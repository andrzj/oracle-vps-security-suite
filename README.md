# Oracle Cloud VPS Security Suite

A comprehensive collection of automated security hardening, monitoring, and maintenance scripts for Debian-based VPS instances on Oracle Cloud free tier. This suite provides production-ready tools for securing and maintaining a public-facing server with minimal manual intervention.

## 🎯 Overview

The Oracle Cloud VPS Security Suite provides complete security automation across four key areas:

| Category | Purpose | Scripts |
|----------|---------|---------|
| **Hardening** | Initial security configuration | SSH hardening, firewall setup, kernel parameters |
| **Monitoring** | Real-time threat detection | Log monitoring, alert system, analysis tools |
| **Updates** | Automated maintenance | Version management, backups, rollback |
| **Utilities** | Ongoing management | Verification, configuration, reporting |

## 📋 Quick Start

### Prerequisites

- Debian-based VPS (Ubuntu 20.04+, Debian 10+)
- Root or sudo access
- Internet connectivity
- ~100 MB disk space for scripts and logs

### Installation (5 minutes)

```bash
# Clone the repository
git clone https://github.com/andrzj/oracle-vps-security-suite.git
cd oracle-vps-security-suite

# Make scripts executable
chmod +x scripts/**/*.sh

# Run initial security hardening
sudo bash scripts/hardening/debian_security_hardening.sh

# Verify installation
bash scripts/utilities/verify_security.sh

# Install monitoring (optional but recommended)
sudo bash scripts/monitoring/security_monitor.sh --install
```

## 📦 Scripts Overview

### Hardening Scripts (`scripts/hardening/`)

#### 1. `debian_security_hardening.sh` - Main Hardening Script
**Purpose:** Complete security hardening in one command
**When to use:** First time setup, initial server configuration
**Time:** 5-15 minutes
**What it does:**
- Updates all system packages
- Hardens SSH daemon (disables root login, password auth)
- Enables UFW firewall with sensible defaults
- Installs and configures Fail2Ban
- Applies kernel hardening parameters
- Enables automatic security updates
- Initializes AIDE file integrity monitoring

```bash
# Run once during initial setup
sudo bash scripts/hardening/debian_security_hardening.sh

# Verify in new terminal before closing current one
ssh -i your-key.pem ubuntu@your-instance-ip
```

**Key Outputs:**
- Hardened SSH configuration
- Active UFW firewall
- Running Fail2Ban service
- Automatic security updates enabled

#### 2. `setup_ssh_2fa.sh` - Two-Factor Authentication
**Purpose:** Add Google Authenticator-based 2FA to SSH
**When to use:** After initial hardening, for enhanced security
**Time:** 2 minutes
**Prerequisites:** Main hardening script must be run first

```bash
# Setup 2FA
sudo bash scripts/hardening/setup_ssh_2fa.sh

# As regular user, generate 2FA secret
google-authenticator

# Scan QR code with authenticator app
# Save emergency codes securely
```

**Key Features:**
- Requires both SSH key AND 6-digit code
- Emergency codes for recovery
- Minimal performance impact

---

### Monitoring Scripts (`scripts/monitoring/`)

#### 1. `security_monitor.sh` - Real-time Security Monitoring
**Purpose:** Continuous monitoring and alerting for security events
**When to use:** After hardening, runs 24/7
**Modes:** Interactive, daemon, or systemd service
**Monitors:**
- SSH brute-force attempts
- Privilege escalation attempts
- Firewall blocks
- System resource usage
- Fail2Ban activity

```bash
# Install as systemd service (recommended)
sudo bash scripts/monitoring/security_monitor.sh --install

# Run interactively (for testing)
sudo bash scripts/monitoring/security_monitor.sh --interactive

# View recent alerts
bash scripts/monitoring/security_monitor.sh --view-alerts

# Generate security report
sudo bash scripts/monitoring/security_monitor.sh --report
```

**Alert Levels:**
- CRITICAL: Kernel panic, system compromise
- HIGH: Root login attempts, multiple failed logins
- MEDIUM: Firewall blocks, sudo failures
- LOW: Successful logins, normal activity

#### 2. `setup_email_alerts.sh` - Email Configuration
**Purpose:** Configure email notifications for security alerts
**When to use:** After installing security monitor
**Time:** 2-5 minutes
**Options:**
- Local mail delivery (Postfix)
- External SMTP (Gmail, SendGrid, etc.)

```bash
# Configure email alerts
sudo bash scripts/monitoring/setup_email_alerts.sh

# Test email
echo "Test" | mail -s "Test Subject" root@localhost
```

#### 3. `analyze_logs.sh` - Log Analysis Tool
**Purpose:** Deep analysis of security logs and patterns
**When to use:** Daily/weekly security reviews, incident investigation
**Time:** 1-5 minutes
**Analysis Types:**
- SSH security analysis (failed logins, attacking IPs)
- Firewall analysis (blocked connections)
- Sudo activity analysis
- System events analysis
- Fail2Ban statistics
- System health metrics
- Security alerts summary

```bash
# Interactive analysis menu
bash scripts/monitoring/analyze_logs.sh

# Generate full report
bash scripts/monitoring/analyze_logs.sh --report
```

---

### Update Scripts (`scripts/updates/`)

#### 1. `update_monitor.sh` - Automatic Update Manager
**Purpose:** Manage updates, backups, and version rollback
**When to use:** Ongoing maintenance, scheduled updates
**Modes:** Manual, automatic, scheduled
**Features:**
- Check for available updates
- Automatic backup before updates
- Version rollback capability
- Scheduled updates via cron
- Update notifications

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

#### 2. `check_dependencies.sh` - Dependency Manager
**Purpose:** Verify and install system dependencies
**When to use:** Before initial setup, troubleshooting, maintenance
**Checks:**
- System packages
- Python modules
- Configuration files
- Service status
- File permissions
- Disk space
- Network connectivity

```bash
# Check all dependencies
bash scripts/updates/check_dependencies.sh --check-all

# Install missing packages
sudo bash scripts/updates/check_dependencies.sh --install

# Generate dependency report
bash scripts/updates/check_dependencies.sh --report
```

---

### Utility Scripts (`scripts/utilities/`)

#### 1. `verify_security.sh` - Security Verification
**Purpose:** Verify security configurations are properly applied
**When to use:** After hardening, periodic verification
**Time:** 1 minute
**Checks:**
- SSH configuration hardening
- Firewall configuration and status
- Fail2Ban installation and operation
- System hardening parameters
- Automatic updates configuration

```bash
# Verify security settings
bash scripts/utilities/verify_security.sh

# With monitoring
bash scripts/utilities/verify_security.sh --monitor
```

#### 2. `configure_firewall.sh` - Firewall Management
**Purpose:** Interactive firewall rule management
**When to use:** After hardening, when adding services
**Time:** 1-5 minutes
**Features:**
- View current rules
- Allow/deny ports
- Add custom rules
- Change SSH port
- Enable/disable firewall

```bash
# Interactive firewall menu
sudo bash scripts/utilities/configure_firewall.sh
```

---

## 📖 Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| `docs/oracle_cloud_security_guide.md` | Security concepts and best practices | All users |
| `docs/QUICK_START.md` | Step-by-step setup guide | New users |
| `docs/SECURITY_SCRIPTS_README.md` | Detailed script documentation | Developers |
| `docs/MONITORING_GUIDE.md` | Monitoring system usage | Operators |
| `docs/MONITORING_QUICK_REFERENCE.md` | Quick command reference | Daily use |
| `docs/UPDATE_MANAGEMENT_GUIDE.md` | Update procedures | Maintainers |
| `docs/UPDATE_QUICK_REFERENCE.md` | Update commands | Daily use |

## 🚀 Common Workflows

### Initial Setup (30 minutes)

```bash
# 1. Clone repository
git clone https://github.com/andrzj/oracle-vps-security-suite.git
cd oracle-vps-security-suite

# 2. Check dependencies
bash scripts/updates/check_dependencies.sh --check-all

# 3. Run main hardening
sudo bash scripts/hardening/debian_security_hardening.sh

# 4. Verify in new terminal
bash scripts/utilities/verify_security.sh

# 5. Install monitoring
sudo bash scripts/monitoring/security_monitor.sh --install

# 6. Configure email alerts (optional)
sudo bash scripts/monitoring/setup_email_alerts.sh

# 7. Schedule automatic updates
sudo bash scripts/updates/update_monitor.sh --schedule
```

### Daily Operations

```bash
# Check for alerts
bash scripts/monitoring/security_monitor.sh --view-alerts

# Review logs
bash scripts/monitoring/analyze_logs.sh

# Check system health
bash scripts/utilities/verify_security.sh --monitor
```

### Weekly Maintenance

```bash
# Generate security report
sudo bash scripts/monitoring/security_monitor.sh --report

# Check dependencies
bash scripts/updates/check_dependencies.sh --check-all

# Analyze logs
bash scripts/monitoring/analyze_logs.sh --report

# Check for updates
bash scripts/updates/update_monitor.sh --check
```

### Monthly Review

```bash
# Full security verification
bash scripts/utilities/verify_security.sh

# Review update history
bash scripts/updates/update_monitor.sh --changelog

# List backups
bash scripts/updates/update_monitor.sh --list-backups

# Generate comprehensive report
bash scripts/monitoring/analyze_logs.sh --report
```

## 🔄 Update Schedule

### Recommended Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Security updates | Automatic | Enabled by default |
| Dependency check | Weekly | `check_dependencies.sh --check-all` |
| Log analysis | Weekly | `analyze_logs.sh --report` |
| Security report | Monthly | `security_monitor.sh --report` |
| Backup verification | Monthly | `update_monitor.sh --list-backups` |

### Automatic Scheduling

```bash
# Configure automatic updates
sudo bash scripts/updates/update_monitor.sh --schedule

# View cron schedule
sudo crontab -l | grep update_monitor
```

## 📊 Monitoring Dashboard

### Real-time Monitoring

```bash
# Start interactive monitoring
sudo bash scripts/monitoring/security_monitor.sh --interactive
```

Shows live updates of:
- SSH authentication attempts
- Sudo command executions
- Firewall blocks
- System resource usage
- Fail2Ban activity

### Alert Viewing

```bash
# View recent alerts
bash scripts/monitoring/security_monitor.sh --view-alerts

# Follow alerts in real-time
tail -f /var/log/security-monitor/alerts.log

# Count alerts by type
grep -c "\[CRITICAL\]" /var/log/security-monitor/alerts.log
```

## 🔐 Security Features

### SSH Hardening
- ✓ Root login disabled
- ✓ Password authentication disabled
- ✓ Strong key exchange algorithms
- ✓ Strong ciphers and MACs
- ✓ Optional 2FA/MFA

### Firewall Protection
- ✓ UFW enabled with default deny
- ✓ Fail2Ban for brute-force protection
- ✓ Automatic IP banning
- ✓ Port-based access control

### System Hardening
- ✓ Kernel parameter hardening
- ✓ Automatic security updates
- ✓ File integrity monitoring (AIDE)
- ✓ Password security policies

### Monitoring & Alerting
- ✓ Real-time log monitoring
- ✓ Email and syslog alerts
- ✓ Threat detection
- ✓ Security reporting

## 🛠️ Troubleshooting

### SSH Connection Issues

```bash
# Check SSH status
sudo systemctl status ssh

# Verify SSH configuration
sudo sshd -t

# Check firewall rules
sudo ufw status

# View SSH logs
sudo tail -50 /var/log/auth.log
```

### Monitoring Issues

```bash
# Check service status
sudo systemctl status security-monitor

# View service logs
sudo journalctl -u security-monitor -f

# Verify configuration
cat /etc/security-monitor/config.conf

# Restart service
sudo systemctl restart security-monitor
```

### Update Issues

```bash
# Check update log
tail -100 /var/log/security-monitor/updates.log

# List available backups
bash scripts/updates/update_monitor.sh --list-backups

# Rollback to previous version
sudo bash scripts/updates/update_monitor.sh --rollback
```

## 📁 Directory Structure

```
oracle-vps-security-suite/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore rules
├── scripts/
│   ├── hardening/
│   │   ├── debian_security_hardening.sh
│   │   └── setup_ssh_2fa.sh
│   ├── monitoring/
│   │   ├── security_monitor.sh
│   │   ├── setup_email_alerts.sh
│   │   └── analyze_logs.sh
│   ├── updates/
│   │   ├── update_monitor.sh
│   │   └── check_dependencies.sh
│   └── utilities/
│       ├── verify_security.sh
│       └── configure_firewall.sh
├── docs/
│   ├── oracle_cloud_security_guide.md
│   ├── QUICK_START.md
│   ├── SECURITY_SCRIPTS_README.md
│   ├── MONITORING_GUIDE.md
│   ├── MONITORING_QUICK_REFERENCE.md
│   ├── UPDATE_MANAGEMENT_GUIDE.md
│   └── UPDATE_QUICK_REFERENCE.md
├── examples/
│   ├── cron_schedules.txt
│   ├── config_examples/
│   └── troubleshooting_scenarios.md
└── .github/
    └── workflows/
        └── security_checks.yml
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Important Notes

### Before Using

1. **Backup Your Data**: These scripts make significant system changes
2. **Test First**: Test in a non-production environment first
3. **Review Scripts**: Read scripts before running them
4. **Keep SSH Key**: Ensure you have backup access to your instance
5. **Monitor After Changes**: Watch logs after applying changes

### Oracle Cloud Free Tier Specifics

- **Idle Instance Reclamation**: Keep instances active (>20% CPU/network for 7 days)
- **No NAT Gateway**: Public IPs required for outbound traffic
- **Limited Bandwidth**: 50 Mbps internet bandwidth
- **Storage Limits**: 200 GB block storage, 20 GB object storage

## 🆘 Support

For issues or questions:

1. Check the relevant documentation in `docs/`
2. Review the troubleshooting section above
3. Check script logs: `/var/log/security-monitor/`
4. Open an issue on GitHub

## 🎓 Learning Resources

- [Oracle Cloud Documentation](https://docs.oracle.com/iaas/)
- [Linux Security Best Practices](https://github.com/imthenachoman/How-To-Secure-A-Linux-Server)
- [UFW Firewall Guide](https://help.ubuntu.com/community/UFW)
- [Fail2Ban Documentation](https://www.fail2ban.org/)

## 📞 Contact

- GitHub Issues: [Report bugs or request features](https://github.com/andrzj/oracle-vps-security-suite/issues)
- Discussions: [Ask questions and share ideas](https://github.com/andrzj/oracle-vps-security-suite/discussions)

---

**Last Updated:** June 2024
**Version:** 1.0.0
**Tested On:** Ubuntu 22.04 LTS, Debian 11+

Made with ❤️ for Oracle Cloud VPS users
