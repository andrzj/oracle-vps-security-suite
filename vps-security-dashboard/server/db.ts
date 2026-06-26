import { eq, desc, gte, sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/mysql2";
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
import { ENV } from './_core/env';

let _db: ReturnType<typeof drizzle> | null = null;

// Lazily create the drizzle instance so local tooling can run without a DB.
export async function getDb() {
  if (!_db && process.env.DATABASE_URL) {
    try {
      _db = drizzle(process.env.DATABASE_URL);
    } catch (error) {
      console.warn("[Database] Failed to connect:", error);
      _db = null;
    }
  }
  return _db;
}

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) {
    throw new Error("User openId is required for upsert");
  }

  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot upsert user: database not available");
    return;
  }

  try {
    const values: InsertUser = {
      openId: user.openId,
    };
    const updateSet: Record<string, unknown> = {};

    const textFields = ["name", "email", "loginMethod"] as const;
    type TextField = (typeof textFields)[number];

    const assignNullable = (field: TextField) => {
      const value = user[field];
      if (value === undefined) return;
      const normalized = value ?? null;
      values[field] = normalized;
      updateSet[field] = normalized;
    };

    textFields.forEach(assignNullable);

    if (user.lastSignedIn !== undefined) {
      values.lastSignedIn = user.lastSignedIn;
      updateSet.lastSignedIn = user.lastSignedIn;
    }
    if (user.role !== undefined) {
      values.role = user.role;
      updateSet.role = user.role;
    } else if (user.openId === ENV.ownerOpenId) {
      values.role = 'admin';
      updateSet.role = 'admin';
    }

    if (!values.lastSignedIn) {
      values.lastSignedIn = new Date();
    }

    if (Object.keys(updateSet).length === 0) {
      updateSet.lastSignedIn = new Date();
    }

    await db.insert(users).values(values).onDuplicateKeyUpdate({
      set: updateSet,
    });
  } catch (error) {
    console.error("[Database] Failed to upsert user:", error);
    throw error;
  }
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot get user: database not available");
    return undefined;
  }

  const result = await db.select().from(users).where(eq(users.openId, openId)).limit(1);

  return result.length > 0 ? result[0] : undefined;
}

// ─── Audit Logs ───────────────────────────────────────────────────────────────

export async function insertAuditLog(log: InsertAuditLog) {
  const db = await getDb();
  if (!db) return;
  await db.insert(auditLogs).values(log);
}

export async function getAuditLogs(limit = 50, offset = 0) {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(auditLogs).orderBy(desc(auditLogs.createdAt)).limit(limit).offset(offset);
}

export async function getAuditLogCount() {
  const db = await getDb();
  if (!db) return 0;
  const result = await db.select({ count: sql<number>`count(*)` }).from(auditLogs);
  return result[0]?.count ?? 0;
}

// ─── Security Alerts ──────────────────────────────────────────────────────────

export async function insertSecurityAlert(alert: InsertSecurityAlert) {
  const db = await getDb();
  if (!db) return;
  await db.insert(securityAlerts).values(alert);
}

export async function getSecurityAlerts(limit = 50, onlyUnacknowledged = false) {
  const db = await getDb();
  if (!db) return [];
  if (onlyUnacknowledged) {
    return db.select().from(securityAlerts).where(eq(securityAlerts.acknowledged, false)).orderBy(desc(securityAlerts.createdAt)).limit(limit);
  }
  return db.select().from(securityAlerts).orderBy(desc(securityAlerts.createdAt)).limit(limit);
}

export async function acknowledgeAlert(id: number, userId: number) {
  const db = await getDb();
  if (!db) return;
  await db.update(securityAlerts).set({ acknowledged: true, acknowledgedBy: userId, acknowledgedAt: new Date() }).where(eq(securityAlerts.id, id));
}

export async function getAlertCounts() {
  const db = await getDb();
  if (!db) return { critical: 0, high: 0, medium: 0, low: 0, total: 0 };
  const result = await db.select({ severity: securityAlerts.severity, count: sql<number>`count(*)` }).from(securityAlerts).where(eq(securityAlerts.acknowledged, false)).groupBy(securityAlerts.severity);
  const counts = { critical: 0, high: 0, medium: 0, low: 0, total: 0 };
  for (const row of result) {
    counts[row.severity as keyof typeof counts] = row.count;
    counts.total += row.count;
  }
  return counts;
}

// ─── System Health ────────────────────────────────────────────────────────────

export async function insertSystemHealth(snapshot: InsertSystemHealth) {
  const db = await getDb();
  if (!db) return;
  await db.insert(systemHealth).values(snapshot);
}

export async function getLatestSystemHealth() {
  const db = await getDb();
  if (!db) return null;
  const result = await db.select().from(systemHealth).orderBy(desc(systemHealth.createdAt)).limit(1);
  return result[0] ?? null;
}

export async function getSystemHealthHistory(hours = 24) {
  const db = await getDb();
  if (!db) return [];
  const since = new Date(Date.now() - hours * 60 * 60 * 1000);
  return db.select().from(systemHealth).where(gte(systemHealth.createdAt, since)).orderBy(desc(systemHealth.createdAt)).limit(288);
}

// ─── Fail2Ban History ─────────────────────────────────────────────────────────

export async function insertFail2BanEvent(event: InsertFail2BanHistory) {
  const db = await getDb();
  if (!db) return;
  await db.insert(fail2banHistory).values(event);
}

export async function getFail2BanHistory(limit = 50) {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(fail2banHistory).orderBy(desc(fail2banHistory.bannedAt)).limit(limit);
}

// ─── Firewall Rules ───────────────────────────────────────────────────────────

export async function insertFirewallRule(rule: InsertFirewallRule) {
  const db = await getDb();
  if (!db) return;
  await db.insert(firewallRules).values(rule);
}

export async function getFirewallRules() {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(firewallRules).orderBy(desc(firewallRules.createdAt));
}

export async function deleteFirewallRuleById(id: number) {
  const db = await getDb();
  if (!db) return;
  await db.delete(firewallRules).where(eq(firewallRules.id, id));
}
