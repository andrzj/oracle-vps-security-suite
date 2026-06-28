import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

/**
 * Self-contained admin credentials table.
 * Passwords are stored as bcrypt hashes (cost factor 12).
 * No external OAuth provider is required — the dashboard is fully standalone.
 */
export const admins = sqliteTable("admins", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  username: text("username").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  role: text("role", { enum: ["admin", "viewer"] }).default("admin").notNull(),
  createdAt: text("created_at").default(sql`(datetime('now'))`).notNull(),
  updatedAt: text("updated_at").default(sql`(datetime('now'))`).notNull(),
  lastSignedIn: text("last_signed_in"),
});

export type Admin = typeof admins.$inferSelect;
export type InsertAdmin = typeof admins.$inferInsert;

// ── Security Dashboard Tables ─────────────────────────────────────────────────

export const auditLogs = sqliteTable("audit_logs", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  adminId: integer("admin_id"),
  username: text("username"),
  action: text("action").notNull(),
  resource: text("resource"),
  resourceId: text("resource_id"),
  status: text("status", { enum: ["success", "failure"] }).notNull(),
  details: text("details"),
  ipAddress: text("ip_address"),
  createdAt: text("created_at").default(sql`(datetime('now'))`).notNull(),
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
  acknowledgedAt: text("acknowledged_at"),
  createdAt: text("created_at").default(sql`(datetime('now'))`).notNull(),
  updatedAt: text("updated_at").default(sql`(datetime('now'))`).notNull(),
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
  createdAt: text("created_at").default(sql`(datetime('now'))`).notNull(),
});

export type SystemHealth = typeof systemHealth.$inferSelect;
export type InsertSystemHealth = typeof systemHealth.$inferInsert;

export const fail2banHistory = sqliteTable("fail2ban_history", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  ipAddress: text("ip_address").notNull(),
  jail: text("jail").notNull(),
  bannedAt: text("banned_at").default(sql`(datetime('now'))`).notNull(),
  unbannedAt: text("unbanned_at"),
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
  createdAt: text("created_at").default(sql`(datetime('now'))`).notNull(),
  createdBy: integer("created_by"),
});

export type FirewallRule = typeof firewallRules.$inferSelect;
export type InsertFirewallRule = typeof firewallRules.$inferInsert;
