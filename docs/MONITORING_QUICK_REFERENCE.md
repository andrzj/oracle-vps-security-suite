# Security Monitoring - Quick Reference

## Installation (One-Time Setup)

```bash
# Make scripts executable
chmod +x security_monitor.sh setup_email_alerts.sh analyze_logs.sh

# Install as systemd service (recommended)
sudo bash security_monitor.sh --install

# Verify installation
sudo systemctl status security-monitor
```

## Daily Commands

```bash
# View recent alerts
bash security_monitor.sh --view-alerts

# Generate security report
sudo bash security_monitor.sh --report

# Analyze security logs
bash analyze_logs.sh

# Check Fail2Ban status
sudo fail2ban-client status sshd
```

## Running Modes

| Mode | Command | Best For |
|------|---------|----------|
| Interactive | `sudo bash security_monitor.sh --interactive` | Real-time monitoring |
| Daemon | `sudo bash security_monitor.sh --daemon` | Background service |
| Service | `sudo systemctl start security-monitor` | Auto-start on reboot |
| View Alerts | `bash security_monitor.sh --view-alerts` | Checking alerts |
| Report | `sudo bash security_monitor.sh --report` | Summary report |

## Service Management

```bash
# Start monitoring service
sudo systemctl start security-monitor

# Stop monitoring service
sudo systemctl stop security-monitor

# Restart monitoring service
sudo systemctl restart security-monitor

# Check service status
sudo systemctl status security-monitor

# View service logs
sudo journalctl -u security-monitor -f

# View last 50 log lines
sudo journalctl -u security-monitor -n 50

# Enable auto-start on reboot
sudo systemctl enable security-monitor

# Disable auto-start
sudo systemctl disable security-monitor
```

## Configuration

```bash
# View configuration
cat /etc/security-monitor/config.conf

# Edit configuration
sudo nano /etc/security-monitor/config.conf

# Create/reset configuration
sudo bash security_monitor.sh --config

# Reload configuration
sudo systemctl restart security-monitor
```

## Email Alerts Setup

```bash
# Configure email alerts
sudo bash setup_email_alerts.sh

# Test email
echo "Test" | mail -s "Test Subject" root@localhost

# View local mail
mail
```

## Log Analysis

```bash
# Interactive analysis menu
bash analyze_logs.sh

# Generate full report
bash analyze_logs.sh --report

# SSH analysis
bash analyze_logs.sh
# Select option 1

# Firewall analysis
bash analyze_logs.sh
# Select option 2

# System health
bash analyze_logs.sh
# Select option 6
```

## Viewing Logs

```bash
# View alert log
tail -50 /var/log/security-monitor/alerts.log

# Follow alerts in real-time
tail -f /var/log/security-monitor/alerts.log

# Count alerts by level
grep -c "\[CRITICAL\]" /var/log/security-monitor/alerts.log
grep -c "\[HIGH\]" /var/log/security-monitor/alerts.log
grep -c "\[MEDIUM\]" /var/log/security-monitor/alerts.log

# Search for specific alerts
grep "SSH Failed" /var/log/security-monitor/alerts.log
grep "Firewall" /var/log/security-monitor/alerts.log
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Monitor not alerting | `sudo systemctl restart security-monitor` |
| Email not working | `sudo bash setup_email_alerts.sh` |
| Too many alerts | Increase `ALERT_LEVEL` in config |
| High CPU usage | Increase `MONITOR_INTERVAL` in config |
| Logs too large | `sudo logrotate -f /etc/logrotate.conf` |

## Alert Levels

| Level | Severity | Examples |
|-------|----------|----------|
| CRITICAL | Highest | Kernel panic, system compromise |
| HIGH | High | Root login attempts, multiple failed logins |
| MEDIUM | Medium | Firewall blocks, sudo failures |
| LOW | Low | Successful logins, normal activity |

## Key Metrics to Monitor

### SSH Security
- Failed login attempts (threshold: >5 per hour)
- Invalid user attempts
- Root login attempts
- Successful login count

### System Health
- Disk usage (alert: >90%)
- Memory usage (alert: >90%)
- Load average (alert: >CPU count)

### Firewall
- UFW blocks (unusual patterns)
- Blocked source IPs
- Blocked destination ports

### Fail2Ban
- Banned IP count
- Ban rate
- Jail status

## Emergency Response

### If Compromised

```bash
# 1. View recent SSH logins
grep "Accepted" /var/log/auth.log | tail -20

# 2. Check running processes
ps aux | grep -E "nc|ncat|socat"

# 3. View sudo history
sudo grep "COMMAND=" /var/log/auth.log

# 4. Check firewall rules
sudo ufw status numbered

# 5. View network connections
sudo netstat -tulpn

# 6. Generate full report
sudo bash security_monitor.sh --report
```

### If Under Attack

```bash
# 1. View attacking IPs
grep "Failed password" /var/log/auth.log | grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn

# 2. Block attacking IP
sudo ufw deny from 203.0.113.45

# 3. Check Fail2Ban status
sudo fail2ban-client status sshd

# 4. View firewall blocks
sudo tail -100 /var/log/kern.log | grep UFW

# 5. Monitor in real-time
sudo bash security_monitor.sh --interactive
```

## File Locations

| File | Purpose |
|------|---------|
| `/etc/security-monitor/config.conf` | Configuration file |
| `/var/log/security-monitor/alerts.log` | Alert log |
| `/var/run/security-monitor.pid` | Process ID file |
| `/var/lib/security-monitor/` | State files |
| `/var/log/auth.log` | Authentication log |
| `/var/log/kern.log` | Kernel log |
| `/var/log/syslog` | System log |

## Tips & Tricks

```bash
# Count alerts by type
grep "\[CRITICAL\]\|\[HIGH\]" /var/log/security-monitor/alerts.log | \
  grep -oP '(?<=\] )\S+' | sort | uniq -c | sort -rn

# Export alerts to file
cp /var/log/security-monitor/alerts.log alerts_backup_$(date +%Y%m%d).log

# Monitor specific user activity
grep "username" /var/log/auth.log | tail -20

# Check for privilege escalation attempts
grep "sudo.*sorry" /var/log/auth.log

# Find all failed logins in last hour
grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d %H')"
```

## Automation

### Daily Report via Cron

```bash
# Edit crontab
crontab -e

# Add this line to run daily at 6 AM
0 6 * * * /usr/bin/bash /home/ubuntu/security_monitor.sh --report >> /tmp/daily_report.log 2>&1
```

### Weekly Analysis

```bash
# Add to crontab
0 7 * * 0 /usr/bin/bash /home/ubuntu/analyze_logs.sh --report >> /tmp/weekly_analysis.log 2>&1
```

## Performance

- **CPU Usage:** <1%
- **Memory Usage:** 20-50 MB
- **Disk I/O:** Minimal
- **Monitoring Interval:** 5 seconds (configurable)

## Next Steps

1. ✓ Install security monitor
2. ✓ Configure email alerts
3. ✓ Set up daily reports
4. ✓ Review logs regularly
5. ✓ Respond to alerts promptly

For detailed information, see `MONITORING_GUIDE.md`
