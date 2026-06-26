# Scripts Reference

Quick reference guide for all scripts in the Oracle Cloud VPS Security Suite.

## Hardening Scripts

### debian_security_hardening.sh

**Location:** `scripts/hardening/debian_security_hardening.sh`
**Size:** ~15 KB
**Type:** Main hardening script
**Frequency:** Run once during initial setup

#### Purpose
Complete security hardening for Debian/Ubuntu VPS in a single command.

#### When to Use
- First time server setup
- Initial security configuration
- After fresh OS installation

#### How to Run
```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

#### What It Does
- Updates system packages
- Hardens SSH daemon
- Enables UFW firewall
- Installs Fail2Ban
- Applies kernel hardening
- Enables automatic security updates
- Initializes AIDE file integrity monitoring

#### Time Required
5-15 minutes

#### Risk Level
Medium (requires SSH verification)

#### Rollback
- SSH config backed up to `/etc/ssh/sshd_config.backup*`
- Restore with: `sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config`

#### Important Notes
- Do NOT close SSH session after running
- Test SSH in new terminal before closing current one
- Review backed up files before restoring

---

### setup_ssh_2fa.sh

**Location:** `scripts/hardening/setup_ssh_2fa.sh`
**Size:** ~3.5 KB
**Type:** Optional security enhancement
**Frequency:** Run once after main hardening

#### Purpose
Add Google Authenticator-based 2FA/MFA to SSH login.

#### When to Use
- After initial hardening
- For enhanced security
- When 2FA is required

#### How to Run
```bash
sudo bash scripts/hardening/setup_ssh_2fa.sh
```

#### What It Does
- Installs Google Authenticator
- Configures PAM for 2FA
- Generates QR code
- Creates emergency recovery codes

#### Time Required
2 minutes

#### Risk Level
Low (can be disabled easily)

#### Requirements
- Main hardening script must be run first
- Authenticator app on phone (Google Authenticator, Authy, etc.)

#### Steps
1. Run script
2. Scan QR code with authenticator app
3. Save emergency codes securely
4. Test login with code

#### Disable 2FA
```bash
sudo nano /etc/pam.d/sshd
# Comment out the google_authenticator line
```

---

## Monitoring Scripts

### security_monitor.sh

**Location:** `scripts/monitoring/security_monitor.sh`
**Size:** ~24 KB
**Type:** Real-time monitoring daemon
**Frequency:** Runs continuously

#### Purpose
Real-time security monitoring and alerting for threats and suspicious activities.

#### When to Use
- After hardening is complete
- For continuous security monitoring
- 24/7 threat detection

#### How to Run
```bash
# Install as systemd service (recommended)
sudo bash scripts/monitoring/security_monitor.sh --install

# Run interactively (for testing)
sudo bash scripts/monitoring/security_monitor.sh --interactive

# Run as daemon
sudo bash scripts/monitoring/security_monitor.sh --daemon
```

#### Modes
- **Interactive:** Live dashboard (testing/debugging)
- **Daemon:** Background service (production)
- **Service:** Systemd service (recommended)

#### Commands
```bash
--interactive          Run in interactive mode
--daemon              Run as background daemon
--install             Install as systemd service
--view-alerts         View recent alerts
--report              Generate security report
--config              Create/edit configuration
```

#### What It Monitors
- SSH authentication attempts
- Invalid user attempts
- Root login attempts
- Sudo command executions
- Firewall blocks
- System resource usage
- Fail2Ban activity
- Kernel security events

#### Alert Levels
- **CRITICAL:** System compromise, kernel panic
- **HIGH:** Root login attempts, multiple failed logins
- **MEDIUM:** Firewall blocks, sudo failures
- **LOW:** Successful logins, normal activity

#### Configuration
Edit `/etc/security-monitor/config.conf`

#### Logs
- Alerts: `/var/log/security-monitor/alerts.log`
- Service: `sudo journalctl -u security-monitor`

#### Resource Usage
- CPU: <1%
- Memory: 20-50 MB
- Disk I/O: Minimal

---

### setup_email_alerts.sh

**Location:** `scripts/monitoring/setup_email_alerts.sh`
**Size:** ~6.3 KB
**Type:** Configuration script
**Frequency:** Run once after installing monitor

#### Purpose
Configure email notifications for security alerts.

#### When to Use
- After installing security monitor
- To receive alerts via email
- For external notifications

#### How to Run
```bash
sudo bash scripts/monitoring/setup_email_alerts.sh
```

#### Options
1. Local mail delivery (Postfix)
2. External SMTP (Gmail, SendGrid, etc.)
3. Test email
4. Update monitor config

#### Time Required
2-5 minutes

#### Risk Level
None (configuration only)

#### Setup Methods

**Local Mail (Simple):**
- Installs Postfix
- Emails stored locally
- View with: `mail`

**External SMTP (Advanced):**
- Requires SMTP credentials
- Emails delivered to inbox
- Supports Gmail, SendGrid, etc.

#### Testing
```bash
echo "Test" | mail -s "Test Subject" root@localhost
```

---

### analyze_logs.sh

**Location:** `scripts/monitoring/analyze_logs.sh`
**Size:** ~10 KB
**Type:** Analysis and reporting tool
**Frequency:** Daily/weekly reviews

#### Purpose
Deep analysis of security logs to identify patterns and threats.

#### When to Use
- Daily security reviews
- Weekly log analysis
- Incident investigation
- Troubleshooting

#### How to Run
```bash
# Interactive menu
bash scripts/monitoring/analyze_logs.sh

# Generate full report
bash scripts/monitoring/analyze_logs.sh --report
```

#### Analysis Types
1. SSH Security Analysis
   - Failed login attempts
   - Top attacking IPs
   - Invalid user attempts

2. Firewall Analysis
   - UFW blocks
   - Blocked source IPs
   - Blocked destination ports

3. Sudo Activity Analysis
   - Command executions
   - Failed attempts
   - Users using sudo

4. System Events Analysis
   - Reboots
   - Service changes
   - Kernel warnings

5. Fail2Ban Analysis
   - Ban statistics
   - Jail details

6. System Health Analysis
   - Disk usage
   - Memory usage
   - Load average
   - CPU information

7. Security Alerts Summary
   - Alert count by level
   - Recent alerts

8. Generate Full Report
   - Complete analysis report

#### Time Required
1-5 minutes

#### Risk Level
None (read-only analysis)

#### Output
- Console display
- Optional report file

---

## Update Scripts

### update_monitor.sh

**Location:** `scripts/updates/update_monitor.sh`
**Size:** ~21 KB
**Type:** Update management system
**Frequency:** Weekly checks, as-needed updates

#### Purpose
Manage updates, backups, and version rollback for the security suite.

#### When to Use
- Weekly update checks
- Installing available updates
- Managing backups
- Rolling back versions

#### How to Run
```bash
# Check for updates
bash scripts/updates/update_monitor.sh --check

# Install updates
sudo bash scripts/updates/update_monitor.sh --update

# Schedule automatic updates
sudo bash scripts/updates/update_monitor.sh --schedule

# View status
bash scripts/updates/update_monitor.sh --status
```

#### Commands
```bash
--check              Check for available updates
--update             Install available updates
--schedule           Configure automatic updates
--show-schedule      Display current cron schedule
--rollback           Rollback to previous version
--list-backups       List available backups
--status             Show update status
--changelog          Show update history
--config             Create/edit configuration
```

#### Features
- Semantic versioning (X.Y.Z)
- Automatic backup creation
- One-command rollback
- Cron-based scheduling
- Update history tracking
- Email notifications

#### Time Required
2-5 minutes

#### Risk Level
Low (automatic backups)

#### Backup Retention
- Keep last 5 versions
- Location: `/var/backups/security-monitor/`

#### Rollback
```bash
sudo bash scripts/updates/update_monitor.sh --rollback
```

---

### check_dependencies.sh

**Location:** `scripts/updates/check_dependencies.sh`
**Size:** ~13 KB
**Type:** Dependency verification tool
**Frequency:** Before setup, weekly checks

#### Purpose
Verify and install system dependencies for the security suite.

#### When to Use
- Before initial setup
- Weekly maintenance
- Troubleshooting
- Pre-update verification

#### How to Run
```bash
# Check all dependencies
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

#### Checks
- System packages (curl, wget, git, etc.)
- Python modules
- Configuration files
- Service status
- File permissions
- Disk space (alerts at >90%)
- Network connectivity

#### Time Required
1 minute

#### Risk Level
None (read-only checking)

#### Output
- Console display
- Optional report file

---

## Utility Scripts

### verify_security.sh

**Location:** `scripts/utilities/verify_security.sh`
**Size:** ~9.9 KB
**Type:** Verification tool
**Frequency:** Weekly verification

#### Purpose
Verify that all security configurations are properly applied.

#### When to Use
- After hardening
- Weekly verification
- Post-update verification
- Troubleshooting

#### How to Run
```bash
# Quick verification
bash scripts/utilities/verify_security.sh

# With monitoring
bash scripts/utilities/verify_security.sh --monitor
```

#### Verifies
- SSH configuration hardening
- Firewall configuration and status
- Fail2Ban installation and operation
- System hardening parameters
- Automatic updates configuration
- Monitoring system status

#### Time Required
1 minute

#### Risk Level
None (read-only verification)

#### Output
- Status of each security component
- Color-coded results (✓ or ✗)

---

### configure_firewall.sh

**Location:** `scripts/utilities/configure_firewall.sh`
**Size:** ~5.4 KB
**Type:** Interactive configuration tool
**Frequency:** As needed for service changes

#### Purpose
Interactive firewall rule management and configuration.

#### When to Use
- After hardening
- When adding services
- Firewall troubleshooting
- Port management

#### How to Run
```bash
sudo bash scripts/utilities/configure_firewall.sh
```

#### Features
- View current rules
- Allow/deny ports
- Add custom rules
- Change SSH port
- Enable/disable firewall

#### Time Required
1-5 minutes

#### Risk Level
Medium (can block access if misconfigured)

#### Common Tasks
```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow custom port
sudo ufw allow 8080/tcp

# Deny port
sudo ufw deny 3306/tcp

# View rules
sudo ufw status numbered

# Reload firewall
sudo ufw reload
```

---

## Script Dependencies

```
debian_security_hardening.sh (Main)
├── Installs: UFW, Fail2Ban, AIDE
├── Configures: SSH, kernel parameters
└── Enables: Automatic updates

setup_ssh_2fa.sh
├── Requires: debian_security_hardening.sh
└── Installs: Google Authenticator, PAM

security_monitor.sh
├── Requires: debian_security_hardening.sh
├── Uses: /var/log/auth.log, /var/log/kern.log
└── Creates: /var/log/security-monitor/

setup_email_alerts.sh
├── Requires: security_monitor.sh
└── Installs: Postfix or configures SMTP

analyze_logs.sh
├── Reads: System logs
└── No installation required

update_monitor.sh
├── Creates: Backups, version tracking
└── Manages: Script updates

check_dependencies.sh
├── Checks: System packages, Python modules
└── Installs: Missing dependencies

verify_security.sh
├── Verifies: All security configurations
└── No installation required

configure_firewall.sh
├── Manages: UFW firewall rules
└── Requires: UFW installed
```

---

## Quick Command Reference

### Hardening
```bash
sudo bash scripts/hardening/debian_security_hardening.sh
sudo bash scripts/hardening/setup_ssh_2fa.sh
```

### Monitoring
```bash
sudo bash scripts/monitoring/security_monitor.sh --install
bash scripts/monitoring/security_monitor.sh --view-alerts
bash scripts/monitoring/analyze_logs.sh
```

### Updates
```bash
bash scripts/updates/update_monitor.sh --check
sudo bash scripts/updates/update_monitor.sh --update
bash scripts/updates/check_dependencies.sh --check-all
```

### Utilities
```bash
bash scripts/utilities/verify_security.sh
sudo bash scripts/utilities/configure_firewall.sh
```

---

For detailed usage information, see `USAGE_GUIDE.md` and documentation in `docs/` directory.
