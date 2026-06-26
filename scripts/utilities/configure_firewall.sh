#!/bin/bash

################################################################################
# Firewall Configuration Helper Script
#
# This script helps configure UFW firewall rules for common services.
# It can be used after running the main hardening script to add additional
# ports for specific services (web server, database, etc.).
#
# Usage: sudo bash configure_firewall.sh
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

check_ufw() {
    if ! command -v ufw &> /dev/null; then
        log_error "UFW is not installed. Please run the main hardening script first."
        exit 1
    fi
}

show_menu() {
    echo ""
    echo -e "${BLUE}=== UFW Firewall Configuration ===${NC}"
    echo "1. View current firewall rules"
    echo "2. Allow HTTP (port 80)"
    echo "3. Allow HTTPS (port 443)"
    echo "4. Allow MySQL (port 3306)"
    echo "5. Allow PostgreSQL (port 5432)"
    echo "6. Allow custom port"
    echo "7. Deny a port"
    echo "8. Change SSH port"
    echo "9. Enable/Disable firewall"
    echo "10. Reset firewall to defaults"
    echo "11. Exit"
    echo ""
}

view_rules() {
    log_info "Current UFW rules:"
    echo ""
    ufw status numbered
    echo ""
}

allow_port() {
    local port=$1
    local protocol=${2:-tcp}
    local description=$3
    
    if [[ -z "$description" ]]; then
        description="Port $port"
    fi
    
    log_info "Allowing $protocol port $port ($description)..."
    ufw allow "$port/$protocol" comment "$description"
    log_success "Port $port/$protocol allowed"
}

deny_port() {
    local port=$1
    local protocol=${2:-tcp}
    
    log_info "Denying $protocol port $port..."
    ufw deny "$port/$protocol"
    log_success "Port $port/$protocol denied"
}

change_ssh_port() {
    echo ""
    read -p "Enter new SSH port (current: 22): " new_port
    
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        log_error "Invalid port number"
        return 1
    fi
    
    log_warning "Changing SSH port to $new_port..."
    log_warning "IMPORTANT: You must also update the OCI Security List to allow this port!"
    
    # Update SSH config
    sed -i "s/^Port .*/Port $new_port/" /etc/ssh/sshd_config
    
    # Update UFW
    ufw delete allow 22/tcp 2>/dev/null || true
    ufw allow "$new_port/tcp" comment "SSH access on port $new_port"
    
    # Restart SSH
    systemctl restart ssh
    
    log_success "SSH port changed to $new_port"
    log_warning "Update your OCI Security List to allow port $new_port before closing this session!"
}

toggle_firewall() {
    echo ""
    read -p "Enable firewall? (y/n): " choice
    
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_info "Enabling UFW..."
        echo "y" | ufw enable > /dev/null
        log_success "UFW enabled"
    else
        log_warning "Disabling UFW..."
        echo "y" | ufw disable > /dev/null
        log_warning "UFW disabled"
    fi
}

reset_firewall() {
    echo ""
    log_warning "This will reset UFW to default settings!"
    read -p "Are you sure? (y/n): " choice
    
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        log_info "Resetting UFW..."
        echo "y" | ufw reset > /dev/null
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow 22/tcp comment "SSH access"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        echo "y" | ufw enable > /dev/null
        log_success "UFW reset to defaults"
    else
        log_info "Reset cancelled"
    fi
}

main() {
    check_root
    check_ufw
    
    log_info "UFW Firewall Configuration Helper"
    
    while true; do
        show_menu
        read -p "Select an option (1-11): " choice
        
        case $choice in
            1)
                view_rules
                ;;
            2)
                allow_port 80 tcp "HTTP web traffic"
                ;;
            3)
                allow_port 443 tcp "HTTPS web traffic"
                ;;
            4)
                allow_port 3306 tcp "MySQL database"
                ;;
            5)
                allow_port 5432 tcp "PostgreSQL database"
                ;;
            6)
                echo ""
                read -p "Enter port number: " custom_port
                read -p "Enter description (optional): " custom_desc
                allow_port "$custom_port" tcp "$custom_desc"
                ;;
            7)
                echo ""
                read -p "Enter port number to deny: " deny_port_num
                deny_port "$deny_port_num" tcp
                ;;
            8)
                change_ssh_port
                ;;
            9)
                toggle_firewall
                ;;
            10)
                reset_firewall
                ;;
            11)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
    done
}

main "$@"
