# Oracle Cloud VPS Security Suite

A comprehensive collection of automated security hardening, monitoring, and maintenance scripts for Debian-based VPS instances on Oracle Cloud free tier — plus a browser-based security dashboard deployable with Docker Compose.

---

## One-Command Install

The fastest way to get started is the guided installer. It walks through every phase interactively and handles everything automatically:

```bash
git clone https://github.com/andrzj/oracle-vps-security-suite.git
cd oracle-vps-security-suite
sudo bash main.sh
```

`main.sh` is **idempotent** — if it is interrupted, re-running it skips already-completed phases and resumes from where it stopped. An install log is written to `/var/log/vps-security-installer.log`.

---

## What the Installer Does

The installer guides you through four sequential phases:

| Phase | What Happens |
|-------|-------------|
| **1 — System Hardening** | SSH hardening, UFW firewall, Fail2Ban, kernel parameters, AIDE file integrity, automatic security updates. Optionally changes SSH port and enables 2FA. Includes a safety gate — if you change the SSH port, the installer pauses and requires you to confirm connectivity on the new port before continuing. |
| **2 — Security Monitoring** | Installs the real-time log monitoring service as a systemd unit. Optionally configures email alerts and weekly auto-updates for the monitoring scripts. |
| **3 — Dashboard Configuration** | Interactively collects `DOMAIN`, `TRUSTED_IP` (auto-detected from your current IP), `JWT_SECRET` (auto-generated if left blank), and Manus OAuth credentials. Writes `.env` with `chmod 600`, patches the Caddyfile, and installs the sudoers config. |
| **4 — Dashboard Deploy** | Installs Docker if missing, checks DNS resolution, runs `docker compose up -d --build`, health-checks containers, and prints a final summary with quick-reference commands. |

---

## Manual Usage (Without the Installer)

If you prefer to run individual phases yourself, use the scripts directly:

### Phase 1 — Harden (run once)

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
bash scripts/utilities/verify_security.sh
```

### Phase 2 — Monitor (install and forget)

```bash
sudo bash scripts/monitoring/security_monitor.sh --install
sudo bash scripts/monitoring/setup_email_alerts.sh   # optional
```

### Phase 3 — Deploy Dashboard

```bash
cd vps-security-dashboard/docker
cp env.template .env && nano .env
docker compose up -d
```

See [`vps-security-dashboard/DEPLOYMENT.md`](vps-security-dashboard/DEPLOYMENT.md) for the full step-by-step deployment guide.

---

## Security Dashboard

The suite includes a full-stack browser-based security dashboard built with React, tRPC, SQLite, and Caddy.

**Features:**

| Page | Description |
|------|-------------|
| Overview | CPU, memory, disk, uptime cards and 6-hour resource history chart |
| Alerts | Security alerts with severity levels and acknowledge action |
| Fail2Ban | Service status, active jails, banned IPs with unban action |
| Firewall | UFW status, active rules, add/delete rules |
| Logs | Raw log viewer (auth, syslog, UFW) with top attackers panel |
| Audit Log | Paginated history of every write action performed through the dashboard |

**Architecture:**

```
Internet
    │
    ▼
Caddy :443 (HTTPS + IP restriction — only your IP can reach the dashboard)
    │
    ▼
App :3000 (Express + React)
    │
    ├── SQLite (single file, zero network surface, trivially backed up)
    │
    └── Host system (read-only log mounts + limited sudo via sudoers)
         ├── /var/log (read-only)
         ├── fail2ban-client (via sudo)
         └── ufw (via sudo)
```

**Stack:** Next.js 16 · React 19 · tRPC 11 · Drizzle ORM · SQLite (better-sqlite3) · Caddy 2 · Docker Compose v5 · Node.js 24 LTS

---

## Repository Structure

```
oracle-vps-security-suite/
├── main.sh                            ← Unified guided installer (start here)
├── README.md
├── LICENSE
├── .gitignore
│
├── scripts/
│   ├── hardening/
│   │   ├── debian_security_hardening.sh   ← Run once at setup
│   │   └── setup_ssh_2fa.sh               ← Optional: add 2FA to SSH
│   ├── monitoring/
│   │   ├── security_monitor.sh            ← Runs 24/7 as a service
│   │   ├── setup_email_alerts.sh          ← Configure email notifications
│   │   └── analyze_logs.sh                ← On-demand log analysis
│   ├── updates/
│   │   ├── update_monitor.sh              ← Manage updates and rollbacks
│   │   └── check_dependencies.sh          ← Verify system requirements
│   └── utilities/
│       ├── verify_security.sh             ← Verify hardening is applied
│       └── configure_firewall.sh          ← Interactive firewall management
│
├── vps-security-dashboard/            ← Browser-based security dashboard
│   ├── DEPLOYMENT.md                  ← Full deployment guide
│   ├── docker/
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── caddy/Caddyfile
│   │   ├── env.template
│   │   └── sudoers-dashboard.conf
│   ├── client/                        ← React frontend
│   ├── server/                        ← Express + tRPC backend
│   └── drizzle/                       ← SQLite schema and migrations
│
└── docs/
    ├── oracle_cloud_security_guide.md
    ├── QUICK_START.md
    ├── SECURITY_SCRIPTS_README.md
    ├── MONITORING_GUIDE.md
    ├── MONITORING_QUICK_REFERENCE.md
    ├── UPDATE_MANAGEMENT_GUIDE.md
    └── UPDATE_QUICK_REFERENCE.md
```

---

## Script Decision Table

| Situation | Script to Use |
|-----------|--------------|
| Fresh VPS, first full setup | `sudo bash main.sh` |
| Only want OS hardening | `scripts/hardening/debian_security_hardening.sh` |
| Add 2FA to SSH | `scripts/hardening/setup_ssh_2fa.sh` |
| Install 24/7 threat monitoring | `scripts/monitoring/security_monitor.sh --install` |
| Configure email notifications | `scripts/monitoring/setup_email_alerts.sh` |
| Investigate a security event | `scripts/monitoring/analyze_logs.sh` |
| Open a port for a new service | `scripts/utilities/configure_firewall.sh` |
| Verify hardening is still intact | `scripts/utilities/verify_security.sh` |
| Update the monitoring suite | `scripts/updates/update_monitor.sh --update` |
| Roll back after a bad update | `scripts/updates/update_monitor.sh --rollback` |
| Deploy the web dashboard only | `cd vps-security-dashboard/docker && docker compose up -d` |

---

## Scripts Reference

### Hardening (`scripts/hardening/`)

#### `debian_security_hardening.sh`
Complete OS-level hardening in one command. Run once during initial setup.
- Updates all system packages and enables automatic security updates
- Hardens SSH (disables root login, password auth, enforces strong ciphers)
- Configures UFW firewall with default-deny inbound policy
- Installs and configures Fail2Ban
- Applies kernel hardening parameters via sysctl
- Initialises AIDE file integrity monitoring

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

#### `setup_ssh_2fa.sh`
Adds Google Authenticator TOTP as a second factor for SSH login. Run after the main hardening script.

```bash
sudo bash scripts/hardening/setup_ssh_2fa.sh
google-authenticator   # run as your regular user to generate the secret
```

---

### Monitoring (`scripts/monitoring/`)

#### `security_monitor.sh`
Real-time security monitoring service. Monitors SSH attempts, sudo usage, firewall blocks, and system health. Supports interactive, daemon, and systemd service modes.

```bash
sudo bash scripts/monitoring/security_monitor.sh --install    # install as service
bash scripts/monitoring/security_monitor.sh --view-alerts     # view recent alerts
sudo bash scripts/monitoring/security_monitor.sh --report     # generate report
```

**Alert levels:** CRITICAL · HIGH · MEDIUM · LOW

#### `setup_email_alerts.sh`
Configures email notifications (local Postfix or external SMTP) for security alerts.

```bash
sudo bash scripts/monitoring/setup_email_alerts.sh
```

#### `analyze_logs.sh`
Interactive log analysis with eight analysis types: SSH security, firewall, sudo activity, system events, Fail2Ban statistics, system health, alerts summary, and full report.

```bash
bash scripts/monitoring/analyze_logs.sh
bash scripts/monitoring/analyze_logs.sh --report
```

---

### Updates (`scripts/updates/`)

#### `update_monitor.sh`
Manages the monitoring suite lifecycle: version checking, updates, backups, and rollback.

```bash
bash scripts/updates/update_monitor.sh --check       # check for updates
sudo bash scripts/updates/update_monitor.sh --update  # install updates
sudo bash scripts/updates/update_monitor.sh --schedule # schedule weekly auto-updates
sudo bash scripts/updates/update_monitor.sh --rollback # roll back to previous version
```

#### `check_dependencies.sh`
Verifies all system packages, Python modules, config files, services, and permissions are in order.

```bash
bash scripts/updates/check_dependencies.sh --check-all
sudo bash scripts/updates/check_dependencies.sh --install
```

---

### Utilities (`scripts/utilities/`)

#### `verify_security.sh`
Checks that all hardening measures are correctly applied. Run after initial setup and periodically thereafter.

```bash
bash scripts/utilities/verify_security.sh
```

#### `configure_firewall.sh`
Interactive menu for managing UFW rules: view rules, allow/deny ports, add custom rules, change SSH port.

```bash
sudo bash scripts/utilities/configure_firewall.sh
```

---

## Common Workflows

### Daily Operations

```bash
bash scripts/monitoring/security_monitor.sh --view-alerts
bash scripts/monitoring/analyze_logs.sh
```

### Weekly Maintenance

```bash
sudo bash scripts/monitoring/security_monitor.sh --report
bash scripts/updates/check_dependencies.sh --check-all
bash scripts/updates/update_monitor.sh --check
```

### Monthly Review

```bash
bash scripts/utilities/verify_security.sh
bash scripts/updates/update_monitor.sh --changelog
bash scripts/monitoring/analyze_logs.sh --report
```

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/oracle_cloud_security_guide.md`](docs/oracle_cloud_security_guide.md) | Security concepts and architecture |
| [`docs/QUICK_START.md`](docs/QUICK_START.md) | Manual step-by-step setup guide |
| [`docs/SECURITY_SCRIPTS_README.md`](docs/SECURITY_SCRIPTS_README.md) | Detailed script documentation |
| [`docs/MONITORING_GUIDE.md`](docs/MONITORING_GUIDE.md) | Monitoring system usage |
| [`docs/MONITORING_QUICK_REFERENCE.md`](docs/MONITORING_QUICK_REFERENCE.md) | Quick monitoring commands |
| [`docs/UPDATE_MANAGEMENT_GUIDE.md`](docs/UPDATE_MANAGEMENT_GUIDE.md) | Update procedures |
| [`docs/UPDATE_QUICK_REFERENCE.md`](docs/UPDATE_QUICK_REFERENCE.md) | Quick update commands |
| [`vps-security-dashboard/DEPLOYMENT.md`](vps-security-dashboard/DEPLOYMENT.md) | Dashboard deployment guide |

---

## Oracle Cloud Free Tier Notes

- **Idle instance reclamation**: Instances with less than 20% CPU/network/memory utilisation over 7 days may be reclaimed. The monitoring service and dashboard keep the instance active.
- **No NAT Gateway on free tier**: Public IPs are required for outbound traffic.
- **Bandwidth**: 50 Mbps internet bandwidth included.
- **Storage**: 200 GB block storage, 20 GB object storage.
- **SQLite is the right database choice here**: No extra container, no RAM overhead, no network port — ideal for the 1 GB free tier instance.

---

## Troubleshooting

### SSH connection issues

```bash
sudo systemctl status ssh
sudo sshd -t
sudo ufw status
sudo tail -50 /var/log/auth.log
```

### Monitoring service issues

```bash
sudo systemctl status security-monitor
sudo journalctl -u security-monitor -f
sudo systemctl restart security-monitor
```

### Dashboard issues

```bash
cd vps-security-dashboard/docker
docker compose ps
docker compose logs -f app
docker compose logs -f caddy
```

---

## Important Notes

1. **Keep your SSH key safe** — store a backup in a secure location before hardening
2. **Test SSH in a new terminal** before closing your current session after hardening
3. **Update your Oracle Cloud Security List** if you change the SSH port
4. **The dashboard is IP-restricted** — only `TRUSTED_IP` can reach it; update the Caddyfile if your IP changes
5. **Back up the SQLite database** regularly — see the backup commands in `vps-security-dashboard/DEPLOYMENT.md`

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome. Please fork the repository, create a feature branch, test thoroughly, and open a pull request.

---

**Tested on:** Ubuntu 22.04 LTS, Debian 11+
**Last updated:** June 2026
