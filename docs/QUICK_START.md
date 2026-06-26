# Quick Start Guide

## Recommended: One-Command Install

The guided installer handles everything — hardening, monitoring, dashboard configuration, and deployment — in a single interactive session:

```bash
git clone https://github.com/andrzj/oracle-vps-security-suite.git
cd oracle-vps-security-suite
sudo bash main.sh
```

The installer will ask you a small number of questions (SSH port, trusted IP, domain, credentials) and do the rest automatically. It is **idempotent** — if interrupted, re-run it and it will skip completed phases.

**Estimated time:** 5–10 minutes on a fresh Oracle Cloud free tier instance.

---

## Manual Setup (Step by Step)

If you prefer to run each phase individually, follow the steps below.

---

### Step 1 — System Hardening

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

This hardens the OS in one pass:
- Updates all system packages
- Hardens SSH (disables root login, disables password authentication)
- Enables UFW firewall with default-deny inbound policy
- Installs and configures Fail2Ban
- Applies kernel hardening parameters
- Enables automatic security updates
- Initialises AIDE file integrity monitoring

**Critical:** Do NOT close your current SSH session until you have verified access in a new terminal.

```bash
# Open a new terminal and test before closing the current one
ssh -i your-key.pem ubuntu@YOUR_VPS_IP
```

If the connection fails, use the Oracle Cloud Console → Compute → Instances → Console Connection to regain access and check `/etc/ssh/sshd_config`.

---

### Step 2 — Verify Hardening

```bash
bash scripts/utilities/verify_security.sh
```

Checks SSH configuration, UFW status, Fail2Ban, kernel parameters, and automatic updates. Review any warnings before proceeding.

---

### Step 3 — Optional: SSH 2FA

For an additional layer of authentication, add Google Authenticator TOTP to SSH:

```bash
sudo bash scripts/hardening/setup_ssh_2fa.sh

# Then, as your regular user (not root), generate your secret:
google-authenticator
```

Scan the QR code with the Google Authenticator app and save the emergency codes in a secure location.

---

### Step 4 — Install Security Monitoring

```bash
sudo bash scripts/monitoring/security_monitor.sh --install
```

Installs the monitoring service as a systemd unit that starts automatically on boot. It monitors SSH attempts, sudo usage, firewall blocks, and system health.

```bash
# Verify the service is running
sudo systemctl status security-monitor

# View recent alerts
bash scripts/monitoring/security_monitor.sh --view-alerts
```

---

### Step 5 — Optional: Email Alerts

```bash
sudo bash scripts/monitoring/setup_email_alerts.sh
```

Configures email notifications for critical security events. Supports local Postfix delivery or an external SMTP provider (Gmail, SendGrid, etc.).

---

### Step 6 — Optional: Schedule Auto-Updates

```bash
sudo bash scripts/updates/update_monitor.sh --schedule
```

Configures a weekly cron job to check for and apply updates to the monitoring scripts automatically.

---

### Step 7 — Deploy the Security Dashboard

The dashboard provides a browser-based interface for monitoring alerts, managing Fail2Ban bans, viewing firewall rules, and reading logs.

```bash
cd vps-security-dashboard/docker
cp env.template .env
nano .env   # fill in DOMAIN, TRUSTED_IP, JWT_SECRET, and Manus credentials
chmod 600 .env
```

Configure the Caddyfile:

```bash
nano caddy/Caddyfile
# Replace YOUR_DOMAIN and YOUR_HOME_IP
```

Install the sudoers config for least-privilege host access:

```bash
sudo cp sudoers-dashboard.conf /etc/sudoers.d/dashboard
sudo chmod 440 /etc/sudoers.d/dashboard
sudo visudo -c   # validate — never skip this
```

Open ports 80 and 443 in your Oracle Cloud Security List, then deploy:

```bash
docker compose up -d
docker compose ps   # verify containers are healthy
```

See [`vps-security-dashboard/DEPLOYMENT.md`](../vps-security-dashboard/DEPLOYMENT.md) for the full deployment guide including DNS setup, backup procedures, and troubleshooting.

---

## Script Quick Reference

| Situation | Command |
|-----------|---------|
| Full guided install | `sudo bash main.sh` |
| OS hardening only | `sudo bash scripts/hardening/debian_security_hardening.sh` |
| Add SSH 2FA | `sudo bash scripts/hardening/setup_ssh_2fa.sh` |
| Install monitoring service | `sudo bash scripts/monitoring/security_monitor.sh --install` |
| View security alerts | `bash scripts/monitoring/security_monitor.sh --view-alerts` |
| Analyse logs | `bash scripts/monitoring/analyze_logs.sh` |
| Open a port for a service | `sudo bash scripts/utilities/configure_firewall.sh` |
| Verify hardening is intact | `bash scripts/utilities/verify_security.sh` |
| Update monitoring scripts | `sudo bash scripts/updates/update_monitor.sh --update` |
| Roll back after bad update | `sudo bash scripts/updates/update_monitor.sh --rollback` |

---

## Common Issues

### "Permission denied" when running scripts

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

All hardening and monitoring scripts require root privileges. Prefix with `sudo bash`.

### SSH connection fails after hardening

1. Open Oracle Cloud Console → Compute → Instances → your instance → Console Connection
2. Check SSH config: `sudo sshd -t`
3. Restore backup if needed: `sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config`
4. Restart SSH: `sudo systemctl restart ssh`

### Changed SSH port but cannot connect

1. Update the Oracle Cloud Security List to allow TCP on the new port
2. Verify the config: `sudo sshd -t`
3. Restart SSH: `sudo systemctl restart ssh`
4. Connect with: `ssh -p NEW_PORT -i your-key.pem ubuntu@YOUR_VPS_IP`

### Firewall is blocking a service

```bash
sudo ufw status numbered
sudo ufw allow 8080/tcp   # replace with your port
# Also open the port in Oracle Cloud Security List
```

### Dashboard shows 403 Forbidden

Your IP is not in the Caddyfile's `remote_ip` list. Update it and reload:

```bash
nano vps-security-dashboard/docker/caddy/Caddyfile
# Update the remote_ip line

cd vps-security-dashboard/docker
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## After Setup — Ongoing Operations

### Daily
```bash
bash scripts/monitoring/security_monitor.sh --view-alerts
```

### Weekly
```bash
bash scripts/monitoring/analyze_logs.sh --report
bash scripts/updates/update_monitor.sh --check
```

### Monthly
```bash
bash scripts/utilities/verify_security.sh
sudo bash scripts/monitoring/security_monitor.sh --report
```

---

Your VPS is now hardened, monitored, and ready for public services.
