# Oracle Cloud / Debian VPS Security Hardening Scripts

This package contains automated security hardening scripts designed specifically for Debian-based VPS instances on Oracle Cloud free tier. These scripts implement industry best practices for securing a public-facing server.

## Scripts Overview

### 1. `debian_security_hardening.sh` (Main Script)

The primary hardening script that automates the complete security configuration process.

**What it does:**
- Updates all system packages and applies security patches
- Hardens SSH daemon configuration (disables root login, password auth, etc.)
- Installs and configures UFW firewall with sensible defaults
- Installs and configures Fail2Ban for intrusion prevention
- Applies kernel hardening parameters via sysctl
- Enables automatic security updates
- Initializes AIDE for file integrity monitoring
- Configures password security policies

**Usage:**
```bash
sudo bash debian_security_hardening.sh
```

**Execution time:** 5-15 minutes depending on system speed and internet connection

**What you should do after:**
1. Test your SSH connection before closing the current session
2. Verify firewall rules: `sudo ufw status`
3. Check Fail2Ban status: `sudo fail2ban-client status`
4. If you changed SSH port, update OCI Security List immediately

---

### 2. `setup_ssh_2fa.sh` (Optional - Two-Factor Authentication)

Adds an additional layer of security by requiring both SSH key and a time-based one-time password (TOTP).

**What it does:**
- Installs Google Authenticator PAM module
- Configures SSH to require both public key and TOTP
- Updates PAM and SSH daemon configurations

**Prerequisites:**
- Main hardening script must be run first
- A smartphone with Google Authenticator, Authy, or similar TOTP app

**Usage:**
```bash
sudo bash setup_ssh_2fa.sh
```

**After running:**
1. As your regular user (not root), run: `google-authenticator`
2. Scan the QR code with your authenticator app
3. Save the emergency codes in a secure location
4. Test SSH login with both key and 2FA code

**Important:** Keep your SSH key and authenticator device secure. If you lose access to your 2FA device, you can use emergency codes to regain access.

---

### 3. `configure_firewall.sh` (Firewall Management)

Interactive helper script for managing UFW firewall rules after initial hardening.

**What it does:**
- Displays current firewall rules
- Allows adding rules for common services (HTTP, HTTPS, and common database ports)
- Allows adding custom port rules
- Provides SSH port change functionality
- Allows firewall enable/disable and reset

**Usage:**
```bash
sudo bash configure_firewall.sh
```

**Common use cases:**
- Adding HTTP/HTTPS rules for web server
- Adding database port rules for any service (PostgreSQL, Redis, custom ports)
- Changing SSH port to non-standard port
- Viewing and managing existing rules

**Important:** After changing SSH port, you must update the OCI Security List to allow the new port before closing your session.

---

### 4. `verify_security.sh` (Verification and Monitoring)

Post-hardening verification script that checks if security measures are properly applied and provides ongoing monitoring.

**What it does:**
- Verifies SSH configuration hardening
- Checks firewall configuration and status
- Verifies Fail2Ban installation and operation
- Confirms system hardening parameters
- Checks automatic updates configuration
- Displays recent security logs and activity
- Provides security recommendations

**Usage:**
```bash
# One-time verification
bash verify_security.sh

# With security log monitoring
bash verify_security.sh --monitor
```

**Output includes:**
- Configuration verification results
- Current security status
- Recent authentication attempts
- Fail2Ban ban statistics
- Actionable security recommendations

---

## Quick Start Guide

### Step 1: Prepare Your Instance

Connect to your Oracle Cloud instance via SSH:
```bash
ssh -i your-key.pem ubuntu@your-instance-ip
```

### Step 2: Download and Run Main Hardening Script

```bash
# Download the script
wget https://your-server/debian_security_hardening.sh

# Make it executable
chmod +x debian_security_hardening.sh

# Run with sudo
sudo bash debian_security_hardening.sh
```

### Step 3: Verify Installation

```bash
bash verify_security.sh
```

### Step 4 (Optional): Set Up 2FA

```bash
sudo bash setup_ssh_2fa.sh
```

### Step 5: Configure Additional Firewall Rules

```bash
sudo bash configure_firewall.sh
```

---

## Important Security Considerations

### Before Running Scripts

1. **Backup your current configuration** - The scripts back up modified files automatically, but it's good practice to have your own backups
2. **Test SSH access** - Ensure you can SSH into your instance before running scripts
3. **Have a recovery plan** - Know how to access your instance via OCI Console if SSH fails
4. **Update OCI Security List** - Ensure your IP is allowed for SSH (port 22 or custom port)

### After Running Scripts

1. **Test SSH connection immediately** - Don't close your current session until you've verified SSH still works
2. **Update OCI Security List** - If you changed SSH port, update the Security List rule
3. **Monitor logs** - Watch `/var/log/auth.log` for any issues
4. **Verify services** - Test that your applications still work correctly

### Ongoing Maintenance

1. **Review logs regularly** - Check for suspicious activity: `sudo tail -f /var/log/auth.log`
2. **Monitor Fail2Ban** - Check banned IPs: `sudo fail2ban-client status sshd`
3. **Update packages** - Automatic updates are enabled, but monitor: `sudo apt list --upgradable`
4. **Rotate SSH keys** - Consider rotating SSH keys periodically
5. **Review firewall rules** - Periodically audit open ports: `sudo ufw status numbered`

---

## Troubleshooting

### Locked Out of SSH

If you accidentally lock yourself out:

1. **Use OCI Console** - Connect via OCI Console's VNC viewer
2. **Check firewall rules** - Verify OCI Security List allows your IP
3. **Review SSH config** - Check `/etc/ssh/sshd_config` for errors
4. **Restore backup** - If needed, restore from backup: `sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config`

### Firewall Blocking Services

If your services aren't accessible:

1. **Check UFW rules** - `sudo ufw status numbered`
2. **Check OCI Security List** - Verify rules in OCI Console
3. **Verify service is running** - `sudo systemctl status service-name`
4. **Check service logs** - Review application logs for errors

### SSH Connection Issues

If SSH is slow or unresponsive:

1. **Check SSH status** - `sudo systemctl status ssh`
2. **Review SSH logs** - `sudo tail -50 /var/log/auth.log`
3. **Check Fail2Ban** - Verify you're not banned: `sudo fail2ban-client status sshd`
4. **Verify DNS** - Check if DNS resolution is working: `nslookup google.com`

---

## Security Best Practices

### SSH Key Management

- Store SSH private keys in a secure location
- Use strong passphrases for SSH keys
- Rotate SSH keys periodically
- Never share private keys
- Consider using hardware security keys for production

### Password Management

- Use strong, unique passwords for all accounts
- Store passwords in a password manager
- Avoid reusing passwords across services
- Change default passwords immediately

### Monitoring and Alerting

- Regularly review authentication logs
- Monitor system resources (CPU, memory, disk)
- Set up alerts for suspicious activity
- Keep audit logs for compliance

### Backup and Recovery

- Regularly backup important data
- Test backup restoration procedures
- Store backups in multiple locations
- Document recovery procedures

---

## Customization

### Changing SSH Port

To use a non-standard SSH port:

```bash
sudo bash configure_firewall.sh
# Select option 8 to change SSH port
```

### Adding Custom Firewall Rules

```bash
sudo bash configure_firewall.sh
# Select option 6 to add custom port
```

### Adjusting Fail2Ban Settings

Edit `/etc/fail2ban/jail.local` to customize ban times and thresholds:

```bash
sudo nano /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

---

## References

- [Oracle Cloud Always Free Resources](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [How to Secure a Linux Server](https://github.com/imthenachoman/how-to-secure-a-linux-server)
- [Mozilla SSH Configuration Guidelines](https://infosec.mozilla.org/guidelines/openssh)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Fail2Ban Documentation](https://www.fail2ban.org/)

---

## Support and Issues

If you encounter issues:

1. Check the troubleshooting section above
2. Review script output for error messages
3. Check system logs: `sudo journalctl -xe`
4. Verify OCI Security List and network configuration
5. Consult the referenced documentation

---

## License

These scripts are provided as-is for securing Oracle Cloud free tier instances. Use at your own risk and ensure you understand what each script does before running.

---

## Version History

- **v1.0** (2026-06-26): Initial release with core security hardening scripts
