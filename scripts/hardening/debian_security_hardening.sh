#!/bin/bash

################################################################################
# Oracle Cloud / Debian VPS Security Hardening Script
# 
# This script automates security hardening for a Debian-based VPS on Oracle
# Cloud free tier. It implements:
# - System updates and security patches
# - SSH hardening
# - UFW firewall configuration
# - Fail2Ban installation and configuration
# - System hardening parameters
# - Automatic security updates
#
# Usage: sudo bash debian_security_hardening.sh
# 
# WARNING: This script makes significant changes to system security settings.
# Review the script before running and ensure you have a backup plan.
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SSH_PORT=22  # Change this to a non-standard port if desired (e.g., 2222)
SSH_CUSTOM_PORT=false  # Set to true if using a non-standard port

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use: sudo bash debian_security_hardening.sh)"
        exit 1
    fi
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

################################################################################
# Phase 1: System Updates
################################################################################

phase_system_updates() {
    log_info "=== Phase 1: System Updates ==="
    
    log_info "Updating package lists..."
    apt-get update
    
    log_info "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    log_info "Installing security updates..."
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    
    log_success "System updates completed"
}

################################################################################
# Phase 2: SSH Hardening
################################################################################

phase_ssh_hardening() {
    log_info "=== Phase 2: SSH Hardening ==="
    
    local sshd_config="/etc/ssh/sshd_config"
    
    # Backup original SSH config
    backup_file "$sshd_config"
    
    log_info "Hardening SSH configuration..."
    
    # Create a temporary config file with hardened settings
    cat > /tmp/sshd_config_hardened << 'EOF'
# This is the ssh server system-wide configuration file.
# See sshd_config(5) for more information.

Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# HostKeys
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

# Key exchange algorithms (from Mozilla modern recommendations)
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

# Ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Message authentication codes
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# User/Group restrictions
AllowUsers *@*
# Uncomment and modify to restrict to specific users/groups:
# AllowGroups sshusers

# Connection settings
LoginGraceTime 30
MaxAuthTries 2
MaxSessions 2
MaxStartups 2:30:2
ClientAliveInterval 15
ClientAliveCountMax 3
TCPKeepAlive no

# Security options
HostbasedAuthentication no
IgnoreRhosts yes
IgnoreUserKnownHosts no
PermitUserEnvironment no
Compression no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no
UseDNS yes
HashKnownHosts yes

# SFTP
Subsystem sftp internal-sftp -f AUTHPRIV -l INFO

# Banner
Banner /etc/ssh/banner.txt
EOF

    # Replace the SSH config
    cp /tmp/sshd_config_hardened "$sshd_config"
    chmod 600 "$sshd_config"
    
    log_info "Creating SSH banner..."
    cat > /etc/ssh/banner.txt << 'EOF'
###############################################################################
#                       AUTHORIZED ACCESS ONLY                               #
#                                                                             #
# Unauthorized access to this system is forbidden and will be prosecuted     #
# by law. By accessing this system, you agree that your actions may be       #
# monitored and recorded.                                                    #
###############################################################################
EOF
    chmod 644 /etc/ssh/banner.txt
    
    # Verify SSH config syntax
    if sshd -t 2>/dev/null; then
        log_success "SSH configuration syntax verified"
    else
        log_error "SSH configuration has syntax errors. Restoring backup."
        cp "${sshd_config}.backup"* "$sshd_config" 2>/dev/null || true
        return 1
    fi
    
    # Restart SSH service
    systemctl restart ssh
    log_success "SSH service restarted with hardened configuration"
    
    log_warning "SSH hardening complete. If you changed the SSH port, update your firewall rules."
}

################################################################################
# Phase 3: Firewall Configuration (UFW)
################################################################################

phase_firewall_setup() {
    log_info "=== Phase 3: Firewall Configuration (UFW) ==="
    
    log_info "Installing UFW..."
    apt-get install -y ufw
    
    log_info "Configuring UFW default policies..."
    ufw --force reset > /dev/null 2>&1 || true
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny routed
    
    log_info "Allowing SSH access..."
    if [[ "$SSH_CUSTOM_PORT" == "true" ]]; then
        ufw allow "$SSH_PORT"/tcp comment "SSH access on port $SSH_PORT"
    else
        ufw allow 22/tcp comment "SSH access"
    fi
    
    log_info "Allowing HTTP and HTTPS..."
    ufw allow 80/tcp comment "HTTP web traffic"
    ufw allow 443/tcp comment "HTTPS web traffic"
    
    log_info "Enabling UFW..."
    echo "y" | ufw enable > /dev/null
    
    log_success "UFW firewall configured and enabled"
    log_info "Current UFW rules:"
    ufw status numbered
}

################################################################################
# Phase 4: Fail2Ban Installation and Configuration
################################################################################

phase_fail2ban_setup() {
    log_info "=== Phase 4: Fail2Ban Installation and Configuration ==="
    
    log_info "Installing Fail2Ban..."
    apt-get install -y fail2ban
    
    log_info "Creating Fail2Ban local configuration..."
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600

[recidive]
enabled = true
filter = recidive
action = %(action_mwl)s
logpath = /var/log/fail2ban.log
bantime = 604800
findtime = 86400
maxretry = 5
EOF

    log_info "Starting Fail2Ban service..."
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban installed and configured"
    log_info "Fail2Ban status:"
    fail2ban-client status
}

################################################################################
# Phase 5: System Hardening Parameters
################################################################################

phase_system_hardening() {
    log_info "=== Phase 5: System Hardening Parameters ==="
    
    log_info "Backing up sysctl configuration..."
    backup_file "/etc/sysctl.conf"
    
    log_info "Applying kernel hardening parameters..."
    cat >> /etc/sysctl.conf << 'EOF'

# Kernel hardening parameters
# Restrict kernel module loading
kernel.modules_disabled = 1

# Hide kernel pointers
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict access to kernel logs
kernel.printk = 3 3 3 3

# Restrict ptrace scope
kernel.yama.ptrace_scope = 2

# Enable ASLR
kernel.randomize_va_space = 2

# Restrict access to kernel sysrq
kernel.sysrq = 0

# Restrict magic SysRq key
kernel.magic_sysrq = 0

# Enable core dump restrictions
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# Network hardening
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# File system hardening
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_fifos = 2
EOF

    log_info "Applying sysctl parameters..."
    sysctl -p > /dev/null
    
    log_success "System hardening parameters applied"
}

################################################################################
# Phase 6: Automatic Security Updates
################################################################################

phase_automatic_updates() {
    log_info "=== Phase 6: Automatic Security Updates ==="
    
    log_info "Installing unattended-upgrades..."
    apt-get install -y unattended-upgrades apt-listchanges
    
    log_info "Configuring unattended-upgrades..."
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    log_success "Automatic security updates configured"
    log_info "Security updates will run daily"
}

################################################################################
# Phase 7: Additional Security Measures
################################################################################

phase_additional_security() {
    log_info "=== Phase 7: Additional Security Measures ==="
    
    log_info "Installing security tools..."
    apt-get install -y aide aide-common
    
    log_info "Initializing AIDE database (this may take a few minutes)..."
    aideinit
    
    log_info "Installing additional security packages..."
    apt-get install -y auditd curl wget git
    
    log_info "Configuring login.defs for password security..."
    backup_file "/etc/login.defs"
    
    # Set password expiration and minimum length
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
    sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    14/' /etc/login.defs
    
    log_success "Additional security measures applied"
}

################################################################################
# Phase 8: Verification and Summary
################################################################################

phase_verification() {
    log_info "=== Phase 8: Verification and Summary ==="
    
    log_info "Verifying SSH configuration..."
    if sshd -t 2>/dev/null; then
        log_success "SSH configuration is valid"
    else
        log_error "SSH configuration has errors"
    fi
    
    log_info "Verifying UFW status..."
    ufw status | head -5
    
    log_info "Verifying Fail2Ban status..."
    fail2ban-client status sshd | head -3
    
    log_success "Security hardening verification completed"
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting Oracle Cloud / Debian VPS Security Hardening"
    log_warning "This script will make significant changes to your system security settings."
    log_info "A backup of modified configuration files will be created."
    echo ""
    
    check_root
    
    # Execute all phases
    phase_system_updates
    echo ""
    
    phase_ssh_hardening
    echo ""
    
    phase_firewall_setup
    echo ""
    
    phase_fail2ban_setup
    echo ""
    
    phase_system_hardening
    echo ""
    
    phase_automatic_updates
    echo ""
    
    phase_additional_security
    echo ""
    
    phase_verification
    echo ""
    
    log_success "=== Security Hardening Complete ==="
    log_info "Summary of changes:"
    log_info "  ✓ System packages updated"
    log_info "  ✓ SSH daemon hardened"
    log_info "  ✓ UFW firewall enabled"
    log_info "  ✓ Fail2Ban configured"
    log_info "  ✓ Kernel parameters hardened"
    log_info "  ✓ Automatic security updates enabled"
    log_info "  ✓ AIDE file integrity monitoring initialized"
    echo ""
    log_warning "IMPORTANT: Review and test your SSH connection before closing this session."
    log_warning "If you changed the SSH port, update your OCI Security List accordingly."
    log_warning "Ensure your public IP is allowed in the OCI Security List for SSH access."
}

# Run main function
main "$@"
