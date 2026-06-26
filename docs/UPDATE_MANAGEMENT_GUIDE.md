# Security Monitoring System - Update Management Guide

This guide covers automatic updates, version management, backups, and rollback procedures for the security monitoring system.

## Overview

The update management system provides:

- **Automatic Updates**: Scheduled checks and installations
- **Version Management**: Track and compare versions
- **Backup & Restore**: Automatic backups before updates
- **Rollback**: Revert to previous versions if needed
- **Dependency Management**: Check and install required packages
- **Update Notifications**: Email and Slack alerts

---

## Quick Start

### 1. Check for Updates

```bash
bash update_monitor.sh --check
```

Shows current and latest available versions.

### 2. Install Updates

```bash
sudo bash update_monitor.sh --update
```

Automatically backs up current version and installs updates.

### 3. Schedule Automatic Updates

```bash
sudo bash update_monitor.sh --schedule
```

Configure automatic update checks and installation.

### 4. View Status

```bash
bash update_monitor.sh --status
```

Display current version, configuration, and backup count.

---

## Update Scripts

### `update_monitor.sh` - Main Update Manager

**Purpose:** Manage updates, backups, and rollbacks

**Commands:**

| Command | Purpose | Requires Root |
|---------|---------|---------------|
| `--check` | Check for available updates | No |
| `--update` | Install available updates | Yes |
| `--schedule` | Configure automatic updates | Yes |
| `--show-schedule` | Display cron schedule | No |
| `--rollback` | Rollback to previous version | Yes |
| `--list-backups` | List available backups | No |
| `--status` | Show update status | No |
| `--changelog` | Show update history | No |
| `--config` | Create/edit configuration | Yes |

**Usage Examples:**

```bash
# Check for updates
bash update_monitor.sh --check

# Install updates
sudo bash update_monitor.sh --update

# Schedule weekly updates at 2 AM
sudo bash update_monitor.sh --schedule

# View available backups
bash update_monitor.sh --list-backups

# Rollback to previous version
sudo bash update_monitor.sh --rollback

# View update history
bash update_monitor.sh --changelog
```

### `check_dependencies.sh` - Dependency Manager

**Purpose:** Check and manage system dependencies

**Commands:**

| Command | Purpose |
|---------|---------|
| `--check-all` | Check all dependencies |
| `--install` | Install missing dependencies |
| `--packages` | Check system packages |
| `--python` | Check Python modules |
| `--config` | Check configuration files |
| `--services` | Check service status |
| `--disk` | Check disk space |
| `--network` | Check network connectivity |
| `--report` | Generate comprehensive report |

**Usage Examples:**

```bash
# Check all dependencies
bash check_dependencies.sh --check-all

# Install missing packages
sudo bash check_dependencies.sh --install

# Generate dependency report
bash check_dependencies.sh --report
```

---

## Configuration

### Update Configuration File

Edit `/etc/security-monitor/update.conf`:

```bash
sudo nano /etc/security-monitor/update.conf
```

**Key Settings:**

```bash
# Enable automatic updates
AUTO_UPDATE=true

# Update schedule (daily, weekly, monthly)
UPDATE_SCHEDULE="weekly"

# Time to check for updates (24-hour format)
UPDATE_TIME="02:00"

# Automatically backup before updating
AUTO_BACKUP=true

# Number of backups to keep
KEEP_BACKUPS=5

# Notify on successful updates
NOTIFY_ON_UPDATE=true

# Enable beta versions
ENABLE_BETA=false

# Verify checksums before installing
VERIFY_CHECKSUMS=true

# Email for notifications
UPDATE_EMAIL="root@localhost"

# Slack webhook for notifications (optional)
SLACK_WEBHOOK=""
```

---

## Update Process

### Automatic Update Flow

```
1. Check for new version
   ↓
2. Compare versions
   ↓
3. If update available:
   ├─ Create backup (if AUTO_BACKUP=true)
   ├─ Stop service
   ├─ Download update
   ├─ Verify integrity
   ├─ Install files
   ├─ Update version
   ├─ Start service
   └─ Send notification
```

### Manual Update

```bash
sudo bash update_monitor.sh --update
```

**What happens:**

1. Checks for available updates
2. Creates backup of current version
3. Stops security-monitor service
4. Installs new files
5. Updates version file
6. Restarts service
7. Sends notification

---

## Backup and Restore

### Automatic Backups

Backups are automatically created before each update:

```
Location: /var/backups/security-monitor/
Format: backup_<version>_<timestamp>.tar.gz
Retention: Keep last 5 backups (configurable)
```

### List Backups

```bash
bash update_monitor.sh --list-backups
```

Output:
```
Available backups:
  1) backup_1.0.0_20240626_120000
     Date: 2024-06-26 12:00:00 | Size: 2.5M

  2) backup_0.9.9_20240619_020000
     Date: 2024-06-19 02:00:00 | Size: 2.4M
```

### Restore from Backup

```bash
sudo bash update_monitor.sh --rollback
```

**Interactive process:**

1. Lists available backups
2. Prompts for backup number
3. Confirms rollback
4. Restores files and configuration
5. Restarts service

---

## Automatic Update Scheduling

### Setup Scheduled Updates

```bash
sudo bash update_monitor.sh --schedule
```

**Interactive prompts:**

```
Schedule (daily/weekly/monthly) [weekly]: weekly
Time (HH:MM) [02:00]: 02:00
```

### View Current Schedule

```bash
bash update_monitor.sh --show-schedule
```

### Manual Cron Configuration

Edit crontab:

```bash
sudo crontab -e
```

**Examples:**

```bash
# Daily updates at 2 AM
0 2 * * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --update

# Weekly updates on Sunday at 2 AM
0 2 * * 0 /usr/bin/bash /opt/security-monitor/update_monitor.sh --update

# Monthly updates on 1st at 2 AM
0 2 1 * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --update
```

---

## Version Management

### Current Version

```bash
cat /opt/security-monitor/.version
```

### Check for Updates

```bash
bash update_monitor.sh --check
```

Output:
```
[INFO] Checking for updates...
[INFO] Current version: 1.0.0
[INFO] Latest version: 1.0.1
[!] New version available: 1.0.1
```

### Version Comparison

Versions are compared using semantic versioning (X.Y.Z):

- `1.0.0` < `1.0.1` < `1.1.0` < `2.0.0`

---

## Update Notifications

### Email Notifications

Enable in configuration:

```bash
NOTIFY_ON_UPDATE=true
UPDATE_EMAIL="admin@example.com"
```

Requires mail service:

```bash
sudo bash setup_email_alerts.sh
```

### Slack Notifications

Set webhook URL in configuration:

```bash
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Syslog Notifications

Automatically logged to syslog:

```bash
sudo tail -f /var/log/syslog | grep security-monitor
```

---

## Monitoring Updates

### Update Log

View update history:

```bash
tail -50 /var/log/security-monitor/updates.log
```

### Update History

View all updates:

```bash
cat /var/backups/security-monitor/UPDATE_HISTORY
```

### Changelog

```bash
bash update_monitor.sh --changelog
```

---

## Dependency Management

### Check All Dependencies

```bash
bash check_dependencies.sh --check-all
```

**Checks:**

- System packages (curl, wget, git, etc.)
- Python modules
- Configuration files
- Service status
- File permissions
- Disk space
- Network connectivity

### Install Missing Dependencies

```bash
sudo bash check_dependencies.sh --install
```

### Generate Dependency Report

```bash
bash check_dependencies.sh --report
```

---

## Troubleshooting

### Update Failed

**Check logs:**

```bash
tail -100 /var/log/security-monitor/updates.log
```

**Verify service:**

```bash
sudo systemctl status security-monitor
```

**Manual rollback:**

```bash
sudo bash update_monitor.sh --rollback
```

### Backup Issues

**Check backup directory:**

```bash
ls -lh /var/backups/security-monitor/
```

**Verify backup integrity:**

```bash
tar tzf /var/backups/security-monitor/backup_*.tar.gz | head -10
```

### Dependency Issues

**Check specific component:**

```bash
bash check_dependencies.sh --packages
bash check_dependencies.sh --python
bash check_dependencies.sh --network
```

**Install missing packages:**

```bash
sudo bash check_dependencies.sh --install
```

### Update Schedule Issues

**Verify cron:**

```bash
sudo crontab -l | grep update_monitor
```

**Check cron logs:**

```bash
sudo grep CRON /var/log/syslog | tail -20
```

**Manually trigger update:**

```bash
sudo bash update_monitor.sh --update
```

---

## Best Practices

### Update Strategy

1. **Test Updates**: Install in test environment first
2. **Schedule Off-Peak**: Update during low-traffic hours
3. **Monitor After Update**: Check logs for issues
4. **Keep Backups**: Maintain multiple backup versions
5. **Document Changes**: Track what changed in each update

### Backup Management

1. **Regular Backups**: Enable automatic backups
2. **Test Restores**: Periodically test rollback procedures
3. **Archive Old Backups**: Move old backups to storage
4. **Monitor Disk Space**: Ensure sufficient space for backups
5. **Verify Integrity**: Check backup files regularly

### Dependency Management

1. **Regular Checks**: Run dependency checks weekly
2. **Keep Updated**: Update system packages regularly
3. **Monitor Disk Space**: Alert when usage exceeds 80%
4. **Network Monitoring**: Ensure connectivity for updates
5. **Document Requirements**: Track all dependencies

---

## Automation Examples

### Daily Update Check

```bash
# Add to crontab
0 6 * * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --check >> /tmp/update_check.log 2>&1
```

### Weekly Dependency Check

```bash
# Add to crontab
0 7 * * 0 /usr/bin/bash /opt/security-monitor/check_dependencies.sh --report >> /tmp/deps_report.log 2>&1
```

### Monthly Backup Verification

```bash
# Add to crontab
0 8 1 * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --list-backups >> /tmp/backup_list.log 2>&1
```

---

## File Locations

| File | Purpose |
|------|---------|
| `/opt/security-monitor/` | Main installation directory |
| `/opt/security-monitor/.version` | Current version file |
| `/etc/security-monitor/update.conf` | Update configuration |
| `/var/log/security-monitor/updates.log` | Update log |
| `/var/backups/security-monitor/` | Backup directory |
| `/var/backups/security-monitor/UPDATE_HISTORY` | Update history |

---

## Support

For issues:

1. Check logs: `tail -100 /var/log/security-monitor/updates.log`
2. Verify dependencies: `bash check_dependencies.sh --check-all`
3. Check status: `bash update_monitor.sh --status`
4. Review configuration: `cat /etc/security-monitor/update.conf`
5. Test manually: `sudo bash update_monitor.sh --update`

---

## Next Steps

1. ✓ Review update configuration
2. ✓ Schedule automatic updates
3. ✓ Test backup and restore
4. ✓ Check dependencies
5. ✓ Set up notifications
6. ✓ Monitor update logs

Your security monitoring system is now equipped with automated updates and backup management! 🔄
