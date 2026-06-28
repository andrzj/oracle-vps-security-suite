import { eq, desc, gte, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/better-sqlite3";
import Database from "better-sqlite3";
import path from "path";
import fs from "fs";
import bcrypt from "bcryptjs";
import { SignJWT, jwtVerify } from "jose";
import {
  admins,
  auditLogs,
  securityAlerts,
  systemHealth,
  fail2banHistory,
  firewallRules,
  type Admin,
  type InsertAuditLog,
  type InsertSecurityAlert,
  type InsertSystemHealth,
  type InsertFail2BanHistory,
  type InsertFirewallRule,
} from "../drizzle/schema";
import { ENV } from "./_core/env";

// ── SQLite connection ─────────────────────────────────────────────────────────

function getDbPath(): string {
  return process.env.SQLITE_DB_PATH ?? path.join(process.cwd(), "data", "security-dashboard.db");
}

let _db: ReturnType<typeof drizzle> | null = null;

export function getDb() {
  if (!_db) {
    const dbPath = getDbPath();
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const sqlite = new Database(dbPath);
    sqlite.pragma("journal_mode = WAL");
    sqlite.pragma("foreign_keys = ON");
    _db = drizzle(sqlite);
  }
  return _db;
}

function now(): string {
  return new Date().toISOString();
}

// ── JWT helpers ───────────────────────────────────────────────────────────────

const JWT_EXPIRY = "8h";

function getJwtSecret(): Uint8Array {
  const secret = ENV.cookieSecret;
  if (!secret || secret.length < 16) {
    throw new Error("JWT_SECRET must be at least 16 characters");
  }
  return new TextEncoder().encode(secret);
}

export async function signAdminJWT(admin: Pick<Admin, "id" | "username" | "role">): Promise<string> {
  return new SignJWT({ id: admin.id, username: admin.username, role: admin.role })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(JWT_EXPIRY)
    .sign(getJwtSecret());
}

export async function verifyAdminJWT(
  token: string
): Promise<{ id: number; username: string; role: string } | null> {
  try {
    const { payload } = await jwtVerify(token, getJwtSecret());
    return payload as { id: number; username: string; role: string };
  } catch {
    return null;
  }
}

// ── Admin credential helpers ──────────────────────────────────────────────────

export async function createAdmin(
  username: string,
  password: string,
  role: "admin" | "viewer" = "admin"
): Promise<Admin> {
  const db = getDb();
  const passwordHash = await bcrypt.hash(password, 12);
  const ts = now();
  const result = db
    .insert(admins)
    .values({ username, passwordHash, role, createdAt: ts, updatedAt: ts })
    .returning()
    .get();
  return result;
}

export async function verifyAdminCredentials(
  username: string,
  password: string
): Promise<Admin | null> {
  const db = getDb();
  const admin = db.select().from(admins).where(eq(admins.username, username)).get();
  if (!admin) return null;
  const valid = await bcrypt.compare(password, admin.passwordHash);
  if (!valid) return null;
  db.update(admins)
    .set({ lastSignedIn: now(), updatedAt: now() })
    .where(eq(admins.id, admin.id))
    .run();
  return admin;
}

export function getAdminById(id: number): Admin | undefined {
  const db = getDb();
  return db.select().from(admins).where(eq(admins.id, id)).get();
}

export function getAdminByUsername(username: string): Admin | undefined {
  const db = getDb();
  return db.select().from(admins).where(eq(admins.username, username)).get();
}

export function countAdmins(): number {
  const db = getDb();
  const result = db.select({ count: sql<number>`count(*)` }).from(admins).get();
  return result?.count ?? 0;
}

export async function changeAdminPassword(id: number, newPassword: string): Promise<void> {
  const db = getDb();
  const passwordHash = await bcrypt.hash(newPassword, 12);
  db.update(admins)
    .set({ passwordHash, updatedAt: now() })
    .where(eq(admins.id, id))
    .run();
}

// ── Audit Logs ────────────────────────────────────────────────────────────────

export function insertAuditLog(log: InsertAuditLog): void {
  const db = getDb();
  db.insert(auditLogs).values({ ...log, createdAt: now() }).run();
}

export function getAuditLogs(limit = 50, offset = 0) {
  const db = getDb();
  return db.select().from(auditLogs).orderBy(desc(auditLogs.createdAt)).limit(limit).offset(offset).all();
}

export function getAuditLogCount(): number {
  const db = getDb();
  const result = db.select({ count: sql<number>`count(*)` }).from(auditLogs).get();
  return result?.count ?? 0;
}

// ── Security Alerts ───────────────────────────────────────────────────────────

export function insertSecurityAlert(alert: InsertSecurityAlert) {
  const db = getDb();
  const ts = now();
  db.insert(securityAlerts).values({ ...alert, createdAt: ts, updatedAt: ts }).run();
}

export function getSecurityAlerts(limit = 50, onlyUnacknowledged = false) {
  const db = getDb();
  if (onlyUnacknowledged) {
    return db
      .select()
      .from(securityAlerts)
      .where(eq(securityAlerts.acknowledged, false))
      .orderBy(desc(securityAlerts.createdAt))
      .limit(limit)
      .all();
  }
  return db.select().from(securityAlerts).orderBy(desc(securityAlerts.createdAt)).limit(limit).all();
}

export function acknowledgeAlert(id: number, adminId: number): void {
  const db = getDb();
  db.update(securityAlerts)
    .set({ acknowledged: true, acknowledgedBy: adminId, acknowledgedAt: now(), updatedAt: now() })
    .where(eq(securityAlerts.id, id))
    .run();
}

export function getAlertCounts() {
  const db = getDb();
  const result = db
    .select({ severity: securityAlerts.severity, count: sql<number>`count(*)` })
    .from(securityAlerts)
    .where(eq(securityAlerts.acknowledged, false))
    .groupBy(securityAlerts.severity)
    .all();
  const counts = { critical: 0, high: 0, medium: 0, low: 0, total: 0 };
  for (const row of result) {
    counts[row.severity as keyof typeof counts] = row.count;
    counts.total += row.count;
  }
  return counts;
}

// ── System Health ─────────────────────────────────────────────────────────────

export function insertSystemHealth(snapshot: InsertSystemHealth): void {
  const db = getDb();
  db.insert(systemHealth).values({ ...snapshot, createdAt: now() }).run();
}

export function getLatestSystemHealth() {
  const db = getDb();
  return db.select().from(systemHealth).orderBy(desc(systemHealth.createdAt)).limit(1).get() ?? null;
}

export function getSystemHealthHistory(hours = 24) {
  const db = getDb();
  const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
  return db
    .select()
    .from(systemHealth)
    .where(gte(systemHealth.createdAt, since))
    .orderBy(desc(systemHealth.createdAt))
    .limit(288)
    .all();
}

// ── Fail2Ban History ──────────────────────────────────────────────────────────

export function insertFail2BanEvent(event: InsertFail2BanHistory): void {
  const db = getDb();
  db.insert(fail2banHistory).values({ ...event, bannedAt: now() }).run();
}

export function getFail2BanHistory(limit = 50) {
  const db = getDb();
  return db.select().from(fail2banHistory).orderBy(desc(fail2banHistory.bannedAt)).limit(limit).all();
}

// ── Firewall Rules ────────────────────────────────────────────────────────────

export function insertFirewallRule(rule: InsertFirewallRule) {
  const db = getDb();
  db.insert(firewallRules).values({ ...rule, createdAt: now() }).run();
}

export function getFirewallRules() {
  const db = getDb();
  return db.select().from(firewallRules).orderBy(desc(firewallRules.createdAt)).all();
}

export function deleteFirewallRuleById(id: number): void {
  const db = getDb();
  db.delete(firewallRules).where(eq(firewallRules.id, id)).run();
}
