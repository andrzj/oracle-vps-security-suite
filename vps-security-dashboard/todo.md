# VPS Security Dashboard TODO

## Core Features
- [x] Database schema (users, security_alerts, firewall_rules, ban_history, audit_log, system_health_history)
- [x] tRPC API routes (health, alerts, fail2ban, firewall, logs, audit)
- [x] Security agent module (controlled system command execution)
- [x] Manus OAuth authentication (built-in)
- [x] Audit logging for all write operations

## Frontend Pages
- [x] Overview page (CPU/memory/disk/uptime, resource history chart, security status)
- [x] Alerts page (list, acknowledge, severity filters)
- [x] Fail2Ban page (service status, banned IPs, ban history, unban action)
- [x] Firewall page (UFW status, add/delete rules)
- [x] Logs page (raw log viewer, top attackers panel)
- [x] Audit Log page (paginated action history)

## Infrastructure
- [x] Docker Compose stack (caddy + app)
- [x] Caddyfile with automatic HTTPS and IP restriction
- [x] Production Dockerfile (multi-stage, node:24-alpine)
- [x] Sudoers configuration for least-privilege host access
- [x] DEPLOYMENT.md guide

## Testing
- [x] Vitest tests for auth, health, alerts, audit, firewall, fail2ban (16 tests passing)
