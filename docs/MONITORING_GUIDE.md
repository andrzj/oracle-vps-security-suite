# VPS Security Monitoring and Alerting Guide

This guide covers the security monitoring and alerting tools designed to help you detect and respond to suspicious activities on your Oracle Cloud VPS.

## Overview

The monitoring suite consists of three main components:

| Tool | Purpose | Usage |
|------|---------|-------|
| `security_monitor.sh` | Real-time security monitoring and alerting | Daemon or interactive mode |
| `setup_email_alerts.sh` | Configure email notifications | One-time setup |
| `analyze_logs.sh` | Analyze logs and generate reports | On-demand analysis |

---

## Quick Start

### 1. Install Security Monitor

```bash
# Make scripts executable
chmod +x security_monitor.sh setup_email_alerts.sh analyze_logs.sh

# Install as systemd service (auto-starts on reboot)
sudo bash security_monitor.sh --install

# Verify it's running
sudo systemctl status security-monitor
```

### 2. Configure Email Alerts (Optional)

```bash
sudo bash setup_email_alerts.sh
```

### 3. View Alerts

```bash
# View recent alerts
bash security_monitor.sh --view-alerts

# Generate security report
sudo bash security_monitor.sh --report

# Analyze logs
bash analyze_logs.sh
```

---

## Security Monitor (`security_monitor.sh`)

### Monitoring Capabilities

The security monitor tracks the following security events:

#### SSH Monitoring
- Failed login attempts
- Invalid user attempts
- Root login attempts
- Successful logins
- Brute-force patterns

#### Sudo Activity
- Command executions
- Failed sudo attempts
- Privilege escalation attempts

#### Firewall Activity
- UFW blocks
- Port scanning attempts
- Suspicious connection patterns

#### System Health
- Disk usage (alerts at >90%)
- Memory usage (alerts at >90%)
- Load average spikes
- Out of memory conditions
- Kernel panics

#### Fail2Ban Integration
- Banned IP tracking
- Ban rate monitoring
- Jail status monitoring

#### Kernel Security
- Security module violations
- System warnings and errors

### Running Modes

#### Interactive Mode (Real-time Display)

```bash
# Run in interactive mode
sudo bash security_monitor.sh --interactive

# Or simply:
sudo bash security_monitor.sh
```

Shows a live dashboard that updates every 5 seconds with:
- SSH activity
- Sudo commands
- Firewall blocks
- System health metrics
- Fail2Ban status

**Best for:** Immediate security monitoring and troubleshooting

#### Daemon Mode (Background Service)

```bash
# Run as background daemon
sudo bash security_monitor.sh --daemon

# Or install as systemd service (recommended)
sudo bash security_monitor.sh --install

# Check status
sudo systemctl status security-monitor

# View logs
sudo journalctl -u security-monitor -f

# Stop service
sudo systemctl stop security-monitor
```

**Best for:** Continuous monitoring with automatic alerts

### Configuration

Edit `/etc/security-monitor/config.conf` to customize:

```bash
sudo nano /etc/security-monitor/config.conf
```

Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `ENABLE_EMAIL_ALERTS` | false | Send email notifications |
| `EMAIL_ADDRESS` | root@localhost | Email recipient |
| `ENABLE_SYSLOG_ALERTS` | true | Log to syslog |
| `ALERT_LEVEL` | 2 (MEDIUM) | Minimum alert level to show |
| `FAILED_LOGIN_THRESHOLD` | 5 | Failed attempts before alerting |
| `MONITOR_INTERVAL` | 5 | Seconds between checks |
| `ENABLE_DAILY_REPORT` | true | Generate daily reports |

### Alert Levels

| Level | Severity | Examples |
|-------|----------|----------|
| 0 | CRITICAL | Kernel panic, system compromise |
| 1 | HIGH | Multiple failed logins, root access attempts |
| 2 | MEDIUM | Firewall blocks, sudo failures |
| 3 | LOW | Successful logins, normal activity |

### Viewing Alerts

```bash
# View recent alerts
bash security_monitor.sh --view-alerts

# View last 20 alerts
tail -20 /var/log/security-monitor/alerts.log

# Follow alerts in real-time
tail -f /var/log/security-monitor/alerts.log

# Count alerts by type
grep "\[CRITICAL\]\|\[HIGH\]" /var/log/security-monitor/alerts.log | wc -l
```

### Generating Reports

```bash
# Generate security report
sudo bash security_monitor.sh --report

# Report includes:
# - System information
# - Security status
# - Recent security events
# - Failed login attempts
# - System resource usage
# - Open ports
```

---

## Email Alerts (`setup_email_alerts.sh`)

### Setup Options

#### Option 1: Local Mail Delivery (Recommended for Simple Setup)

```bash
sudo bash setup_email_alerts.sh
# Select option 1
```

This installs Postfix for local mail delivery. Emails are stored locally and can be read with:

```bash
mail
```

**Pros:** Simple, no external dependencies
**Cons:** Emails don't leave the server

#### Option 2: External SMTP (Gmail, SendGrid, etc.)

```bash
sudo bash setup_email_alerts.sh
# Select option 2
# Enter SMTP server details
```

**Pros:** Emails delivered to your inbox
**Cons:** Requires SMTP credentials

### Testing Email Configuration

```bash
sudo bash setup_email_alerts.sh
# Select option 3 to send test email
```

Or manually:

```bash
echo "Test email" | mail -s "Test Subject" your-email@example.com
```

### Enabling Email Alerts in Monitor

Edit `/etc/security-monitor/config.conf`:

```bash
ENABLE_EMAIL_ALERTS=true
EMAIL_ADDRESS="your-email@example.com"
```

Restart the monitor:

```bash
sudo systemctl restart security-monitor
```

---

## Log Analysis (`analyze_logs.sh`)

### Interactive Analysis

```bash
bash analyze_logs.sh
```

Menu options:

1. **SSH Security Analysis** - Failed logins, top attacking IPs, user attempts
2. **Firewall Analysis** - UFW blocks, blocked IPs and ports
3. **Sudo Activity** - Command executions, failed attempts
4. **System Events** - Reboots, service changes, errors
5. **Fail2Ban Analysis** - Ban statistics, jail details
6. **System Health** - Disk, memory, CPU, uptime
7. **Security Alerts** - Alert summary and recent alerts
8. **Generate Full Report** - Complete analysis report

### Generate Full Report

```bash
bash analyze_logs.sh --report
```

Creates a comprehensive report file with all analyses.

### Sample Output

```
=== SSH Security Analysis ===

Failed Login Attempts (Last 24 hours)
  Failed attempts: 42

Top 10 IPs with Failed Logins
    15 attempts from 203.0.113.45
     8 attempts from 198.51.100.22
     7 attempts from 192.0.2.10
     ...

Top 10 Invalid Usernames
    12 attempts for: admin
     8 attempts for: test
     5 attempts for: root
     ...
```

---

## Common Scenarios

### Scenario 1: Brute-Force SSH Attack

**Detection:**
- Monitor shows high failed login rate
- Specific IP appears multiple times
- Fail2Ban has banned the IP

**Response:**
```bash
# View attack details
bash analyze_logs.sh
# Select option 1 (SSH Analysis)

# Check Fail2Ban status
sudo fail2ban-client status sshd

# Manually ban IP if needed
sudo ufw deny from 203.0.113.45

# View attacker's attempts
grep "203.0.113.45" /var/log/auth.log
```

### Scenario 2: Unusual Sudo Activity

**Detection:**
- Monitor alerts on failed sudo attempts
- Unexpected sudo commands executed

**Response:**
```bash
# Analyze sudo activity
bash analyze_logs.sh
# Select option 3 (Sudo Analysis)

# View specific user's sudo history
sudo grep "user=username" /var/log/auth.log

# Check if user should have sudo access
sudo visudo -c  # Verify sudoers file
```

### Scenario 3: High System Resource Usage

**Detection:**
- Monitor shows >90% disk or memory usage
- Load average spike

**Response:**
```bash
# Check system health
bash analyze_logs.sh
# Select option 6 (System Health)

# Find large files
du -sh /* | sort -rh | head -10

# Check memory usage
free -h
ps aux --sort=-%mem | head -10

# Check disk usage
df -h
```

### Scenario 4: Firewall Blocks

**Detection:**
- Monitor shows UFW blocks
- Unusual port access attempts

**Response:**
```bash
# Analyze firewall activity
bash analyze_logs.sh
# Select option 2 (Firewall Analysis)

# View UFW logs
sudo tail -50 /var/log/kern.log | grep UFW

# Check current firewall rules
sudo ufw status numbered
```

---

## Best Practices

### Regular Monitoring

1. **Daily:** Check alerts and generate reports
   ```bash
   sudo bash security_monitor.sh --report
   ```

2. **Weekly:** Analyze logs for patterns
   ```bash
   bash analyze_logs.sh --report
   ```

3. **Monthly:** Review and update security policies

### Alert Response

1. **CRITICAL alerts:** Investigate immediately
2. **HIGH alerts:** Investigate within 1 hour
3. **MEDIUM alerts:** Review daily
4. **LOW alerts:** Archive for reference

### Log Rotation

Ensure logs don't consume all disk space:

```bash
# Check log rotation config
cat /etc/logrotate.d/rsyslog

# Manually rotate logs if needed
sudo logrotate -f /etc/logrotate.conf
```

### Archive Important Logs

```bash
# Backup security logs
sudo tar czf security_logs_$(date +%Y%m%d).tar.gz /var/log/auth.log /var/log/security-monitor/

# Upload to Object Storage
# (Use Oracle Cloud CLI or web console)
```

---

## Troubleshooting

### Monitor Not Alerting

1. Check if service is running:
   ```bash
   sudo systemctl status security-monitor
   ```

2. Check configuration:
   ```bash
   cat /etc/security-monitor/config.conf
   ```

3. View service logs:
   ```bash
   sudo journalctl -u security-monitor -n 50
   ```

4. Restart service:
   ```bash
   sudo systemctl restart security-monitor
   ```

### Email Alerts Not Working

1. Test mail system:
   ```bash
   echo "Test" | mail -s "Test" root@localhost
   ```

2. Check mail logs:
   ```bash
   sudo tail -50 /var/log/mail.log
   ```

3. Verify Postfix is running:
   ```bash
   sudo systemctl status postfix
   ```

4. Re-run setup:
   ```bash
   sudo bash setup_email_alerts.sh
   ```

### High False Positive Rate

1. Adjust alert level in config:
   ```bash
   ALERT_LEVEL=3  # Only show HIGH and CRITICAL
   ```

2. Increase failed login threshold:
   ```bash
   FAILED_LOGIN_THRESHOLD=10
   ```

3. Whitelist trusted IPs:
   ```bash
   WHITELIST_IPS="192.168.1.100,10.0.0.5"
   ```

### Logs Growing Too Large

1. Check log sizes:
   ```bash
   du -sh /var/log/security-monitor/
   ```

2. Rotate logs manually:
   ```bash
   sudo logrotate -f /etc/logrotate.d/security-monitor
   ```

3. Archive old logs:
   ```bash
   sudo tar czf old_alerts.tar.gz /var/log/security-monitor/alerts.log.*
   ```

---

## Performance Considerations

### Monitoring Overhead

- CPU: <1% (minimal)
- Memory: ~20-50 MB
- Disk I/O: Minimal (log reading only)

### Optimization Tips

1. Increase monitoring interval if needed:
   ```bash
   MONITOR_INTERVAL=10  # Check every 10 seconds instead of 5
   ```

2. Disable unused monitors:
   ```bash
   MONITOR_SSH=false
   MONITOR_SUDO=false
   ```

3. Reduce alert level:
   ```bash
   ALERT_LEVEL=1  # Only CRITICAL and HIGH
   ```

---

## Integration with Other Tools

### Syslog Integration

Alerts are automatically logged to syslog. View with:

```bash
sudo tail -f /var/log/syslog | grep security-monitor
```

### Fail2Ban Integration

Monitor automatically tracks Fail2Ban activity. View with:

```bash
sudo fail2ban-client status
```

### System Monitoring

Combine with other monitoring tools:

```bash
# Prometheus/Grafana
# Datadog
# New Relic
# CloudWatch (if using AWS)
```

---

## Support and Issues

For issues:

1. Check troubleshooting section above
2. Review script logs: `sudo journalctl -u security-monitor`
3. Verify configuration: `cat /etc/security-monitor/config.conf`
4. Test manually: `bash analyze_logs.sh`

---

## Next Steps

1. ✓ Install security monitor
2. ✓ Configure email alerts (optional)
3. ✓ Set up daily reports
4. ✓ Review logs regularly
5. ✓ Respond to alerts promptly
6. ✓ Archive logs periodically

Your VPS is now under continuous security monitoring! 🔒📊
