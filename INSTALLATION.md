# Installation Guide

Complete step-by-step installation and configuration guide for the Oracle Cloud VPS Security Suite.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Installation](#quick-installation)
3. [Detailed Installation](#detailed-installation)
4. [Post-Installation](#post-installation)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **OS**: Debian 10+, Ubuntu 20.04+
- **Architecture**: x86_64 or ARM64
- **Disk Space**: Minimum 100 MB
- **RAM**: Minimum 512 MB
- **Network**: Internet connectivity
- **Access**: Root or sudo privileges

### Required Tools

The scripts will automatically install most dependencies. Verify you have:

```bash
# Check Git
git --version

# Check Bash
bash --version

# Check curl
curl --version
```

### Oracle Cloud Specifics

Before installing, ensure:

1. **Security List Configured**: SSH port 22 (or custom) allowed from your IP
2. **VCN Created**: Virtual Cloud Network with public subnet
3. **Instance Running**: Debian/Ubuntu instance in running state
4. **SSH Access**: Can connect via SSH key

## Quick Installation

For experienced users, complete setup in 5 minutes:

```bash
# 1. Clone repository
git clone https://github.com/yourusername/oracle-vps-security-suite.git
cd oracle-vps-security-suite

# 2. Make scripts executable
chmod +x scripts/**/*.sh

# 3. Run hardening
sudo bash scripts/hardening/debian_security_hardening.sh

# 4. Verify (in new terminal)
bash scripts/utilities/verify_security.sh

# 5. Install monitoring
sudo bash scripts/monitoring/security_monitor.sh --install

# 6. Schedule updates
sudo bash scripts/updates/update_monitor.sh --schedule
```

## Detailed Installation

### Step 1: Prepare Your Instance

Connect to your Oracle Cloud instance:

```bash
ssh -i your-key.pem ubuntu@your-instance-ip
```

Update system packages:

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 2: Clone Repository

```bash
# Clone the repository
git clone https://github.com/yourusername/oracle-vps-security-suite.git

# Navigate to directory
cd oracle-vps-security-suite

# Make scripts executable
chmod +x scripts/**/*.sh
```

### Step 3: Check Dependencies

Before running hardening scripts, verify all dependencies:

```bash
bash scripts/updates/check_dependencies.sh --check-all
```

If any are missing, install them:

```bash
sudo bash scripts/updates/check_dependencies.sh --install
```

### Step 4: Run Security Hardening

**Important**: Do NOT close your SSH session after this step!

```bash
sudo bash scripts/hardening/debian_security_hardening.sh
```

This script will:
- Update all packages
- Harden SSH configuration
- Enable UFW firewall
- Install and configure Fail2Ban
- Apply kernel hardening parameters
- Enable automatic security updates
- Initialize AIDE file integrity monitoring

**Expected output:**
```
[✓] System updates completed
[✓] SSH service restarted with hardened configuration
[✓] UFW firewall configured and enabled
[✓] Fail2Ban installed and configured
[✓] System hardening parameters applied
[✓] Automatic security updates configured
[✓] Additional security measures applied
```

### Step 5: Verify SSH Access (Critical)

**In a NEW terminal**, test SSH connection:

```bash
ssh -i your-key.pem ubuntu@your-instance-ip
```

If this works, continue. If not:

1. Use OCI Console to access instance via VNC
2. Check SSH config: `sudo sshd -t`
3. Review logs: `sudo tail -50 /var/log/auth.log`
4. Restore backup if needed: `sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config`

### Step 6: Install Monitoring (Optional but Recommended)

```bash
# Install as systemd service
sudo bash scripts/monitoring/security_monitor.sh --install

# Verify it's running
sudo systemctl status security-monitor
```

### Step 7: Configure Email Alerts (Optional)

```bash
# Setup email notifications
sudo bash scripts/monitoring/setup_email_alerts.sh

# Test email
echo "Test" | mail -s "Test Subject" root@localhost
```

### Step 8: Schedule Automatic Updates (Recommended)

```bash
# Configure automatic update schedule
sudo bash scripts/updates/update_monitor.sh --schedule

# When prompted:
# Schedule: weekly
# Time: 02:00
```

### Step 9: Configure Firewall for Services (If Needed)

If you're running web services or other applications:

```bash
# Interactive firewall configuration
sudo bash scripts/utilities/configure_firewall.sh

# Or manually add rules
sudo ufw allow 80/tcp comment "HTTP"
sudo ufw allow 443/tcp comment "HTTPS"
```

## Post-Installation

### 1. Review Configuration Files

Check that all configurations are correct:

```bash
# SSH configuration
sudo cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"

# UFW firewall rules
sudo ufw status numbered

# Fail2Ban status
sudo fail2ban-client status

# Monitoring configuration
cat /etc/security-monitor/config.conf
```

### 2. Test All Components

```bash
# Verify security settings
bash scripts/utilities/verify_security.sh

# Test monitoring
sudo bash scripts/monitoring/security_monitor.sh --report

# Check dependencies
bash scripts/updates/check_dependencies.sh --check-all
```

### 3. Set Up Cron Jobs (Optional)

For automated daily checks:

```bash
# Edit crontab
sudo crontab -e

# Add these lines:
# Daily update check at 6 AM
0 6 * * * /usr/bin/bash /home/ubuntu/oracle-vps-security-suite/scripts/updates/update_monitor.sh --check

# Weekly dependency check on Sunday at 7 AM
0 7 * * 0 /usr/bin/bash /home/ubuntu/oracle-vps-security-suite/scripts/updates/check_dependencies.sh --check-all
```

### 4. Configure Backups (Optional)

For important data:

```bash
# Create backup directory
mkdir -p /backups

# Set up automated backups
sudo crontab -e

# Add backup job (daily at 3 AM)
0 3 * * * tar czf /backups/backup_$(date +\%Y\%m\%d).tar.gz /home /etc
```

## Verification

### Quick Verification

```bash
# Run verification script
bash scripts/utilities/verify_security.sh
```

Expected output should show all checks passing:
```
[✓] SSH configuration is valid
[✓] UFW is enabled
[✓] Fail2Ban is running
[✓] System hardening parameters applied
[✓] Automatic security updates enabled
```

### Detailed Verification

```bash
# Check SSH
sudo systemctl status ssh
sudo sshd -t

# Check firewall
sudo ufw status
sudo ufw status numbered

# Check Fail2Ban
sudo fail2ban-client status

# Check monitoring
sudo systemctl status security-monitor
sudo journalctl -u security-monitor -n 20

# Check updates
bash scripts/updates/update_monitor.sh --status
```

### Test Security

```bash
# Test SSH hardening
ssh -v -i your-key.pem ubuntu@your-instance-ip 2>&1 | grep -i "cipher\|auth"

# Test firewall
sudo ufw status

# Test Fail2Ban
sudo fail2ban-client status sshd

# Test monitoring
bash scripts/monitoring/security_monitor.sh --view-alerts
```

## Troubleshooting

### Installation Fails

**Error: Permission denied**
```bash
# Solution: Use sudo
sudo bash scripts/hardening/debian_security_hardening.sh
```

**Error: Command not found**
```bash
# Solution: Make scripts executable
chmod +x scripts/**/*.sh
```

**Error: Dependency missing**
```bash
# Solution: Install dependencies
sudo bash scripts/updates/check_dependencies.sh --install
```

### SSH Connection Issues

**Error: Connection refused**
```bash
# Check if SSH is running
sudo systemctl status ssh

# Check SSH config syntax
sudo sshd -t

# Check firewall rules
sudo ufw status

# Check OCI Security List in console
```

**Error: Permission denied (publickey)**
```bash
# Verify SSH key permissions
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Verify key is in authorized_keys
cat ~/.ssh/authorized_keys
```

### Firewall Issues

**Error: Cannot access web server**
```bash
# Check firewall rules
sudo ufw status numbered

# Add HTTP/HTTPS rules
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Also check OCI Security List
```

**Error: Firewall blocking legitimate traffic**
```bash
# View blocked connections
sudo tail -50 /var/log/kern.log | grep UFW

# Temporarily disable firewall for testing
sudo ufw disable

# Re-enable and add rules
sudo ufw enable
sudo ufw allow from 192.168.1.0/24
```

### Monitoring Issues

**Error: Monitoring service won't start**
```bash
# Check service status
sudo systemctl status security-monitor

# View error logs
sudo journalctl -u security-monitor -n 50

# Restart service
sudo systemctl restart security-monitor
```

**Error: No alerts being generated**
```bash
# Check configuration
cat /etc/security-monitor/config.conf

# Verify alert log exists
ls -la /var/log/security-monitor/

# Restart monitoring
sudo systemctl restart security-monitor
```

### Update Issues

**Error: Update failed**
```bash
# Check update log
tail -100 /var/log/security-monitor/updates.log

# View available backups
bash scripts/updates/update_monitor.sh --list-backups

# Rollback if needed
sudo bash scripts/updates/update_monitor.sh --rollback
```

## Next Steps

After successful installation:

1. **Review Documentation**: Read relevant docs in `docs/` directory
2. **Configure Services**: Set up any web servers or applications
3. **Monitor Activity**: Check logs and alerts regularly
4. **Schedule Maintenance**: Set up automated tasks
5. **Test Procedures**: Practice backup and restore procedures

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review relevant documentation in `docs/`
3. Check log files in `/var/log/security-monitor/`
4. Open an issue on GitHub with:
   - Error message
   - Command that failed
   - Output of `bash scripts/updates/check_dependencies.sh --check-all`
   - OS version: `lsb_release -a`

## Uninstallation

To remove the security suite:

```bash
# Stop monitoring service
sudo systemctl stop security-monitor
sudo systemctl disable security-monitor

# Remove service file
sudo rm /etc/systemd/system/security-monitor.service

# Remove scripts
rm -rf /home/ubuntu/oracle-vps-security-suite

# Remove configuration
sudo rm -rf /etc/security-monitor

# Remove logs (optional)
sudo rm -rf /var/log/security-monitor

# Reload systemd
sudo systemctl daemon-reload
```

Note: UFW, Fail2Ban, and SSH hardening will remain. To revert:

```bash
# Restore SSH config
sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config
sudo systemctl restart ssh

# Disable UFW
sudo ufw disable

# Stop Fail2Ban
sudo systemctl stop fail2ban
sudo systemctl disable fail2ban
```

---

**Installation Complete!** 🎉

Your VPS is now secured and monitored. For daily operations, see the README.md file.
