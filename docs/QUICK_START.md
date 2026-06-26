# Quick Start: Security Hardening Scripts

## TL;DR - Run This First

```bash
# Download and run the main hardening script
sudo bash debian_security_hardening.sh

# Verify everything worked
bash verify_security.sh

# Test SSH connection (in a new terminal)
ssh -i your-key.pem ubuntu@your-instance-ip
```

---

## Script Files

| Script | Purpose | Requires Root | Time |
|--------|---------|---------------|------|
| `debian_security_hardening.sh` | Main hardening - SSH, firewall, Fail2Ban, kernel hardening | Yes | 5-15 min |
| `setup_ssh_2fa.sh` | Add 2FA/MFA to SSH (optional) | Yes | 2 min |
| `configure_firewall.sh` | Interactive firewall management | Yes | 1-5 min |
| `verify_security.sh` | Check security status and view logs | No | 1 min |

---

## Step-by-Step Instructions

### 1. Run Main Hardening Script

```bash
sudo bash debian_security_hardening.sh
```

This script will:
- ✓ Update all packages
- ✓ Harden SSH (disable root login, password auth)
- ✓ Enable UFW firewall
- ✓ Install Fail2Ban
- ✓ Apply kernel hardening
- ✓ Enable automatic security updates

**Important:** Do NOT close your SSH session until you verify it still works!

### 2. Verify in a New Terminal

Open a **new terminal** and test SSH:

```bash
ssh -i your-key.pem ubuntu@your-instance-ip
```

If this works, you're good! If not, use OCI Console to fix the issue.

### 3. Check Security Status

```bash
bash verify_security.sh
```

This shows:
- ✓ SSH configuration status
- ✓ Firewall rules
- ✓ Fail2Ban status
- ✓ System hardening parameters
- ✓ Recent security logs

### 4 (Optional). Add 2FA to SSH

For extra security, add two-factor authentication:

```bash
sudo bash setup_ssh_2fa.sh
```

Then as your regular user:

```bash
google-authenticator
```

Scan the QR code with Google Authenticator app and save emergency codes.

### 5 (Optional). Configure Additional Firewall Rules

If you need to open ports for services:

```bash
sudo bash configure_firewall.sh
```

Menu options:
- View current rules
- Allow HTTP/HTTPS
- Allow database ports
- Add custom ports
- Change SSH port

---

## Common Issues & Solutions

### "Permission denied" when running scripts

Make sure to use `sudo`:
```bash
sudo bash debian_security_hardening.sh
```

### SSH connection fails after running script

1. Open OCI Console → Compute → Instances → Your Instance
2. Click "Console Connection" to access via VNC
3. Check SSH config: `sudo sshd -t`
4. Restore backup if needed: `sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config`
5. Restart SSH: `sudo systemctl restart ssh`

### Firewall is blocking my service

1. Check current rules: `sudo ufw status numbered`
2. Add the port: `sudo ufw allow 8080/tcp` (replace 8080 with your port)
3. Also update OCI Security List in Console

### Changed SSH port but can't connect

1. Use OCI Console to access instance
2. Update OCI Security List to allow new SSH port
3. Verify SSH config: `sudo sshd -t`
4. Restart SSH: `sudo systemctl restart ssh`

---

## What Gets Hardened

### SSH
- ✓ Root login disabled
- ✓ Password authentication disabled
- ✓ X11 forwarding disabled
- ✓ Port forwarding disabled
- ✓ Strong key exchange algorithms
- ✓ Strong ciphers and MACs

### Firewall
- ✓ UFW installed and enabled
- ✓ Default deny incoming
- ✓ Default allow outgoing
- ✓ SSH, HTTP, HTTPS allowed
- ✓ All other ports blocked by default

### Intrusion Prevention
- ✓ Fail2Ban installed
- ✓ SSH brute-force protection
- ✓ Automatic IP banning after 3 failed attempts
- ✓ 1-hour ban duration

### System
- ✓ All packages updated
- ✓ Kernel hardening parameters applied
- ✓ Automatic security updates enabled
- ✓ File integrity monitoring (AIDE) initialized
- ✓ Password security policies configured

---

## Monitoring After Hardening

### Check SSH logs
```bash
sudo tail -20 /var/log/auth.log
```

### Check Fail2Ban activity
```bash
sudo fail2ban-client status sshd
```

### Check firewall status
```bash
sudo ufw status numbered
```

### Check for available updates
```bash
sudo apt list --upgradable
```

### View security verification
```bash
bash verify_security.sh --monitor
```

---

## Important Notes

1. **Backup your SSH key** - Store it in a safe place
2. **Test SSH before closing session** - Don't lose access!
3. **Update OCI Security List** - If you change SSH port
4. **Keep instance active** - Idle instances may be reclaimed (>20% CPU/network for 7 days)
5. **Monitor logs regularly** - Check `/var/log/auth.log` for suspicious activity

---

## Next Steps

1. ✓ Run `debian_security_hardening.sh`
2. ✓ Test SSH in new terminal
3. ✓ Run `verify_security.sh`
4. ✓ (Optional) Run `setup_ssh_2fa.sh` for 2FA
5. ✓ (Optional) Run `configure_firewall.sh` to add service ports
6. ✓ Deploy your application
7. ✓ Monitor logs regularly

---

## Support

For issues:
1. Check the "Common Issues & Solutions" section above
2. Run `bash verify_security.sh` to check status
3. Review logs: `sudo tail -50 /var/log/auth.log`
4. Use OCI Console for emergency access if needed

Good luck! Your server is now hardened and ready for public services. 🔒
