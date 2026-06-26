import { z } from "zod";
import { COOKIE_NAME } from "@shared/const";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, protectedProcedure, router } from "./_core/trpc";
import {
  getAuditLogs,
  getAuditLogCount,
  insertAuditLog,
  getSecurityAlerts,
  acknowledgeAlert,
  getAlertCounts,
  getLatestSystemHealth,
  getSystemHealthHistory,
  insertSystemHealth,
  getFail2BanHistory,
  insertFail2BanEvent,
  getFirewallRules,
  insertFirewallRule,
  deleteFirewallRuleById,
} from "./db";
import * as agent from "./security-agent";

async function audit(
  userId: number,
  action: string,
  resource: string,
  resourceId: string | null,
  status: "success" | "failure",
  details?: string
) {
  await insertAuditLog({
    userId,
    action,
    resource,
    resourceId: resourceId ?? undefined,
    status,
    details,
  });
}

const healthRouter = router({
  current: protectedProcedure.query(async () => {
    const live = await agent.getSystemHealth();
    await insertSystemHealth({ cpuUsage: live.cpu, memoryUsage: live.memory, diskUsage: live.disk, loadAverage: live.loadAverage, uptime: live.uptime });
    return live;
  }),
  history: protectedProcedure.input(z.object({ hours: z.number().min(1).max(168).default(24) })).query(async ({ input }) => getSystemHealthHistory(input.hours)),
  securityStatus: protectedProcedure.query(async () => agent.getSecurityStatus()),
});

const alertsRouter = router({
  list: protectedProcedure.input(z.object({ limit: z.number().min(1).max(200).default(50), onlyUnacknowledged: z.boolean().default(false) })).query(async ({ input }) => getSecurityAlerts(input.limit, input.onlyUnacknowledged)),
  counts: protectedProcedure.query(async () => getAlertCounts()),
  acknowledge: protectedProcedure.input(z.object({ id: z.number() })).mutation(async ({ ctx, input }) => {
    await acknowledgeAlert(input.id, ctx.user.id);
    await audit(ctx.user.id, "acknowledge_alert", "alerts", String(input.id), "success");
    return { success: true };
  }),
  acknowledgeAll: protectedProcedure.mutation(async ({ ctx }) => {
    const alerts = await getSecurityAlerts(200, true);
    for (const alert of alerts) await acknowledgeAlert(alert.id, ctx.user.id);
    await audit(ctx.user.id, "acknowledge_all_alerts", "alerts", null, "success");
    return { success: true, count: alerts.length };
  }),
});

const fail2banRouter = router({
  status: protectedProcedure.query(async ({ ctx }) => {
    const result = await agent.getFail2BanStatus();
    await audit(ctx.user.id, "get_fail2ban_status", "fail2ban", null, result.success ? "success" : "failure");
    return result;
  }),
  bannedIPs: protectedProcedure.query(async ({ ctx }) => {
    const result = await agent.getAllBannedIPs();
    await audit(ctx.user.id, "get_banned_ips", "fail2ban", null, "success");
    return result;
  }),
  jailStatus: protectedProcedure.input(z.object({ jail: z.string().min(1).max(64) })).query(async ({ ctx, input }) => {
    const result = await agent.getJailStatus(input.jail);
    await audit(ctx.user.id, "get_jail_status", "fail2ban", input.jail, result.success ? "success" : "failure");
    return result;
  }),
  unbanIP: protectedProcedure.input(z.object({ ip: z.string().min(7).max(45), jail: z.string().min(1).max(64) })).mutation(async ({ ctx, input }) => {
    const result = await agent.unbanIP(input.ip, input.jail);
    await audit(ctx.user.id, "unban_ip", "fail2ban", input.ip, result.success ? "success" : "failure");
    if (result.success) await insertFail2BanEvent({ ipAddress: input.ip, jail: input.jail, unbannedAt: new Date().toISOString(), reason: "Manual unban via dashboard" });
    return result;
  }),
  history: protectedProcedure.input(z.object({ limit: z.number().min(1).max(200).default(50) })).query(async ({ input }) => getFail2BanHistory(input.limit)),
});

const firewallRouter = router({
  status: protectedProcedure.query(async ({ ctx }) => {
    const result = await agent.getFirewallStatus();
    await audit(ctx.user.id, "get_firewall_status", "firewall", null, result.success ? "success" : "failure");
    return result;
  }),
  rules: protectedProcedure.query(async () => getFirewallRules()),
  addRule: protectedProcedure.input(z.object({ action: z.enum(["allow", "deny"]), port: z.string().min(1).max(32), protocol: z.enum(["tcp", "udp", "any"]), direction: z.enum(["in", "out"]), description: z.string().max(256).optional() })).mutation(async ({ ctx, input }) => {
    const result = await agent.addFirewallRule(input.action, input.port, input.protocol);
    await audit(ctx.user.id, "add_firewall_rule", "firewall", input.port, result.success ? "success" : "failure");
    if (result.success) await insertFirewallRule({ action: input.action, port: input.port, protocol: input.protocol, direction: input.direction, description: input.description, enabled: true, createdBy: ctx.user.id });
    return result;
  }),
  deleteRule: protectedProcedure.input(z.object({ ruleNumber: z.number().min(1).max(999), dbId: z.number().optional() })).mutation(async ({ ctx, input }) => {
    const result = await agent.deleteFirewallRule(input.ruleNumber);
    await audit(ctx.user.id, "delete_firewall_rule", "firewall", String(input.ruleNumber), result.success ? "success" : "failure");
    if (result.success && input.dbId) await deleteFirewallRuleById(input.dbId);
    return result;
  }),
});

const logsRouter = router({
  ssh: protectedProcedure.input(z.object({ lines: z.number().min(10).max(500).default(100) })).query(async ({ ctx, input }) => {
    const result = await agent.getSSHAttempts(input.lines);
    await audit(ctx.user.id, "view_ssh_logs", "logs", "auth.log", result.success ? "success" : "failure");
    return result;
  }),
  topAttackers: protectedProcedure.input(z.object({ limit: z.number().min(5).max(50).default(20) })).query(async ({ ctx, input }) => {
    const result = await agent.getTopAttackers(input.limit);
    await audit(ctx.user.id, "view_top_attackers", "logs", null, "success");
    return result;
  }),
  raw: protectedProcedure.input(z.object({ logName: z.enum(["auth", "syslog", "fail2ban", "ufw", "kern"]), lines: z.number().min(10).max(500).default(100) })).query(async ({ ctx, input }) => {
    const result = await agent.getLogLines(input.logName, input.lines);
    await audit(ctx.user.id, "view_log", "logs", input.logName, result.success ? "success" : "failure");
    return result;
  }),
});

const auditRouter = router({
  list: protectedProcedure.input(z.object({ limit: z.number().min(1).max(200).default(50), offset: z.number().min(0).default(0) })).query(async ({ input }) => {
    const [logs, total] = await Promise.all([getAuditLogs(input.limit, input.offset), getAuditLogCount()]);
    return { logs, total };
  }),
});

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query((opts) => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return { success: true } as const;
    }),
  }),
  health: healthRouter,
  alerts: alertsRouter,
  fail2ban: fail2banRouter,
  firewall: firewallRouter,
  logs: logsRouter,
  audit: auditRouter,
});

export type AppRouter = typeof appRouter;
