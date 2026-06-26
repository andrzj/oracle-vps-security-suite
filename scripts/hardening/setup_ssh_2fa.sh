#!/bin/bash

################################################################################
# SSH 2FA/MFA Setup Script for Debian
#
# This script sets up Google Authenticator-based 2FA/MFA for SSH access.
# It requires the main hardening script to have been run first.
#
# Usage: sudo bash setup_ssh_2fa.sh
#
# After running this script, you will need to:
# 1. Scan the QR code with Google Authenticator or similar app
# 2. Save the emergency codes in a secure location
# 3. Test SSH login with both SSH key and 2FA code
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
        log_error "This script must be run as root"
        exit 1
    fi
}

main() {
    log_info "SSH 2FA/MFA Setup Script"
    log_warning "This script configures Google Authenticator-based 2FA for SSH"
    echo ""
    
    check_root
    
    log_info "Installing libpam-google-authenticator..."
    apt-get update > /dev/null
    apt-get install -y libpam-google-authenticator
    
    log_info "Backing up PAM SSH configuration..."
    cp /etc/pam.d/sshd /etc/pam.d/sshd.backup.$(date +%Y%m%d_%H%M%S)
    
    log_info "Updating PAM SSH configuration..."
    # Add google-authenticator to PAM if not already present
    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        sed -i '/@include common-auth/a auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd
        log_success "PAM configuration updated"
    else
        log_info "PAM already configured for google-authenticator"
    fi
    
    log_info "Updating SSH daemon configuration for keyboard-interactive auth..."
    # Backup sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # Enable ChallengeResponseAuthentication for 2FA
    sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    
    # Add AuthenticationMethods to require both key and 2FA
    if ! grep -q "AuthenticationMethods" /etc/ssh/sshd_config; then
        echo "AuthenticationMethods publickey,keyboard-interactive" >> /etc/ssh/sshd_config
    fi
    
    log_info "Verifying SSH configuration..."
    if sshd -t 2>/dev/null; then
        log_success "SSH configuration is valid"
    else
        log_error "SSH configuration has errors. Restoring backup."
        cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config
        exit 1
    fi
    
    log_info "Restarting SSH service..."
    systemctl restart ssh
    
    log_success "SSH 2FA/MFA setup completed"
    echo ""
    log_info "Next steps:"
    log_info "1. Run 'google-authenticator' as your regular user to generate 2FA secrets"
    log_info "2. When prompted, answer the questions (recommended: yes to all)"
    log_info "3. Scan the QR code with Google Authenticator, Authy, or similar app"
    log_info "4. Save the emergency codes in a secure location"
    log_info "5. Test SSH login with both your SSH key and the 6-digit code"
    echo ""
    log_warning "IMPORTANT: Keep your SSH key and 2FA device secure!"
    log_warning "If you lose access to your 2FA device, use emergency codes to regain access."
}

main "$@"
