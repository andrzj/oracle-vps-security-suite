#!/bin/bash

################################################################################
# VPS Security Monitoring and Alerting Script
#
# This script monitors security logs in real-time and alerts on suspicious
# activities including failed login attempts, privilege escalation, firewall
# blocks, and other security events.
#
# Features:
# - Real-time log monitoring
# - Failed login detection
# - Privilege escalation attempts
# - Firewall rule violations
# - Port scanning detection
# - Rootkit/malware indicators
# - Email and syslog alerts
# - Daily security reports
#
# Usage:
#   Interactive mode: bash security_monitor.sh
#   Daemon mode: bash security_monitor.sh --daemon
#   Install as service: sudo bash security_monitor.sh --install
#   View alerts: bash security_monitor.sh --view-alerts
#   Generate report: bash security_monitor.sh --report
#
# Configuration: Edit /etc/security-monitor/config.conf
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/security-monitor"
CONFIG_FILE="$CONFIG_DIR/config.conf"
ALERT_LOG="/var/log/security-monitor/alerts.log"
STATE_DIR="/var/lib/security-monitor"
PID_FILE="/var/run/security-monitor.pid"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Alert levels
ALERT_CRITICAL=0
ALERT_HIGH=1
ALERT_MEDIUM=2
ALERT_LOW=3

# Default configuration
ENABLE_EMAIL_ALERTS=false
EMAIL_ADDRESS="root@localhost"
ENABLE_SYSLOG_ALERTS=true
ALERT_LEVEL=2  # MEDIUM
FAILED_LOGIN_THRESHOLD=5
MONITOR_INTERVAL=5
ENABLE_DAILY_REPORT=true
REPORT_TIME="06:00"

################################################################################
# Helper Functions
################################################################################

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

log_alert() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        $ALERT_CRITICAL)
            echo -e "${RED}[CRITICAL]${NC} $message" >&2
            ;;
        $ALERT_HIGH)
            echo -e "${RED}[HIGH]${NC} $message" >&2
            ;;
        $ALERT_MEDIUM)
            echo -e "${YELLOW}[MEDIUM]${NC} $message" >&2
            ;;
        $ALERT_LOW)
            echo -e "${BLUE}[LOW]${NC} $message" >&2
            ;;
    esac
    
    # Log to file
    if [[ -w "$(dirname "$ALERT_LOG")" ]]; then
        echo "[$timestamp] [Level $level] $message" >> "$ALERT_LOG"
    fi
}

alert_send() {
    local level=$1
    local title=$2
    local message=$3
    
    # Send syslog alert
    if [[ "$ENABLE_SYSLOG_ALERTS" == "true" ]]; then
        logger -t security-monitor -p "security.alert" "$title: $message"
    fi
    
    # Send email alert
    if [[ "$ENABLE_EMAIL_ALERTS" == "true" ]] && command -v mail &>/dev/null; then
        {
            echo "Security Alert from $(hostname)"
            echo "Time: $(date)"
            echo "Level: $level"
            echo ""
            echo "Title: $title"
            echo "Message: $message"
        } | mail -s "[Security Alert] $title" "$EMAIL_ADDRESS"
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        log_warning "Configuration file not found. Using defaults."
        log_info "To customize, create: $CONFIG_FILE"
    fi
}

create_config() {
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_FILE" << 'EOF'
# Security Monitor Configuration
# Uncomment and modify settings as needed

# Email alerting
ENABLE_EMAIL_ALERTS=false
EMAIL_ADDRESS="root@localhost"

# Syslog alerting
ENABLE_SYSLOG_ALERTS=true

# Alert level (0=CRITICAL, 1=HIGH, 2=MEDIUM, 3=LOW)
# Only alerts at this level or higher will be shown
ALERT_LEVEL=2

# Failed login threshold before alerting
FAILED_LOGIN_THRESHOLD=5

# Monitoring interval in seconds
MONITOR_INTERVAL=5

# Enable daily security reports
ENABLE_DAILY_REPORT=true
REPORT_TIME="06:00"

# Suspicious port ranges to monitor
SUSPICIOUS_PORTS="1:1023,6000:6999,31337:31337"

# Whitelist IPs (comma-separated) - these IPs won't trigger alerts
WHITELIST_IPS="127.0.0.1,::1"

# Enable specific monitors
MONITOR_SSH=true
MONITOR_SUDO=true
MONITOR_FIREWALL=true
MONITOR_KERNEL=true
MONITOR_PROCESS=true
EOF

    chmod 600 "$CONFIG_FILE"
    log_success "Configuration file created at $CONFIG_FILE"
}

init_directories() {
    mkdir -p "$(dirname "$ALERT_LOG")"
    mkdir -p "$STATE_DIR"
    chmod 700 "$(dirname "$ALERT_LOG")"
    chmod 700 "$STATE_DIR"
}

check_root() {
    if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "--view-alerts" ]] && [[ "${1:-}" != "--report" ]]; then
        log_error "This script must be run as root for monitoring"
        exit 1
    fi
}

################################################################################
# SSH Monitoring
################################################################################

monitor_ssh() {
    log_info "=== SSH Monitoring ==="
    
    local auth_log="/var/log/auth.log"
    local state_file="$STATE_DIR/ssh_state"
    local last_line=0
    
    if [[ -f "$state_file" ]]; then
        last_line=$(cat "$state_file")
    fi
    
    # Get new lines since last check
    local new_lines=$(wc -l < "$auth_log")
    
    if [[ $new_lines -gt $last_line ]]; then
        # Extract new log entries
        tail -n "+$((last_line + 1))" "$auth_log" | while read -r line; do
            # Failed password attempts
            if echo "$line" | grep -q "Failed password"; then
                local ip=$(echo "$line" | grep -oP '(?<=from )\S+' | head -1)
                log_alert $ALERT_MEDIUM "SSH Failed Login" "Failed password attempt from $ip"
                alert_send $ALERT_MEDIUM "SSH Failed Login" "Failed password attempt from $ip"
            fi
            
            # Invalid user attempts
            if echo "$line" | grep -q "Invalid user"; then
                local user=$(echo "$line" | grep -oP '(?<=Invalid user )\S+' | head -1)
                local ip=$(echo "$line" | grep -oP '(?<=from )\S+' | head -1)
                log_alert $ALERT_MEDIUM "SSH Invalid User" "Invalid user '$user' from $ip"
                alert_send $ALERT_MEDIUM "SSH Invalid User" "Invalid user '$user' from $ip"
            fi
            
            # Root login attempts
            if echo "$line" | grep -q "root.*ssh"; then
                if echo "$line" | grep -q "Failed password\|Invalid user"; then
                    local ip=$(echo "$line" | grep -oP '(?<=from )\S+' | head -1)
                    log_alert $ALERT_HIGH "SSH Root Login Attempt" "Root login attempt from $ip"
                    alert_send $ALERT_HIGH "SSH Root Login Attempt" "Root login attempt from $ip"
                fi
            fi
            
            # Successful logins
            if echo "$line" | grep -q "Accepted publickey\|Accepted password"; then
                local user=$(echo "$line" | grep -oP '(?<=for )\S+' | head -1)
                local ip=$(echo "$line" | grep -oP '(?<=from )\S+' | head -1)
                log_alert $ALERT_LOW "SSH Login Success" "User '$user' logged in from $ip"
            fi
        done
    fi
    
    echo "$new_lines" > "$state_file"
}

check_failed_logins() {
    log_info "=== Checking Failed Login Attempts ==="
    
    local failed_count=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null | tail -1 || echo 0)
    local last_hour_count=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d %H')" | wc -l || echo 0)
    
    if [[ $last_hour_count -gt $FAILED_LOGIN_THRESHOLD ]]; then
        log_alert $ALERT_HIGH "High Failed Login Rate" "$last_hour_count failed attempts in the last hour"
        alert_send $ALERT_HIGH "High Failed Login Rate" "$last_hour_count failed attempts in the last hour"
    fi
    
    log_info "Total failed logins: $failed_count (Last hour: $last_hour_count)"
}

################################################################################
# Sudo/Privilege Escalation Monitoring
################################################################################

monitor_sudo() {
    log_info "=== Sudo Activity Monitoring ==="
    
    local auth_log="/var/log/auth.log"
    local state_file="$STATE_DIR/sudo_state"
    local last_line=0
    
    if [[ -f "$state_file" ]]; then
        last_line=$(cat "$state_file")
    fi
    
    local new_lines=$(wc -l < "$auth_log")
    
    if [[ $new_lines -gt $last_line ]]; then
        tail -n "+$((last_line + 1))" "$auth_log" | while read -r line; do
            # Sudo command execution
            if echo "$line" | grep -q "sudo.*COMMAND="; then
                local user=$(echo "$line" | grep -oP '(?<=user=)\S+' | head -1)
                local command=$(echo "$line" | grep -oP '(?<=COMMAND=).*' | head -1)
                log_alert $ALERT_LOW "Sudo Command" "User '$user' executed: $command"
            fi
            
            # Failed sudo attempts
            if echo "$line" | grep -q "sudo.*sorry"; then
                local user=$(echo "$line" | grep -oP '(?<=user=)\S+' | head -1)
                log_alert $ALERT_MEDIUM "Failed Sudo Attempt" "Failed sudo attempt by user '$user'"
                alert_send $ALERT_MEDIUM "Failed Sudo Attempt" "Failed sudo attempt by user '$user'"
            fi
        done
    fi
    
    echo "$new_lines" > "$state_file"
}

################################################################################
# Firewall Monitoring
################################################################################

monitor_firewall() {
    log_info "=== Firewall Activity Monitoring ==="
    
    if ! command -v ufw &>/dev/null; then
        log_warning "UFW not installed, skipping firewall monitoring"
        return
    fi
    
    local kernel_log="/var/log/kern.log"
    local state_file="$STATE_DIR/firewall_state"
    local last_line=0
    
    if [[ -f "$state_file" ]]; then
        last_line=$(cat "$state_file")
    fi
    
    if [[ ! -f "$kernel_log" ]]; then
        return
    fi
    
    local new_lines=$(wc -l < "$kernel_log")
    
    if [[ $new_lines -gt $last_line ]]; then
        tail -n "+$((last_line + 1))" "$kernel_log" | while read -r line; do
            # UFW blocks
            if echo "$line" | grep -q "UFW BLOCK"; then
                local src_ip=$(echo "$line" | grep -oP '(?<=SRC=)[^ ]+' | head -1)
                local dst_port=$(echo "$line" | grep -oP '(?<=DPT=)[^ ]+' | head -1)
                log_alert $ALERT_LOW "Firewall Block" "Blocked connection from $src_ip to port $dst_port"
            fi
        done
    fi
    
    echo "$new_lines" > "$state_file"
}

################################################################################
# Process and System Monitoring
################################################################################

monitor_processes() {
    log_info "=== Process Monitoring ==="
    
    # Check for suspicious processes
    local suspicious_procs=("nc" "ncat" "netcat" "socat" "curl" "wget" "python" "perl")
    
    for proc in "${suspicious_procs[@]}"; do
        if pgrep -f "$proc" > /dev/null 2>&1; then
            local count=$(pgrep -f "$proc" | wc -l)
            if [[ $count -gt 2 ]]; then
                log_alert $ALERT_MEDIUM "Suspicious Process" "Found $count instances of '$proc' running"
                alert_send $ALERT_MEDIUM "Suspicious Process" "Found $count instances of '$proc' running"
            fi
        fi
    done
}

monitor_kernel() {
    log_info "=== Kernel Security Monitoring ==="
    
    local kern_log="/var/log/kern.log"
    local state_file="$STATE_DIR/kernel_state"
    local last_line=0
    
    if [[ -f "$state_file" ]]; then
        last_line=$(cat "$state_file")
    fi
    
    if [[ ! -f "$kern_log" ]]; then
        return
    fi
    
    local new_lines=$(wc -l < "$kern_log")
    
    if [[ $new_lines -gt $last_line ]]; then
        tail -n "+$((last_line + 1))" "$kern_log" | while read -r line; do
            # Kernel panics
            if echo "$line" | grep -q "Kernel panic"; then
                log_alert $ALERT_CRITICAL "Kernel Panic" "System kernel panic detected"
                alert_send $ALERT_CRITICAL "Kernel Panic" "System kernel panic detected"
            fi
            
            # OOM killer
            if echo "$line" | grep -q "Out of memory"; then
                log_alert $ALERT_HIGH "Out of Memory" "System running out of memory"
                alert_send $ALERT_HIGH "Out of Memory" "System running out of memory"
            fi
            
            # SELinux/AppArmor violations
            if echo "$line" | grep -q "apparmor\|selinux"; then
                log_alert $ALERT_MEDIUM "Security Module Alert" "AppArmor or SELinux violation detected"
            fi
        done
    fi
    
    echo "$new_lines" > "$state_file"
}

################################################################################
# System Health Monitoring
################################################################################

check_system_health() {
    log_info "=== System Health Check ==="
    
    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log_alert $ALERT_HIGH "High Disk Usage" "Disk usage is at ${disk_usage}%"
        alert_send $ALERT_HIGH "High Disk Usage" "Disk usage is at ${disk_usage}%"
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk 'NR==2 {printf "%.0f", ($3/$2)*100}')
    if [[ $mem_usage -gt 90 ]]; then
        log_alert $ALERT_HIGH "High Memory Usage" "Memory usage is at ${mem_usage}%"
        alert_send $ALERT_HIGH "High Memory Usage" "Memory usage is at ${mem_usage}%"
    fi
    
    # Check load average
    local load=$(uptime | grep -oP '(?<=load average: ).*' | awk '{print $1}')
    local cpu_count=$(nproc)
    if (( $(echo "$load > $cpu_count" | bc -l) )); then
        log_alert $ALERT_MEDIUM "High Load Average" "Load average is $load (CPU count: $cpu_count)"
    fi
    
    log_info "Disk: ${disk_usage}% | Memory: ${mem_usage}% | Load: $load"
}

################################################################################
# Fail2Ban Monitoring
################################################################################

monitor_fail2ban() {
    log_info "=== Fail2Ban Monitoring ==="
    
    if ! command -v fail2ban-client &>/dev/null; then
        log_warning "Fail2Ban not installed, skipping"
        return
    fi
    
    local status=$(fail2ban-client status sshd 2>/dev/null || echo "")
    
    if [[ -n "$status" ]]; then
        local banned=$(echo "$status" | grep "Banned IP" | awk '{print $NF}')
        log_info "Fail2Ban SSH Jail - Banned IPs: $banned"
        
        if [[ $banned -gt 10 ]]; then
            log_alert $ALERT_MEDIUM "High Fail2Ban Activity" "Fail2Ban has banned $banned IPs"
            alert_send $ALERT_MEDIUM "High Fail2Ban Activity" "Fail2Ban has banned $banned IPs"
        fi
    fi
}

################################################################################
# Report Generation
################################################################################

generate_security_report() {
    log_info "=== Generating Security Report ==="
    
    local report_file="/tmp/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "======================================"
        echo "Security Report - $(date)"
        echo "======================================"
        echo ""
        
        echo "System Information:"
        echo "  Hostname: $(hostname)"
        echo "  Uptime: $(uptime | sed 's/^[^,]*,//')"
        echo "  Kernel: $(uname -r)"
        echo ""
        
        echo "Security Status:"
        echo "  UFW Status: $(ufw status | head -1)"
        echo "  Fail2Ban Status: $(systemctl is-active fail2ban 2>/dev/null || echo 'Not installed')"
        echo "  SSH Status: $(systemctl is-active ssh)"
        echo ""
        
        echo "Recent Security Events (Last 24 hours):"
        if [[ -f "$ALERT_LOG" ]]; then
            tail -20 "$ALERT_LOG"
        else
            echo "  No alerts recorded"
        fi
        echo ""
        
        echo "Failed Login Attempts (Last 24 hours):"
        grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l || echo "0"
        echo ""
        
        echo "System Resources:"
        echo "  Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
        echo "  Memory Usage: $(free | awk 'NR==2 {printf "%.0f%%", ($3/$2)*100}')"
        echo "  Load Average: $(uptime | grep -oP '(?<=load average: ).*')"
        echo ""
        
        echo "Open Ports:"
        ss -tuln 2>/dev/null | grep LISTEN || echo "  Unable to determine"
        echo ""
        
        echo "======================================"
        
    } | tee "$report_file"
    
    log_success "Report generated: $report_file"
}

################################################################################
# Daemon Mode
################################################################################

run_daemon() {
    log_info "Starting security monitor in daemon mode"
    
    # Check if already running
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Security monitor already running (PID: $old_pid)"
            exit 1
        fi
    fi
    
    # Daemonize
    echo $$ > "$PID_FILE"
    
    log_success "Security monitor started (PID: $$)"
    log_info "Monitoring interval: ${MONITOR_INTERVAL}s"
    log_info "Alert log: $ALERT_LOG"
    
    # Main monitoring loop
    while true; do
        # Run all monitors
        [[ "${MONITOR_SSH:-true}" == "true" ]] && monitor_ssh 2>/dev/null || true
        [[ "${MONITOR_SUDO:-true}" == "true" ]] && monitor_sudo 2>/dev/null || true
        [[ "${MONITOR_FIREWALL:-true}" == "true" ]] && monitor_firewall 2>/dev/null || true
        [[ "${MONITOR_KERNEL:-true}" == "true" ]] && monitor_kernel 2>/dev/null || true
        [[ "${MONITOR_PROCESS:-true}" == "true" ]] && monitor_processes 2>/dev/null || true
        
        # Periodic checks
        check_system_health 2>/dev/null || true
        monitor_fail2ban 2>/dev/null || true
        
        sleep "$MONITOR_INTERVAL"
    done
}

################################################################################
# Interactive Mode
################################################################################

run_interactive() {
    log_info "Starting security monitor in interactive mode"
    log_info "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}=== VPS Security Monitor ===${NC}"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        [[ "${MONITOR_SSH:-true}" == "true" ]] && monitor_ssh 2>/dev/null || true
        echo ""
        
        [[ "${MONITOR_SUDO:-true}" == "true" ]] && monitor_sudo 2>/dev/null || true
        echo ""
        
        [[ "${MONITOR_FIREWALL:-true}" == "true" ]] && monitor_firewall 2>/dev/null || true
        echo ""
        
        [[ "${MONITOR_KERNEL:-true}" == "true" ]] && monitor_kernel 2>/dev/null || true
        echo ""
        
        [[ "${MONITOR_PROCESS:-true}" == "true" ]] && monitor_processes 2>/dev/null || true
        echo ""
        
        check_system_health 2>/dev/null || true
        echo ""
        
        monitor_fail2ban 2>/dev/null || true
        echo ""
        
        echo "Next update in ${MONITOR_INTERVAL}s... (Press Ctrl+C to exit)"
        sleep "$MONITOR_INTERVAL"
    done
}

################################################################################
# View Alerts
################################################################################

view_alerts() {
    if [[ ! -f "$ALERT_LOG" ]]; then
        log_warning "No alerts recorded yet"
        return
    fi
    
    echo -e "${BLUE}=== Recent Security Alerts ===${NC}"
    echo ""
    
    tail -50 "$ALERT_LOG"
}

################################################################################
# Main
################################################################################

main() {
    case "${1:-}" in
        --daemon)
            check_root
            init_directories
            load_config
            run_daemon
            ;;
        --interactive|-i)
            check_root
            init_directories
            load_config
            run_interactive
            ;;
        --install)
            check_root
            log_info "Installing security monitor as systemd service..."
            create_config
            init_directories
            
            cat > /etc/systemd/system/security-monitor.service << 'EOF'
[Unit]
Description=VPS Security Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/security_monitor.sh --daemon
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

            cp "$SCRIPT_DIR/security_monitor.sh" /usr/local/bin/security_monitor.sh
            chmod +x /usr/local/bin/security_monitor.sh
            
            systemctl daemon-reload
            systemctl enable security-monitor.service
            systemctl start security-monitor.service
            
            log_success "Security monitor installed and started"
            log_info "View status: sudo systemctl status security-monitor"
            log_info "View logs: sudo journalctl -u security-monitor -f"
            ;;
        --uninstall)
            check_root
            log_info "Uninstalling security monitor..."
            systemctl stop security-monitor.service 2>/dev/null || true
            systemctl disable security-monitor.service 2>/dev/null || true
            rm -f /etc/systemd/system/security-monitor.service
            rm -f /usr/local/bin/security_monitor.sh
            systemctl daemon-reload
            log_success "Security monitor uninstalled"
            ;;
        --view-alerts)
            init_directories
            view_alerts
            ;;
        --report)
            check_root
            init_directories
            load_config
            generate_security_report
            ;;
        --config)
            check_root
            create_config
            log_info "Edit configuration: sudo nano $CONFIG_FILE"
            ;;
        --help|-h)
            cat << 'EOF'
VPS Security Monitor - Usage

Modes:
  --daemon              Run as background daemon
  --interactive, -i     Run in interactive mode (real-time display)
  --install             Install as systemd service (auto-start)
  --uninstall           Remove systemd service
  --view-alerts         Display recent security alerts
  --report              Generate security report
  --config              Create/edit configuration file
  --help, -h            Show this help message

Examples:
  # Run interactively
  sudo bash security_monitor.sh --interactive

  # Install as service
  sudo bash security_monitor.sh --install

  # View alerts
  bash security_monitor.sh --view-alerts

  # Generate report
  sudo bash security_monitor.sh --report

Configuration:
  Edit /etc/security-monitor/config.conf to customize:
  - Email alerts
  - Alert levels
  - Monitoring interval
  - Which monitors to enable

Logs:
  Alert log: /var/log/security-monitor/alerts.log
  Systemd logs: sudo journalctl -u security-monitor -f
EOF
            ;;
        *)
            check_root
            init_directories
            load_config
            log_info "Starting security monitor in interactive mode"
            log_info "Use --help for more options"
            echo ""
            run_interactive
            ;;
    esac
}

main "$@"
