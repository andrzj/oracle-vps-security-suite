#!/bin/bash

################################################################################
# Security Verification and Monitoring Script
#
# This script verifies that security hardening has been properly applied
# and provides ongoing security monitoring capabilities.
#
# Usage: bash verify_security.sh
# For continuous monitoring: bash verify_security.sh --monitor
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

################################################################################
# SSH Verification
################################################################################

verify_ssh() {
    log_info "=== SSH Configuration Verification ==="
    
    local sshd_config="/etc/ssh/sshd_config"
    local issues=0
    
    # Check if SSH config is valid
    if sshd -t 2>/dev/null; then
        log_success "SSH configuration syntax is valid"
    else
        log_error "SSH configuration has syntax errors"
        ((issues++))
    fi
    
    # Check key settings
    if grep -q "^PermitRootLogin no" "$sshd_config"; then
        log_success "Root login disabled"
    else
        log_error "Root login is not disabled"
        ((issues++))
    fi
    
    if grep -q "^PasswordAuthentication no" "$sshd_config"; then
        log_success "Password authentication disabled"
    else
        log_warning "Password authentication is not disabled (may be intentional)"
    fi
    
    if grep -q "^X11Forwarding no" "$sshd_config"; then
        log_success "X11 forwarding disabled"
    else
        log_error "X11 forwarding is not disabled"
        ((issues++))
    fi
    
    if grep -q "^AllowTcpForwarding no" "$sshd_config"; then
        log_success "TCP forwarding disabled"
    else
        log_error "TCP forwarding is not disabled"
        ((issues++))
    fi
    
    return $issues
}

################################################################################
# Firewall Verification
################################################################################

verify_firewall() {
    log_info "=== Firewall Configuration Verification ==="
    
    local issues=0
    
    # Check if UFW is installed
    if command -v ufw &> /dev/null; then
        log_success "UFW is installed"
    else
        log_error "UFW is not installed"
        ((issues++))
        return $issues
    fi
    
    # Check if UFW is enabled
    if ufw status | grep -q "Status: active"; then
        log_success "UFW is enabled"
    else
        log_warning "UFW is not enabled"
        ((issues++))
    fi
    
    # Check default policies
    if ufw status | grep -q "Default: deny (incoming)"; then
        log_success "Default incoming policy is deny"
    else
        log_error "Default incoming policy is not deny"
        ((issues++))
    fi
    
    if ufw status | grep -q "Default: allow (outgoing)"; then
        log_success "Default outgoing policy is allow"
    else
        log_error "Default outgoing policy is not allow"
        ((issues++))
    fi
    
    return $issues
}

################################################################################
# Fail2Ban Verification
################################################################################

verify_fail2ban() {
    log_info "=== Fail2Ban Configuration Verification ==="
    
    local issues=0
    
    # Check if Fail2Ban is installed
    if command -v fail2ban-client &> /dev/null; then
        log_success "Fail2Ban is installed"
    else
        log_error "Fail2Ban is not installed"
        ((issues++))
        return $issues
    fi
    
    # Check if Fail2Ban is running
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2Ban is running"
    else
        log_error "Fail2Ban is not running"
        ((issues++))
    fi
    
    # Check SSH jail
    if fail2ban-client status sshd 2>/dev/null | grep -q "Status"; then
        log_success "SSH jail is configured"
        local banned=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | awk '{print $NF}')
        log_info "Currently banned IPs: $banned"
    else
        log_warning "SSH jail status could not be verified"
    fi
    
    return $issues
}

################################################################################
# System Hardening Verification
################################################################################

verify_system_hardening() {
    log_info "=== System Hardening Verification ==="
    
    local issues=0
    
    # Check kernel parameters
    if sysctl kernel.modules_disabled 2>/dev/null | grep -q "= 1"; then
        log_success "Kernel module loading is restricted"
    else
        log_warning "Kernel module loading is not restricted"
    fi
    
    if sysctl kernel.kptr_restrict 2>/dev/null | grep -q "= 2"; then
        log_success "Kernel pointer hiding is enabled"
    else
        log_warning "Kernel pointer hiding is not fully enabled"
    fi
    
    if sysctl net.ipv4.tcp_syncookies 2>/dev/null | grep -q "= 1"; then
        log_success "TCP SYN cookies are enabled"
    else
        log_warning "TCP SYN cookies are not enabled"
    fi
    
    if sysctl net.ipv4.conf.all.rp_filter 2>/dev/null | grep -q "= 1"; then
        log_success "Reverse path filtering is enabled"
    else
        log_warning "Reverse path filtering is not enabled"
    fi
    
    return $issues
}

################################################################################
# Automatic Updates Verification
################################################################################

verify_auto_updates() {
    log_info "=== Automatic Updates Verification ==="
    
    local issues=0
    
    # Check if unattended-upgrades is installed
    if dpkg -l | grep -q "unattended-upgrades"; then
        log_success "unattended-upgrades is installed"
    else
        log_error "unattended-upgrades is not installed"
        ((issues++))
    fi
    
    # Check if auto-upgrades is configured
    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        log_success "Automatic updates configuration found"
    else
        log_error "Automatic updates configuration not found"
        ((issues++))
    fi
    
    return $issues
}

################################################################################
# Security Log Monitoring
################################################################################

monitor_security_logs() {
    log_info "=== Security Log Monitoring ==="
    
    log_info "Recent SSH authentication attempts (last 10):"
    tail -10 /var/log/auth.log 2>/dev/null | sed 's/^/  /'
    
    echo ""
    log_info "Fail2Ban ban summary (last 24 hours):"
    if command -v fail2ban-client &> /dev/null; then
        fail2ban-client status sshd 2>/dev/null | tail -3 | sed 's/^/  /'
    else
        log_warning "Fail2Ban not available"
    fi
    
    echo ""
    log_info "System uptime and load:"
    uptime | sed 's/^/  /'
    
    echo ""
    log_info "Failed login attempts (last 5):"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 | sed 's/^/  /' || log_info "No failed attempts found"
}

################################################################################
# Security Recommendations
################################################################################

show_recommendations() {
    log_info "=== Security Recommendations ==="
    
    echo ""
    echo "1. SSH Access:"
    echo "   - Ensure your SSH key is backed up in a secure location"
    echo "   - Consider setting up 2FA with: sudo bash setup_ssh_2fa.sh"
    echo "   - Restrict SSH to specific IPs in OCI Security List if possible"
    echo ""
    
    echo "2. Firewall Rules:"
    echo "   - Review and minimize open ports using: sudo bash configure_firewall.sh"
    echo "   - Only allow necessary ports for your services"
    echo "   - Regularly audit firewall rules: sudo ufw status numbered"
    echo ""
    
    echo "3. System Maintenance:"
    echo "   - Check for available updates: sudo apt list --upgradable"
    echo "   - Review system logs regularly: sudo tail -f /var/log/syslog"
    echo "   - Monitor Fail2Ban activity: sudo fail2ban-client status"
    echo ""
    
    echo "4. Application Security:"
    echo "   - Keep all applications and services updated"
    echo "   - Run services with minimal required privileges"
    echo "   - Use strong, unique passwords for all accounts"
    echo ""
    
    echo "5. Backup and Recovery:"
    echo "   - Regularly backup important data to Object Storage"
    echo "   - Test restore procedures periodically"
    echo "   - Keep emergency SSH keys in a secure location"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Security Verification and Monitoring Script"
    echo ""
    
    local total_issues=0
    
    # Run all verifications
    verify_ssh || ((total_issues+=$?))
    echo ""
    
    verify_firewall || ((total_issues+=$?))
    echo ""
    
    verify_fail2ban || ((total_issues+=$?))
    echo ""
    
    verify_system_hardening || ((total_issues+=$?))
    echo ""
    
    verify_auto_updates || ((total_issues+=$?))
    echo ""
    
    # Show monitoring info if requested
    if [[ "${1:-}" == "--monitor" ]]; then
        monitor_security_logs
        echo ""
    fi
    
    # Show recommendations
    show_recommendations
    
    # Summary
    echo ""
    if [[ $total_issues -eq 0 ]]; then
        log_success "All security checks passed!"
    else
        log_warning "Found $total_issues potential issues. Review recommendations above."
    fi
}

main "$@"
