# Update Management - Quick Reference

## Essential Commands

### Check for Updates
```bash
bash update_monitor.sh --check
```

### Install Updates
```bash
sudo bash update_monitor.sh --update
```

### Schedule Automatic Updates
```bash
sudo bash update_monitor.sh --schedule
```

### View Status
```bash
bash update_monitor.sh --status
```

### Rollback to Previous Version
```bash
sudo bash update_monitor.sh --rollback
```

---

## Update Management

| Task | Command |
|------|---------|
| Check for updates | `bash update_monitor.sh --check` |
| Install updates | `sudo bash update_monitor.sh --update` |
| Schedule updates | `sudo bash update_monitor.sh --schedule` |
| View schedule | `bash update_monitor.sh --show-schedule` |
| List backups | `bash update_monitor.sh --list-backups` |
| Rollback version | `sudo bash update_monitor.sh --rollback` |
| View status | `bash update_monitor.sh --status` |
| View changelog | `bash update_monitor.sh --changelog` |
| Edit config | `sudo nano /etc/security-monitor/update.conf` |

---

## Dependency Management

| Task | Command |
|------|---------|
| Check all | `bash check_dependencies.sh --check-all` |
| Install missing | `sudo bash check_dependencies.sh --install` |
| Check packages | `bash check_dependencies.sh --packages` |
| Check Python | `bash check_dependencies.sh --python` |
| Check config | `bash check_dependencies.sh --config` |
| Check services | `bash check_dependencies.sh --services` |
| Check disk | `bash check_dependencies.sh --disk` |
| Check network | `bash check_dependencies.sh --network` |
| Generate report | `bash check_dependencies.sh --report` |

---

## Service Management

| Task | Command |
|------|---------|
| Check status | `sudo systemctl status security-monitor` |
| Start service | `sudo systemctl start security-monitor` |
| Stop service | `sudo systemctl stop security-monitor` |
| Restart service | `sudo systemctl restart security-monitor` |
| View logs | `sudo journalctl -u security-monitor -f` |
| Enable auto-start | `sudo systemctl enable security-monitor` |
| Disable auto-start | `sudo systemctl disable security-monitor` |

---

## Backup Operations

| Task | Command |
|------|---------|
| List backups | `bash update_monitor.sh --list-backups` |
| View backup dir | `ls -lh /var/backups/security-monitor/` |
| Restore backup | `sudo bash update_monitor.sh --rollback` |
| Check backup size | `du -sh /var/backups/security-monitor/` |
| Verify backup | `tar tzf /var/backups/security-monitor/backup_*.tar.gz` |

---

## Logging and Monitoring

| Log File | Purpose |
|----------|---------|
| `/var/log/security-monitor/updates.log` | Update operations |
| `/var/backups/security-monitor/UPDATE_HISTORY` | Update history |
| `/var/log/syslog` | System logs |
| `sudo journalctl -u security-monitor` | Service logs |

---

## Configuration

### Edit Update Config
```bash
sudo nano /etc/security-monitor/update.conf
```

### Key Settings
```bash
AUTO_UPDATE=true              # Enable auto-updates
UPDATE_SCHEDULE="weekly"      # daily, weekly, monthly
UPDATE_TIME="02:00"           # Time to update
AUTO_BACKUP=true              # Backup before update
KEEP_BACKUPS=5                # Backups to retain
NOTIFY_ON_UPDATE=true         # Send notifications
```

---

## Cron Scheduling

### View Current Schedule
```bash
sudo crontab -l | grep update_monitor
```

### Edit Schedule
```bash
sudo crontab -e
```

### Common Schedules
```bash
# Daily at 2 AM
0 2 * * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --update

# Weekly on Sunday at 2 AM
0 2 * * 0 /usr/bin/bash /opt/security-monitor/update_monitor.sh --update

# Monthly on 1st at 2 AM
0 2 1 * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --update
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Update failed | Check logs: `tail -100 /var/log/security-monitor/updates.log` |
| Service won't start | Check status: `sudo systemctl status security-monitor` |
| Backup issues | Verify space: `df -h /var/backups/` |
| Dependency missing | Install: `sudo bash check_dependencies.sh --install` |
| Network issues | Test: `bash check_dependencies.sh --network` |

---

## Emergency Rollback

```bash
# 1. List available backups
bash update_monitor.sh --list-backups

# 2. Rollback to previous version
sudo bash update_monitor.sh --rollback

# 3. Verify service is running
sudo systemctl status security-monitor

# 4. Check version
cat /opt/security-monitor/.version
```

---

## Performance

- **Update Time**: 2-5 minutes
- **Backup Size**: ~2-3 MB per backup
- **Disk Space**: ~15-20 MB for 5 backups
- **Service Downtime**: <1 minute

---

## Version Format

Versions follow semantic versioning: `X.Y.Z`

- `X` = Major version (breaking changes)
- `Y` = Minor version (new features)
- `Z` = Patch version (bug fixes)

Example: `1.0.0` → `1.0.1` (patch) → `1.1.0` (minor) → `2.0.0` (major)

---

## Notifications

### Email Alerts
```bash
NOTIFY_ON_UPDATE=true
UPDATE_EMAIL="admin@example.com"
```

### Slack Alerts
```bash
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Syslog
```bash
sudo tail -f /var/log/syslog | grep security-monitor
```

---

## Automation

### Daily Update Check
```bash
0 6 * * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --check
```

### Weekly Dependency Check
```bash
0 7 * * 0 /usr/bin/bash /opt/security-monitor/check_dependencies.sh --check-all
```

### Monthly Backup Verification
```bash
0 8 1 * * /usr/bin/bash /opt/security-monitor/update_monitor.sh --list-backups
```

---

## File Locations

```
/opt/security-monitor/              # Installation directory
/opt/security-monitor/.version      # Current version
/etc/security-monitor/update.conf   # Update configuration
/var/log/security-monitor/          # Log directory
/var/backups/security-monitor/      # Backup directory
```

---

## Next Steps

1. ✓ Review update configuration
2. ✓ Schedule automatic updates
3. ✓ Test backup and restore
4. ✓ Check dependencies
5. ✓ Set up notifications

For detailed information, see `UPDATE_MANAGEMENT_GUIDE.md`
