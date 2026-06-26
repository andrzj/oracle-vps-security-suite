#!/bin/bash

################################################################################
# Dependency and Requirements Checker
#
# This script checks and manages dependencies for the security monitoring
# system, including system packages, Python modules, and configuration files.
#
# Usage:
#   Check all: bash check_dependencies.sh --check-all
#   Install missing: sudo bash check_dependencies.sh --install
#   System packages: bash check_dependencies.sh --packages
#   Python modules: bash check_dependencies.sh --python
#   Configuration: bash check_dependencies.sh --config
#
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
    if [[ $EUID -ne 0 ]] && [[ "${1:-}" == "--install" ]]; then
        log_error "Installation requires root privileges"
        exit 1
    fi
}

################################################################################
# System Package Checking
################################################################################

check_system_packages() {
    log_info "=== Checking System Packages ==="
    echo ""
    
    local packages=(
        "curl"
        "wget"
        "git"
        "bc"
        "grep"
        "sed"
        "awk"
        "tail"
        "systemd"
        "cron"
        "mail-utils"
        "postfix"
    )
    
    local missing=()
    local installed=0
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package"; then
            log_success "$package"
            ((installed++))
        else
            log_warning "$package (missing)"
            missing+=("$package")
        fi
    done
    
    echo ""
    echo "Installed: $installed/${#packages[@]}"
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        log_warning "Missing packages: ${missing[*]}"
        return 1
    else
        log_success "All required packages installed"
        return 0
    fi
}

install_system_packages() {
    log_info "Installing missing system packages..."
    
    local packages=(
        "curl"
        "wget"
        "git"
        "bc"
        "mail-utils"
        "postfix"
    )
    
    apt-get update > /dev/null
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package"; then
            log_info "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" > /dev/null
            log_success "$package installed"
        fi
    done
}

################################################################################
# Python Module Checking
################################################################################

check_python_modules() {
    log_info "=== Checking Python Modules ==="
    echo ""
    
    local modules=(
        "requests"
        "json"
        "subprocess"
        "datetime"
        "logging"
        "argparse"
    )
    
    local missing=()
    local installed=0
    
    for module in "${modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            log_success "$module"
            ((installed++))
        else
            log_warning "$module (missing)"
            missing+=("$module")
        fi
    done
    
    echo ""
    echo "Installed: $installed/${#modules[@]}"
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        log_warning "Missing modules: ${missing[*]}"
        return 1
    else
        log_success "All required Python modules available"
        return 0
    fi
}

################################################################################
# Configuration File Checking
################################################################################

check_configuration() {
    log_info "=== Checking Configuration Files ==="
    echo ""
    
    local config_files=(
        "/etc/security-monitor/config.conf"
        "/etc/security-monitor/update.conf"
        "/etc/ssh/sshd_config"
        "/etc/ufw/ufw.conf"
    )
    
    local missing=()
    local found=0
    
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            log_success "$config"
            ((found++))
        else
            log_warning "$config (missing)"
            missing+=("$config")
        fi
    done
    
    echo ""
    echo "Found: $found/${#config_files[@]}"
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        log_warning "Missing configuration files: ${missing[*]}"
        return 1
    else
        log_success "All configuration files present"
        return 0
    fi
}

################################################################################
# Service Checking
################################################################################

check_services() {
    log_info "=== Checking Services ==="
    echo ""
    
    local services=(
        "ssh"
        "ufw"
        "fail2ban"
        "postfix"
        "security-monitor"
    )
    
    local running=0
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "$service (running)"
            ((running++))
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_warning "$service (installed, not running)"
        else
            log_warning "$service (not installed)"
        fi
    done
    
    echo ""
    echo "Running: $running/${#services[@]}"
}

################################################################################
# Permission Checking
################################################################################

check_permissions() {
    log_info "=== Checking File Permissions ==="
    echo ""
    
    local files=(
        "/etc/security-monitor"
        "/var/log/security-monitor"
        "/var/backups/security-monitor"
        "/opt/security-monitor"
    )
    
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%OLp" "$file" | tail -c 3)
            local owner=$(stat -c "%U:%G" "$file" 2>/dev/null || stat -f "%Su:%Sg" "$file")
            
            if [[ "$perms" == "700" ]] || [[ "$perms" == "755" ]]; then
                log_success "$file ($perms, $owner)"
            else
                log_warning "$file ($perms, $owner) - consider restricting permissions"
            fi
        fi
    done
}

################################################################################
# Disk Space Checking
################################################################################

check_disk_space() {
    log_info "=== Checking Disk Space ==="
    echo ""
    
    local critical_dirs=(
        "/"
        "/var"
        "/var/log"
        "/var/backups"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local usage=$(df "$dir" | awk 'NR==2 {print $5}' | sed 's/%//')
            local available=$(df -h "$dir" | awk 'NR==2 {print $4}')
            
            if [[ $usage -gt 90 ]]; then
                log_error "$dir: ${usage}% used (${available} available)"
            elif [[ $usage -gt 80 ]]; then
                log_warning "$dir: ${usage}% used (${available} available)"
            else
                log_success "$dir: ${usage}% used (${available} available)"
            fi
        fi
    done
}

################################################################################
# Network Connectivity
################################################################################

check_network() {
    log_info "=== Checking Network Connectivity ==="
    echo ""
    
    # Check internet connectivity
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log_success "Internet connectivity: OK"
    else
        log_warning "Internet connectivity: Failed (may affect updates)"
    fi
    
    # Check DNS resolution
    if nslookup google.com &>/dev/null; then
        log_success "DNS resolution: OK"
    else
        log_warning "DNS resolution: Failed"
    fi
    
    # Check GitHub connectivity (for updates)
    if curl -s --connect-timeout 5 https://api.github.com &>/dev/null; then
        log_success "GitHub API: Accessible"
    else
        log_warning "GitHub API: Not accessible (updates may fail)"
    fi
}

################################################################################
# Comprehensive Check
################################################################################

check_all() {
    log_info "=== Comprehensive Dependency Check ==="
    echo ""
    
    local failed=0
    
    check_system_packages || ((failed++))
    echo ""
    
    check_python_modules || ((failed++))
    echo ""
    
    check_configuration || ((failed++))
    echo ""
    
    check_services
    echo ""
    
    check_permissions
    echo ""
    
    check_disk_space
    echo ""
    
    check_network
    echo ""
    
    if [[ $failed -eq 0 ]]; then
        log_success "All checks passed!"
        return 0
    else
        log_warning "$failed check(s) failed"
        return 1
    fi
}

################################################################################
# Install Missing Dependencies
################################################################################

install_all() {
    log_info "Installing missing dependencies..."
    echo ""
    
    install_system_packages
    echo ""
    
    log_info "Dependency installation complete"
    log_info "Run 'bash check_dependencies.sh --check-all' to verify"
}

################################################################################
# Generate Report
################################################################################

generate_report() {
    local report_file="/tmp/dependencies_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Dependency Check Report"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "=========================================="
        echo ""
        
        check_system_packages
        echo ""
        
        check_python_modules
        echo ""
        
        check_configuration
        echo ""
        
        check_services
        echo ""
        
        check_permissions
        echo ""
        
        check_disk_space
        echo ""
        
        check_network
        
    } | tee "$report_file"
    
    log_success "Report saved to: $report_file"
}

################################################################################
# Main
################################################################################

main() {
    case "${1:-}" in
        --check-all)
            check_all
            ;;
        --install)
            check_root "$1"
            install_all
            check_all
            ;;
        --packages)
            check_system_packages
            ;;
        --python)
            check_python_modules
            ;;
        --config)
            check_configuration
            ;;
        --services)
            check_services
            ;;
        --permissions)
            check_permissions
            ;;
        --disk)
            check_disk_space
            ;;
        --network)
            check_network
            ;;
        --report)
            generate_report
            ;;
        --help|-h)
            cat << 'EOF'
Dependency Checker - Usage

Commands:
  --check-all          Check all dependencies
  --install            Install missing dependencies
  --packages           Check system packages
  --python             Check Python modules
  --config             Check configuration files
  --services           Check services status
  --permissions        Check file permissions
  --disk               Check disk space
  --network            Check network connectivity
  --report             Generate comprehensive report
  --help, -h           Show this help message

Examples:
  # Check all dependencies
  bash check_dependencies.sh --check-all

  # Install missing packages
  sudo bash check_dependencies.sh --install

  # Check specific component
  bash check_dependencies.sh --packages

  # Generate report
  bash check_dependencies.sh --report

Checks Performed:
  - System packages (curl, wget, git, etc.)
  - Python modules (requests, json, etc.)
  - Configuration files
  - Service status
  - File permissions
  - Disk space usage
  - Network connectivity
EOF
            ;;
        *)
            check_all
            ;;
    esac
}

main "$@"
