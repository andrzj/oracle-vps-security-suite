import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";
import { relations, sql } from "drizzle-orm";

/**
 * Core user table backing auth flow.
 * Columns use camelCase to match both database fields and generated types.
 *
 * SQLite notes:
 *  - INTEGER PRIMARY KEY is the rowid alias — autoincrement is implicit.
 *  - Timestamps stored as ISO-8601 text (SQLite has no native timestamp type).
 *  - Enums are enforced at the application layer via Zod; SQLite stores them as text.
 */
export const users = sqliteTable("users", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  /** Manus OAuth identifier (openId) returned from the OAuth callback. Unique per user. */
  openId: text("openId").notNull().unique(),
  name: text("name"),
  email: text("email"),
  loginMethod: text("loginMethod"),
  role: text("role", { enum: ["user", "admin"] }).default("user").notNull(),
  createdAt: text("createdAt").default(sql`(datetime('now'))`).notNull(),
  updatedAt: text("updatedAt").default(sql`(datetime('now'))`).notNull(),
  lastSignedIn: text("lastSignedIn").default(sql`(datetime('now'))`).notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

// ── Security Dashboard Tables ─────────────────────────────────────────────────

export const auditLogs = sqliteTable("audit_logs", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: integer("user_id").notNull(),
  action: text("action").notNull(),
  resource: text("resource"),
  resourceId: text("resource_id"),
  status: text("status", { enum: ["success", "failure"] }).notNull(),
  details: text("details"),
  ipAddress: text("ip_address"),
  createdAt: text("createdAt").default(sql`(datetime('now'))`).notNull(),
});

export type AuditLog = typeof auditLogs.$inferSelect;
export type InsertAuditLog = typeof auditLogs.$inferInsert;

export const securityAlerts = sqliteTable("security_alerts", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  alertType: text("alert_type").notNull(),
  severity: text("severity", { enum: ["critical", "high", "medium", "low"] }).notNull(),
  title: text("title").notNull(),
  description: text("description"),
  sourceIp: text("source_ip"),
  count: integer("count").default(1),
  acknowledged: integer("acknowledged", { mode: "boolean" }).default(false),
  acknowledgedBy: integer("acknowledged_by"),
  acknowledgedAt: text("acknowledgedAt"),
  createdAt: text("createdAt").default(sql`(datetime('now'))`).notNull(),
  updatedAt: text("updatedAt").default(sql`(datetime('now'))`).notNull(),
});

export type SecurityAlert = typeof securityAlerts.$inferSelect;
export type InsertSecurityAlert = typeof securityAlerts.$inferInsert;

export const systemHealth = sqliteTable("system_health", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  cpuUsage: real("cpu_usage"),
  memoryUsage: real("memory_usage"),
  diskUsage: real("disk_usage"),
  loadAverage: text("load_average"),
  uptime: integer("uptime"),
  createdAt: text("createdAt").default(sql`(datetime('now'))`).notNull(),
});

export type SystemHealth = typeof systemHealth.$inferSelect;
export type InsertSystemHealth = typeof systemHealth.$inferInsert;

export const fail2banHistory = sqliteTable("fail2ban_history", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  ipAddress: text("ip_address").notNull(),
  jail: text("jail").notNull(),
  bannedAt: text("bannedAt").default(sql`(datetime('now'))`).notNull(),
  unbannedAt: text("unbannedAt"),
  reason: text("reason"),
  banCount: integer("ban_count").default(1),
});

export type Fail2BanHistory = typeof fail2banHistory.$inferSelect;
export type InsertFail2BanHistory = typeof fail2banHistory.$inferInsert;

export const firewallRules = sqliteTable("firewall_rules", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  action: text("action", { enum: ["allow", "deny"] }).notNull(),
  protocol: text("protocol", { enum: ["tcp", "udp", "any"] }),
  port: text("port"),
  source: text("source").default("any"),
  direction: text("direction", { enum: ["in", "out"] }).notNull(),
  description: text("description"),
  enabled: integer("enabled", { mode: "boolean" }).default(true),
  createdAt: text("createdAt").default(sql`(datetime('now'))`).notNull(),
  createdBy: integer("created_by"),
});

export type FirewallRule = typeof firewallRules.$inferSelect;
export type InsertFirewallRule = typeof firewallRules.$inferInsert;

// ── Relations ─────────────────────────────────────────────────────────────────

export const usersRelations = relations(users, ({ many }) => ({
  auditLogs: many(auditLogs),
  firewallRules: many(firewallRules),
}));

export const auditLogsRelations = relations(auditLogs, ({ one }) => ({
  user: one(users, { fields: [auditLogs.userId], references: [users.id] }),
}));

export const firewallRulesRelations = relations(firewallRules, ({ one }) => ({
  createdByUser: one(users, { fields: [firewallRules.createdBy], references: [users.id] }),
}));
