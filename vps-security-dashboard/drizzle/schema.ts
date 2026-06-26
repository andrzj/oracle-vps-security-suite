import { int, mysqlEnum, mysqlTable, text, timestamp, varchar, boolean, float } from "drizzle-orm/mysql-core";
import { relations } from "drizzle-orm";

/**
 * Core user table backing auth flow.
 * Extend this file with additional tables as your product grows.
 * Columns use camelCase to match both database fields and generated types.
 */
export const users = mysqlTable("users", {
  /**
   * Surrogate primary key. Auto-incremented numeric value managed by the database.
   * Use this for relations between tables.
   */
  id: int("id").autoincrement().primaryKey(),
  /** Manus OAuth identifier (openId) returned from the OAuth callback. Unique per user. */
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

// Security Dashboard Tables

export const auditLogs = mysqlTable("audit_logs", {
  id: int("id").autoincrement().primaryKey(),
  userId: int("user_id").notNull(),
  action: varchar("action", { length: 128 }).notNull(),
  resource: varchar("resource", { length: 64 }),
  resourceId: varchar("resource_id", { length: 256 }),
  status: mysqlEnum("status", ["success", "failure"]).notNull(),
  details: text("details"),
  ipAddress: varchar("ip_address", { length: 64 }),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type AuditLog = typeof auditLogs.$inferSelect;
export type InsertAuditLog = typeof auditLogs.$inferInsert;

export const securityAlerts = mysqlTable("security_alerts", {
  id: int("id").autoincrement().primaryKey(),
  alertType: varchar("alert_type", { length: 64 }).notNull(),
  severity: mysqlEnum("severity", ["critical", "high", "medium", "low"]).notNull(),
  title: varchar("title", { length: 256 }).notNull(),
  description: text("description"),
  sourceIp: varchar("source_ip", { length: 64 }),
  count: int("count").default(1),
  acknowledged: boolean("acknowledged").default(false),
  acknowledgedBy: int("acknowledged_by"),
  acknowledgedAt: timestamp("acknowledgedAt"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type SecurityAlert = typeof securityAlerts.$inferSelect;
export type InsertSecurityAlert = typeof securityAlerts.$inferInsert;

export const systemHealth = mysqlTable("system_health", {
  id: int("id").autoincrement().primaryKey(),
  cpuUsage: float("cpu_usage"),
  memoryUsage: float("memory_usage"),
  diskUsage: float("disk_usage"),
  loadAverage: varchar("load_average", { length: 64 }),
  uptime: int("uptime"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export type SystemHealth = typeof systemHealth.$inferSelect;
export type InsertSystemHealth = typeof systemHealth.$inferInsert;

export const fail2banHistory = mysqlTable("fail2ban_history", {
  id: int("id").autoincrement().primaryKey(),
  ipAddress: varchar("ip_address", { length: 64 }).notNull(),
  jail: varchar("jail", { length: 64 }).notNull(),
  bannedAt: timestamp("bannedAt").defaultNow().notNull(),
  unbannedAt: timestamp("unbannedAt"),
  reason: text("reason"),
  banCount: int("ban_count").default(1),
});

export type Fail2BanHistory = typeof fail2banHistory.$inferSelect;
export type InsertFail2BanHistory = typeof fail2banHistory.$inferInsert;

export const firewallRules = mysqlTable("firewall_rules", {
  id: int("id").autoincrement().primaryKey(),
  action: mysqlEnum("action", ["allow", "deny"]).notNull(),
  protocol: mysqlEnum("protocol", ["tcp", "udp", "any"]),
  port: varchar("port", { length: 32 }),
  source: varchar("source", { length: 128 }).default("any"),
  direction: mysqlEnum("direction", ["in", "out"]).notNull(),
  description: varchar("description", { length: 256 }),
  enabled: boolean("enabled").default(true),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  createdBy: int("created_by"),
});

export type FirewallRule = typeof firewallRules.$inferSelect;
export type InsertFirewallRule = typeof firewallRules.$inferInsert;

// Relations
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