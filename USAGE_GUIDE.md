# Usage Guide

Comprehensive guide on how and when to use each script in the Oracle Cloud VPS Security Suite.

## Table of Contents

1. [Script Overview](#script-overview)
2. [When to Use Each Script](#when-to-use-each-script)
3. [Daily Operations](#daily-operations)
4. [Weekly Maintenance](#weekly-maintenance)
5. [Monthly Reviews](#monthly-reviews)
6. [Emergency Procedures](#emergency-procedures)

## Script Overview

### Hardening Scripts

| Script | Purpose | Frequency | Time |
|--------|---------|-----------|------|
| `debian_security_hardening.sh` | Initial security setup | Once | 5-15 min |
| `setup_ssh_2fa.sh` | Add 2FA to SSH | Once | 2 min |

### Monitoring Scripts

| Script | Purpose | Frequency | Time |
|--------|---------|-----------|------|
| `security_monitor.sh` | Real-time monitoring | Continuous | - |
| `setup_email_alerts.sh` | Email configuration | Once | 2-5 min |
| `analyze_logs.sh` | Log analysis | Daily/Weekly | 1-5 min |

### Update Scripts

| Script | Purpose | Frequency | Time |
|--------|---------|-----------|------|
| `update_monitor.sh` | Update management | Weekly | 2-5 min |
| `check_dependencies.sh` | Dependency checking | Weekly | 1 min |

### Utility Scripts

| Script | Purpose | Frequency | Time |
|--------|---------|-----------|------|
| `verify_security.sh` | Security verification | Weekly | 1 min |
| `configure_firewall.sh` | Firewall management | As needed | 1-5 min |

---

## When to Use Each Script

### `debian_security_hardening.sh`

**When:** Initial server setup (first time only)
**Why:** Applies all security hardening measures at once
**How:**

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

**What happens:**
- System packages updated
- SSH hardened
- Firewall enabled
- Fail2Ban installed
- Kernel hardened
- Automatic updates enabled
- AIDE initialized

**Expected duration:** 5-15 minutes
**Risk level:** Medium (requires new SSH connection test)
**Rollback:** Restore from backup or manual reversal

**Important:** Test SSH in new terminal before closing current one!

---

### `setup_ssh_2fa.sh`

**When:** After initial hardening, for enhanced security
**Why:** Adds second factor authentication to SSH
**How:**

```bash
sudo bash scripts/hardening/setup_ssh_2fa.sh
```

**What happens:**
- Installs Google Authenticator
- Configures PAM for 2FA
- Generates QR code
- Creates emergency codes

**Expected duration:** 2 minutes
**Risk level:** Low (can be disabled easily)
**Requirements:** Main hardening must be done first

**Steps:**
1. Run script
2. Scan QR code with authenticator app
3. Save emergency codes securely
4. Test login with code

---

### `security_monitor.sh`

**When:** After hardening, runs continuously
**Why:** Detects security threats in real-time
**How:**

```bash
# Install as service (recommended)
sudo bash scripts/monitoring/security_monitor.sh --install

# Check status
sudo systemctl status security-monitor

# View alerts
bash scripts/monitoring/security_monitor.sh --view-alerts

# Generate report
sudo bash scripts/monitoring/security_monitor.sh --report
```

**Modes:**
- **Interactive**: Real-time dashboard (testing)
- **Daemon**: Background service (production)
- **Service**: Systemd service (recommended)

**What it monitors:**
- SSH authentication attempts
- Sudo command execution
- Firewall blocks
- System resources
- Fail2Ban activity

**Expected duration:** Continuous
**Risk level:** None (read-only monitoring)
**Resource usage:** <1% CPU, 20-50 MB RAM

---

### `setup_email_alerts.sh`

**When:** After installing security monitor
**Why:** Sends security alerts to your email
**How:**

```bash
sudo bash scripts/monitoring/setup_email_alerts.sh
```

**Options:**
1. Local mail delivery (Postfix)
2. External SMTP (Gmail, SendGrid)
3. Test email
4. Update monitor config

**Expected duration:** 2-5 minutes
**Risk level:** None (configuration only)

**Setup steps:**
1. Choose delivery method
2. Enter email details if using SMTP
3. Test email
4. Enable in monitor config

---

### `analyze_logs.sh`

**When:** Daily/weekly security reviews, incident investigation
**Why:** Deep analysis of security patterns and trends
**How:**

```bash
# Interactive menu
bash scripts/monitoring/analyze_logs.sh

# Generate full report
bash scripts/monitoring/analyze_logs.sh --report
```

**Analysis types:**
1. SSH security analysis
2. Firewall analysis
3. Sudo activity analysis
4. System events analysis
5. Fail2Ban analysis
6. System health analysis
7. Security alerts summary
8. Generate full report

**Expected duration:** 1-5 minutes
**Risk level:** None (read-only analysis)

**Common use cases:**
- Investigating failed login attempts
- Analyzing firewall blocks
- Reviewing sudo usage
- Checking system health
- Incident response

---

### `update_monitor.sh`

**When:** Weekly maintenance, update management
**Why:** Manages updates, backups, and rollbacks
**How:**

```bash
# Check for updates
bash scripts/updates/update_monitor.sh --check

# Install updates
sudo bash scripts/updates/update_monitor.sh --update

# Schedule automatic updates
sudo bash scripts/updates/update_monitor.sh --schedule

# Rollback to previous version
sudo bash scripts/updates/update_monitor.sh --rollback

# View status
bash scripts/updates/update_monitor.sh --status
```

**Commands:**
- `--check`: Check for available updates
- `--update`: Install updates
- `--schedule`: Configure automatic updates
- `--rollback`: Revert to previous version
- `--list-backups`: View available backups
- `--status`: Show update status
- `--changelog`: View update history

**Expected duration:** 2-5 minutes
**Risk level:** Low (automatic backups)
**Backup retention:** Last 5 versions

---

### `check_dependencies.sh`

**When:** Before initial setup, troubleshooting, weekly checks
**Why:** Verifies all system dependencies are installed
**How:**

```bash
# Check all
bash scripts/updates/check_dependencies.sh --check-all

# Install missing
sudo bash scripts/updates/check_dependencies.sh --install

# Specific checks
bash scripts/updates/check_dependencies.sh --packages
bash scripts/updates/check_dependencies.sh --python
bash scripts/updates/check_dependencies.sh --services
bash scripts/updates/check_dependencies.sh --disk
bash scripts/updates/check_dependencies.sh --network

# Generate report
bash scripts/updates/check_dependencies.sh --report
```

**Checks:**
- System packages
- Python modules
- Configuration files
- Service status
- File permissions
- Disk space
- Network connectivity

**Expected duration:** 1 minute
**Risk level:** None (read-only checking)

---

### `verify_security.sh`

**When:** After hardening, weekly verification
**Why:** Confirms all security measures are properly applied
**How:**

```bash
# Quick verification
bash scripts/utilities/verify_security.sh

# With monitoring
bash scripts/utilities/verify_security.sh --monitor
```

**Verifies:**
- SSH hardening
- Firewall configuration
- Fail2Ban operation
- System hardening
- Automatic updates
- Monitoring status

**Expected duration:** 1 minute
**Risk level:** None (read-only verification)

---

### `configure_firewall.sh`

**When:** After hardening, when adding services
**Why:** Manage firewall rules interactively
**How:**

```bash
sudo bash scripts/utilities/configure_firewall.sh
```

**Options:**
- View current rules
- Allow/deny ports
- Add custom rules
- Change SSH port
- Enable/disable firewall

**Expected duration:** 1-5 minutes
**Risk level:** Medium (can block access if misconfigured)

**Common tasks:**
- Allow HTTP/HTTPS: `sudo ufw allow 80/tcp` and `sudo ufw allow 443/tcp`
- Allow custom port: `sudo ufw allow 8080/tcp`
- Deny port: `sudo ufw deny 3306/tcp`
- View rules: `sudo ufw status numbered`

---

## Daily Operations

### Morning Check (5 minutes)

```bash
# 1. View recent alerts
bash scripts/monitoring/security_monitor.sh --view-alerts

# 2. Check system health
bash scripts/utilities/verify_security.sh

# 3. Review failed logins
bash scripts/monitoring/analyze_logs.sh
# Select option 1 (SSH Analysis)
```

### Evening Review (10 minutes)

```bash
# 1. Generate daily report
sudo bash scripts/monitoring/security_monitor.sh --report

# 2. Check for unusual activity
bash scripts/monitoring/analyze_logs.sh --report

# 3. Verify services are running
sudo systemctl status security-monitor
sudo systemctl status ssh
sudo systemctl status ufw
```

---

## Weekly Maintenance

### Monday - Security Review (15 minutes)

```bash
# 1. Check dependencies
bash scripts/updates/check_dependencies.sh --check-all

# 2. Analyze logs
bash scripts/monitoring/analyze_logs.sh --report

# 3. Verify security
bash scripts/utilities/verify_security.sh

# 4. Check for updates
bash scripts/updates/update_monitor.sh --check
```

### Wednesday - System Check (10 minutes)

```bash
# 1. Check disk space
df -h
du -sh /var/log/security-monitor/

# 2. Review Fail2Ban
sudo fail2ban-client status sshd

# 3. Check firewall
sudo ufw status numbered
```

### Friday - Update Day (20 minutes)

```bash
# 1. Check for updates
bash scripts/updates/update_monitor.sh --check

# 2. Review update history
bash scripts/updates/update_monitor.sh --changelog

# 3. Install updates if available
sudo bash scripts/updates/update_monitor.sh --update

# 4. Verify after update
bash scripts/utilities/verify_security.sh
```

---

## Monthly Reviews

### First Week - Full Audit (30 minutes)

```bash
# 1. Generate comprehensive report
bash scripts/monitoring/analyze_logs.sh --report

# 2. Check all dependencies
bash scripts/updates/check_dependencies.sh --report

# 3. Verify security configuration
bash scripts/utilities/verify_security.sh

# 4. Review update history
bash scripts/updates/update_monitor.sh --changelog

# 5. List backups
bash scripts/updates/update_monitor.sh --list-backups
```

### Second Week - Performance Review (15 minutes)

```bash
# 1. Check system resources
free -h
df -h
uptime

# 2. Review logs for errors
sudo tail -100 /var/log/syslog | grep -i error

# 3. Check service status
sudo systemctl status security-monitor
sudo fail2ban-client status
```

### Third Week - Backup Verification (10 minutes)

```bash
# 1. List backups
bash scripts/updates/update_monitor.sh --list-backups

# 2. Verify backup integrity
tar tzf /var/backups/security-monitor/backup_*.tar.gz | head -10

# 3. Test restore procedure (optional)
# Follow rollback procedure
```

### Fourth Week - Planning (10 minutes)

```bash
# 1. Review alerts and incidents
bash scripts/monitoring/security_monitor.sh --view-alerts

# 2. Plan any configuration changes
# Document needed changes

# 3. Schedule maintenance window if needed
# Plan for any major updates
```

---

## Emergency Procedures

### Under Attack - SSH Brute Force

```bash
# 1. Check attacking IPs
grep "Failed password" /var/log/auth.log | grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn

# 2. View Fail2Ban status
sudo fail2ban-client status sshd

# 3. Manually ban IP if needed
sudo ufw deny from 203.0.113.45

# 4. Monitor in real-time
sudo bash scripts/monitoring/security_monitor.sh --interactive

# 5. Generate incident report
bash scripts/monitoring/analyze_logs.sh --report
```

### Service Compromised

```bash
# 1. Immediately generate report
sudo bash scripts/monitoring/security_monitor.sh --report

# 2. Check running processes
ps aux | grep -E "nc|ncat|socat|bash"

# 3. Review sudo history
sudo grep "COMMAND=" /var/log/auth.log | tail -20

# 4. Check network connections
sudo netstat -tulpn

# 5. Review firewall rules
sudo ufw status numbered

# 6. Consider rollback if recent update
sudo bash scripts/updates/update_monitor.sh --rollback
```

### System Issues After Update

```bash
# 1. Check update log
tail -100 /var/log/security-monitor/updates.log

# 2. View service status
sudo systemctl status security-monitor

# 3. Check for errors
sudo journalctl -u security-monitor -n 50

# 4. Rollback to previous version
sudo bash scripts/updates/update_monitor.sh --rollback

# 5. Verify after rollback
bash scripts/utilities/verify_security.sh
```

### Disk Space Critical

```bash
# 1. Check disk usage
df -h
du -sh /var/log/security-monitor/

# 2. Rotate logs
sudo logrotate -f /etc/logrotate.conf

# 3. Archive old logs
sudo tar czf /backups/old_logs_$(date +%Y%m%d).tar.gz /var/log/security-monitor/

# 4. Remove archived logs
sudo rm -rf /var/log/security-monitor/alerts.log.*

# 5. Verify space freed
df -h
```

---

## Script Combinations

### Complete Security Audit

```bash
# Run all verification and analysis scripts
bash scripts/utilities/verify_security.sh
bash scripts/monitoring/analyze_logs.sh --report
bash scripts/updates/check_dependencies.sh --report
bash scripts/updates/update_monitor.sh --status
```

### Incident Response

```bash
# Gather all security information
sudo bash scripts/monitoring/security_monitor.sh --report
bash scripts/monitoring/analyze_logs.sh --report
bash scripts/utilities/verify_security.sh
sudo tail -200 /var/log/auth.log > incident_auth.log
sudo tail -200 /var/log/kern.log > incident_kern.log
```

### Pre-Maintenance Checklist

```bash
# Prepare for maintenance
bash scripts/utilities/verify_security.sh
bash scripts/updates/check_dependencies.sh --check-all
bash scripts/updates/update_monitor.sh --list-backups
bash scripts/monitoring/security_monitor.sh --status
```

---

## Automation Examples

### Daily Automated Check

```bash
# Add to crontab
0 6 * * * /usr/bin/bash /path/to/scripts/monitoring/security_monitor.sh --view-alerts >> /tmp/daily_alerts.log 2>&1
```

### Weekly Automated Report

```bash
# Add to crontab
0 7 * * 0 /usr/bin/bash /path/to/scripts/monitoring/analyze_logs.sh --report >> /tmp/weekly_report.log 2>&1
```

### Monthly Automated Audit

```bash
# Add to crontab
0 8 1 * * /usr/bin/bash /path/to/scripts/updates/check_dependencies.sh --report >> /tmp/monthly_audit.log 2>&1
```

---

## Tips and Best Practices

1. **Always test SSH in new terminal** before closing current one
2. **Keep backups** of important configurations
3. **Monitor logs regularly** for unusual activity
4. **Test procedures** in non-production first
5. **Document changes** for future reference
6. **Review alerts** daily or weekly
7. **Schedule maintenance** during low-traffic hours
8. **Keep system updated** for security patches
9. **Test rollback procedures** periodically
10. **Archive old logs** to save disk space

---

For detailed information on each script, see the documentation in the `docs/` directory.
