#!/bin/bash

################################################################################
# Email Alerting Setup Script
#
# This script configures email alerts for security monitoring.
# Supports local mail delivery and external SMTP services.
#
# Usage: sudo bash setup_email_alerts.sh
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

setup_local_mail() {
    log_info "Setting up local mail delivery..."
    
    # Install postfix
    log_info "Installing Postfix..."
    apt-get update > /dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils
    
    # Configure postfix for local delivery only
    log_info "Configuring Postfix..."
    
    cat > /etc/postfix/main.cf << 'EOF'
# Postfix main configuration file
compatibility_level = 2
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/libexec/postfix
data_directory = /var/lib/postfix
mail_owner = postfix
myhostname = $(hostname)
mydomain = $(hostname -d)
myorigin = $myhostname
inet_interfaces = localhost
inet_protocols = all
mydestination = $myhostname, localhost.$mydomain, localhost
local_recipient_maps = unix:passwd.byname $alias_maps
unknown_local_recipient_reject_code = 550
mynetworks_style = subnet
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
recipient_delimiter = +
luser_relay = $user@localhost
transport_maps = hash:/etc/postfix/transport
relay_domains =
relayhost =
EOF

    # Rebuild alias database
    newaliases
    
    # Restart postfix
    systemctl restart postfix
    
    log_success "Local mail delivery configured"
}

setup_external_smtp() {
    log_info "Setting up external SMTP service..."
    
    read -p "SMTP Server (e.g., smtp.gmail.com): " smtp_server
    read -p "SMTP Port (default: 587): " smtp_port
    smtp_port=${smtp_port:-587}
    read -p "Email Address: " email_address
    read -sp "Email Password (will not be displayed): " email_password
    echo ""
    
    # Install postfix
    log_info "Installing Postfix..."
    apt-get update > /dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils
    
    # Configure postfix for external SMTP
    log_info "Configuring Postfix for external SMTP..."
    
    cat > /etc/postfix/main.cf << EOF
compatibility_level = 2
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/libexec/postfix
data_directory = /var/lib/postfix
mail_owner = postfix
myhostname = $(hostname)
mydomain = $(hostname -d)
myorigin = \$myhostname
inet_interfaces = localhost
inet_protocols = all
mydestination = \$myhostname, localhost.\$mydomain, localhost
local_recipient_maps = unix:passwd.byname \$alias_maps
unknown_local_recipient_reject_code = 550
mynetworks_style = subnet
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
recipient_delimiter = +
luser_relay = \$user@localhost
transport_maps = hash:/etc/postfix/transport
relay_domains =
relayhost = [$smtp_server]:$smtp_port
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_use_tls = yes
smtp_tls_security_level = encrypt
smtp_tls_note_starttls_offer = yes
EOF

    # Create SASL password file
    cat > /etc/postfix/sasl_passwd << EOF
[$smtp_server]:$smtp_port $email_address:$email_password
EOF

    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd
    
    # Rebuild alias database
    newaliases
    
    # Restart postfix
    systemctl restart postfix
    
    log_success "External SMTP configured"
    log_info "Credentials stored in /etc/postfix/sasl_passwd"
}

test_email() {
    read -p "Email address to test: " test_email
    
    log_info "Sending test email to $test_email..."
    
    {
        echo "Subject: Security Monitor Test Email"
        echo ""
        echo "This is a test email from your VPS security monitor."
        echo "If you received this, email alerts are working correctly."
        echo ""
        echo "Hostname: $(hostname)"
        echo "Time: $(date)"
    } | sendmail "$test_email"
    
    log_success "Test email sent to $test_email"
    log_info "Check your inbox (may take a few minutes)"
}

update_monitor_config() {
    local config_file="/etc/security-monitor/config.conf"
    
    read -p "Enable email alerts? (y/n): " enable_alerts
    
    if [[ "$enable_alerts" == "y" || "$enable_alerts" == "Y" ]]; then
        read -p "Email address for alerts: " alert_email
        
        if [[ -f "$config_file" ]]; then
            sed -i "s/ENABLE_EMAIL_ALERTS=.*/ENABLE_EMAIL_ALERTS=true/" "$config_file"
            sed -i "s/EMAIL_ADDRESS=.*/EMAIL_ADDRESS=\"$alert_email\"/" "$config_file"
            log_success "Security monitor config updated"
        else
            log_warning "Security monitor config not found. Create it with: sudo bash security_monitor.sh --config"
        fi
    fi
}

main() {
    log_info "Email Alerting Setup"
    echo ""
    
    check_root
    
    echo "Choose email setup method:"
    echo "1. Local mail delivery (recommended for simple setup)"
    echo "2. External SMTP (Gmail, SendGrid, etc.)"
    echo "3. Test email configuration"
    echo "4. Update security monitor config"
    echo ""
    
    read -p "Select option (1-4): " choice
    
    case $choice in
        1)
            setup_local_mail
            update_monitor_config
            ;;
        2)
            setup_external_smtp
            update_monitor_config
            ;;
        3)
            test_email
            ;;
        4)
            update_monitor_config
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "Email setup complete"
    log_info "To test: echo 'Test' | mail -s 'Test Subject' root@localhost"
}

main "$@"
