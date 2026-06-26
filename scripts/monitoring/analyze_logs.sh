#!/bin/bash

################################################################################
# Log Analysis Utility
#
# This script provides detailed analysis of security logs to identify
# patterns, trends, and potential security issues.
#
# Usage: bash analyze_logs.sh [options]
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${MAGENTA}=== $1 ===${NC}"
    echo ""
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_stat() {
    echo -e "  ${GREEN}$1${NC}: $2"
}

################################################################################
# SSH Analysis
################################################################################

analyze_ssh_logs() {
    log_section "SSH Security Analysis"
    
    local auth_log="/var/log/auth.log"
    
    if [[ ! -f "$auth_log" ]]; then
        log_info "Auth log not found"
        return
    fi
    
    print_header "Failed Login Attempts (Last 24 hours)"
    local failed_24h=$(grep "Failed password" "$auth_log" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Failed attempts" "$failed_24h"
    
    print_header "Top 10 IPs with Failed Logins"
    grep "Failed password" "$auth_log" | grep -oP '(?<=from )\S+' | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %5d attempts from %s\n", $1, $2}'
    
    print_header "Failed Login Attempts by User (Last 24 hours)"
    grep "Failed password" "$auth_log" | grep "$(date '+%b %d')" | \
        grep -oP '(?<=for )\S+|(?<=invalid user )\S+' | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %5d attempts for user: %s\n", $1, $2}'
    
    print_header "Invalid User Attempts"
    local invalid_users=$(grep "Invalid user" "$auth_log" | wc -l || echo 0)
    print_stat "Total invalid user attempts" "$invalid_users"
    
    print_header "Top 10 Invalid Usernames"
    grep "Invalid user" "$auth_log" | grep -oP '(?<=Invalid user )\S+' | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %5d attempts for: %s\n", $1, $2}'
    
    print_header "Successful SSH Logins (Last 24 hours)"
    local successful=$(grep "Accepted" "$auth_log" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Successful logins" "$successful"
    
    print_header "Root Login Attempts"
    local root_attempts=$(grep -E "Failed password.*root|Invalid user.*root" "$auth_log" | wc -l || echo 0)
    print_stat "Root login attempts" "$root_attempts"
}

################################################################################
# Firewall Analysis
################################################################################

analyze_firewall_logs() {
    log_section "Firewall Analysis"
    
    local kern_log="/var/log/kern.log"
    
    if [[ ! -f "$kern_log" ]]; then
        log_info "Kernel log not found"
        return
    fi
    
    print_header "UFW Blocks (Last 24 hours)"
    local blocks=$(grep "UFW BLOCK" "$kern_log" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Total blocks" "$blocks"
    
    if [[ $blocks -gt 0 ]]; then
        print_header "Top 10 Blocked Source IPs"
        grep "UFW BLOCK" "$kern_log" | grep "$(date '+%b %d')" | \
            grep -oP '(?<=SRC=)[^ ]+' | sort | uniq -c | sort -rn | head -10 | \
            awk '{printf "  %5d blocks from %s\n", $1, $2}'
        
        print_header "Top 10 Blocked Destination Ports"
        grep "UFW BLOCK" "$kern_log" | grep "$(date '+%b %d')" | \
            grep -oP '(?<=DPT=)[^ ]+' | sort | uniq -c | sort -rn | head -10 | \
            awk '{printf "  %5d blocks to port %s\n", $1, $2}'
    fi
}

################################################################################
# Sudo Analysis
################################################################################

analyze_sudo_logs() {
    log_section "Sudo Activity Analysis"
    
    local auth_log="/var/log/auth.log"
    
    if [[ ! -f "$auth_log" ]]; then
        log_info "Auth log not found"
        return
    fi
    
    print_header "Sudo Command Executions (Last 24 hours)"
    local sudo_commands=$(grep "sudo.*COMMAND=" "$auth_log" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Total sudo commands" "$sudo_commands"
    
    print_header "Users Using Sudo (Last 24 hours)"
    grep "sudo.*COMMAND=" "$auth_log" | grep "$(date '+%b %d')" | \
        grep -oP '(?<=user=)\S+' | sort | uniq -c | sort -rn | \
        awk '{printf "  %5d commands by: %s\n", $1, $2}'
    
    print_header "Failed Sudo Attempts (Last 24 hours)"
    local failed_sudo=$(grep "sudo.*sorry" "$auth_log" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Failed attempts" "$failed_sudo"
}

################################################################################
# System Events Analysis
################################################################################

analyze_system_events() {
    log_section "System Events Analysis"
    
    local syslog="/var/log/syslog"
    
    if [[ ! -f "$syslog" ]]; then
        log_info "System log not found"
        return
    fi
    
    print_header "System Reboots"
    local reboots=$(grep "Kernel panic\|reboot\|shutdown" "$syslog" | wc -l || echo 0)
    print_stat "Reboot events" "$reboots"
    
    print_header "Service Restarts (Last 24 hours)"
    grep "systemd.*Started\|systemd.*Stopped" "$syslog" | grep "$(date '+%b %d')" | wc -l | \
        xargs -I {} echo "  {} service state changes"
    
    print_header "Kernel Warnings (Last 24 hours)"
    local warnings=$(grep -i "warning\|error" "$syslog" | grep "$(date '+%b %d')" | wc -l || echo 0)
    print_stat "Warnings/Errors" "$warnings"
}

################################################################################
# Fail2Ban Analysis
################################################################################

analyze_fail2ban() {
    log_section "Fail2Ban Analysis"
    
    if ! command -v fail2ban-client &>/dev/null; then
        log_info "Fail2Ban not installed"
        return
    fi
    
    print_header "Fail2Ban Status"
    fail2ban-client status 2>/dev/null | head -10 || log_info "Unable to get Fail2Ban status"
    
    print_header "SSH Jail Details"
    fail2ban-client status sshd 2>/dev/null | tail -5 || log_info "Unable to get SSH jail details"
}

################################################################################
# System Health Analysis
################################################################################

analyze_system_health() {
    log_section "System Health Analysis"
    
    print_header "Disk Usage"
    df -h | grep -E "^/dev|^Filesystem" | awk '{printf "  %-20s %5s %5s %5s %s\n", $1, $2, $3, $5, $6}'
    
    print_header "Memory Usage"
    free -h | awk 'NR==2 {printf "  Total: %s | Used: %s | Free: %s\n", $2, $3, $4}'
    
    print_header "Load Average"
    uptime | grep -oP '(?<=load average: ).*' | \
        xargs -I {} echo "  {}"
    
    print_header "CPU Information"
    nproc | xargs -I {} echo "  CPU Cores: {}"
    
    print_header "Uptime"
    uptime | sed 's/^[^,]*,/  /'
}

################################################################################
# Security Alerts Summary
################################################################################

analyze_security_alerts() {
    log_section "Security Alerts Summary"
    
    local alert_log="/var/log/security-monitor/alerts.log"
    
    if [[ ! -f "$alert_log" ]]; then
        log_info "No security monitor alerts found"
        return
    fi
    
    print_header "Alert Count by Level"
    grep -oP '(?<=\[Level )\d+' "$alert_log" | sort | uniq -c | \
        awk '{level=$2; if(level==0) lv="CRITICAL"; else if(level==1) lv="HIGH"; else if(level==2) lv="MEDIUM"; else lv="LOW"; printf "  %5d %s alerts\n", $1, lv}'
    
    print_header "Recent Alerts (Last 10)"
    tail -10 "$alert_log" | sed 's/^/  /'
}

################################################################################
# Generate Full Report
################################################################################

generate_full_report() {
    local report_file="/tmp/security_analysis_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Security Analysis Report"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "=========================================="
        echo ""
        
        # Redirect all analysis to report
        analyze_ssh_logs
        analyze_firewall_logs
        analyze_sudo_logs
        analyze_system_events
        analyze_fail2ban
        analyze_system_health
        analyze_security_alerts
        
    } | tee "$report_file"
    
    log_info "Full report saved to: $report_file"
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    echo ""
    echo -e "${BLUE}=== Log Analysis Utility ===${NC}"
    echo "1. SSH Security Analysis"
    echo "2. Firewall Analysis"
    echo "3. Sudo Activity Analysis"
    echo "4. System Events Analysis"
    echo "5. Fail2Ban Analysis"
    echo "6. System Health Analysis"
    echo "7. Security Alerts Summary"
    echo "8. Generate Full Report"
    echo "9. Exit"
    echo ""
}

main() {
    if [[ "${1:-}" == "--report" ]]; then
        generate_full_report
        exit 0
    fi
    
    while true; do
        show_menu
        read -p "Select analysis (1-9): " choice
        
        case $choice in
            1) analyze_ssh_logs ;;
            2) analyze_firewall_logs ;;
            3) analyze_sudo_logs ;;
            4) analyze_system_events ;;
            5) analyze_fail2ban ;;
            6) analyze_system_health ;;
            7) analyze_security_alerts ;;
            8) generate_full_report ;;
            9) exit 0 ;;
            *) log_info "Invalid option" ;;
        esac
    done
}

main "$@"
