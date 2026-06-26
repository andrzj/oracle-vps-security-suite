import { eq, desc, gte, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/better-sqlite3";
import Database from "better-sqlite3";
import path from "path";
import fs from "fs";
import {
  users,
  auditLogs,
  securityAlerts,
  systemHealth,
  fail2banHistory,
  firewallRules,
  InsertUser,
  InsertAuditLog,
  InsertSecurityAlert,
  InsertSystemHealth,
  InsertFail2BanHistory,
  InsertFirewallRule,
} from "../drizzle/schema";
import { ENV } from "./_core/env";

// ── SQLite connection (synchronous, single-file) ──────────────────────────────

function getDbPath(): string {
  return process.env.SQLITE_DB_PATH ?? path.join(process.cwd(), "data", "security-dashboard.db");
}

let _db: ReturnType<typeof drizzle> | null = null;

export function getDb() {
  if (!_db) {
    const dbPath = getDbPath();
    // Ensure the data directory exists
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    const sqlite = new Database(dbPath);
    // Enable WAL mode for better concurrent read performance
    sqlite.pragma("journal_mode = WAL");
    sqlite.pragma("foreign_keys = ON");
    _db = drizzle(sqlite);
  }
  return _db;
}

// Helper: current UTC ISO string for timestamp fields
function now(): string {
  return new Date().toISOString();
}

// ── Users ─────────────────────────────────────────────────────────────────────

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) {
    throw new Error("User openId is required for upsert");
  }

  const db = getDb();

  try {
    const existing = db.select().from(users).where(eq(users.openId, user.openId)).limit(1).all();

    const isOwner = user.openId === ENV.ownerOpenId;
    const role = user.role ?? (isOwner ? "admin" : "user");
    const ts = now();

    if (existing.length === 0) {
      db.insert(users).values({
        openId: user.openId,
        name: user.name ?? null,
        email: user.email ?? null,
        loginMethod: user.loginMethod ?? null,
        role,
        createdAt: ts,
        updatedAt: ts,
        lastSignedIn: ts,
      }).run();
    } else {
      db.update(users)
        .set({
          name: user.name ?? existing[0]!.name,
          email: user.email ?? existing[0]!.email,
          loginMethod: user.loginMethod ?? existing[0]!.loginMethod,
          role: isOwner ? "admin" : (existing[0]!.role ?? "user"),
          updatedAt: ts,
          lastSignedIn: ts,
        })
        .where(eq(users.openId, user.openId))
        .run();
    }
  } catch (error) {
    console.error("[Database] Failed to upsert user:", error);
    throw error;
  }
}

export async function getUserByOpenId(openId: string) {
  const db = getDb();
  const result = db.select().from(users).where(eq(users.openId, openId)).limit(1).all();
  return result.length > 0 ? result[0] : undefined;
}

// ── Audit Logs ────────────────────────────────────────────────────────────────

export async function insertAuditLog(log: InsertAuditLog) {
  const db = getDb();
  db.insert(auditLogs).values({ ...log, createdAt: now() }).run();
}

export async function getAuditLogs(limit = 50, offset = 0) {
  const db = getDb();
  return db.select().from(auditLogs).orderBy(desc(auditLogs.createdAt)).limit(limit).offset(offset).all();
}

export async function getAuditLogCount() {
  const db = getDb();
  const result = db.select({ count: sql<number>`count(*)` }).from(auditLogs).all();
  return result[0]?.count ?? 0;
}

// ── Security Alerts ───────────────────────────────────────────────────────────

export async function insertSecurityAlert(alert: InsertSecurityAlert) {
  const db = getDb();
  const ts = now();
  db.insert(securityAlerts).values({ ...alert, createdAt: ts, updatedAt: ts }).run();
}

export async function getSecurityAlerts(limit = 50, onlyUnacknowledged = false) {
  const db = getDb();
  if (onlyUnacknowledged) {
    return db.select().from(securityAlerts)
      .where(eq(securityAlerts.acknowledged, false))
      .orderBy(desc(securityAlerts.createdAt))
      .limit(limit)
      .all();
  }
  return db.select().from(securityAlerts).orderBy(desc(securityAlerts.createdAt)).limit(limit).all();
}

export async function acknowledgeAlert(id: number, userId: number) {
  const db = getDb();
  db.update(securityAlerts)
    .set({ acknowledged: true, acknowledgedBy: userId, acknowledgedAt: now(), updatedAt: now() })
    .where(eq(securityAlerts.id, id))
    .run();
}

export async function getAlertCounts() {
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

export async function insertSystemHealth(snapshot: InsertSystemHealth) {
  const db = getDb();
  db.insert(systemHealth).values({ ...snapshot, createdAt: now() }).run();
}

export async function getLatestSystemHealth() {
  const db = getDb();
  const result = db.select().from(systemHealth).orderBy(desc(systemHealth.createdAt)).limit(1).all();
  return result[0] ?? null;
}

export async function getSystemHealthHistory(hours = 24) {
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

export async function insertFail2BanEvent(event: InsertFail2BanHistory) {
  const db = getDb();
  db.insert(fail2banHistory).values({ ...event, bannedAt: now() }).run();
}

export async function getFail2BanHistory(limit = 50) {
  const db = getDb();
  return db.select().from(fail2banHistory).orderBy(desc(fail2banHistory.bannedAt)).limit(limit).all();
}

// ── Firewall Rules ────────────────────────────────────────────────────────────

export async function insertFirewallRule(rule: InsertFirewallRule) {
  const db = getDb();
  db.insert(firewallRules).values({ ...rule, createdAt: now() }).run();
}

export async function getFirewallRules() {
  const db = getDb();
  return db.select().from(firewallRules).orderBy(desc(firewallRules.createdAt)).all();
}

export async function deleteFirewallRuleById(id: number) {
  const db = getDb();
  db.delete(firewallRules).where(eq(firewallRules.id, id)).run();
}
