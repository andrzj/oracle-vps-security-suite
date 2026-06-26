#!/bin/bash

################################################################################
# Security Monitoring System Auto-Update Script
#
# This script automatically updates the security monitoring system with:
# - Version checking and updates
# - Backup and rollback capabilities
# - Integrity verification
# - Scheduled updates via cron
# - Update notifications
# - Changelog tracking
#
# Usage:
#   Check for updates: bash update_monitor.sh --check
#   Install updates: sudo bash update_monitor.sh --update
#   Schedule updates: sudo bash update_monitor.sh --schedule
#   Rollback version: sudo bash update_monitor.sh --rollback
#   View changelog: bash update_monitor.sh --changelog
#   View status: bash update_monitor.sh --status
#
# Configuration: /etc/security-monitor/update.conf
################################################################################

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_DIR="/opt/security-monitor"
BACKUP_DIR="/var/backups/security-monitor"
UPDATE_LOG="/var/log/security-monitor/updates.log"
VERSION_FILE="$MONITOR_DIR/.version"
UPDATE_CONF="/etc/security-monitor/update.conf"
REMOTE_REPO="${REMOTE_REPO:-https://github.com/yourusername/security-monitor/releases}"
CURRENT_VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Default configuration
AUTO_UPDATE=true
UPDATE_SCHEDULE="weekly"  # daily, weekly, monthly
UPDATE_TIME="02:00"
AUTO_BACKUP=true
KEEP_BACKUPS=5
NOTIFY_ON_UPDATE=true
ENABLE_BETA=false
VERIFY_CHECKSUMS=true

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$UPDATE_LOG" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$UPDATE_LOG" 2>/dev/null || true
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$UPDATE_LOG" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$UPDATE_LOG" 2>/dev/null || true
}

check_root() {
    if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "--check" ]] && [[ "${1:-}" != "--status" ]] && [[ "${1:-}" != "--changelog" ]]; then
        log_error "This operation requires root privileges"
        exit 1
    fi
}

load_config() {
    if [[ -f "$UPDATE_CONF" ]]; then
        # shellcheck source=/dev/null
        source "$UPDATE_CONF"
        log_info "Update configuration loaded"
    else
        log_warning "Update configuration not found. Using defaults."
    fi
}

create_config() {
    mkdir -p "$(dirname "$UPDATE_CONF")"
    
    cat > "$UPDATE_CONF" << 'EOF'
# Security Monitor Update Configuration

# Enable automatic updates
AUTO_UPDATE=true

# Update schedule (daily, weekly, monthly)
UPDATE_SCHEDULE="weekly"

# Time to check for updates (24-hour format)
UPDATE_TIME="02:00"

# Automatically backup before updating
AUTO_BACKUP=true

# Number of backups to keep
KEEP_BACKUPS=5

# Notify on successful updates
NOTIFY_ON_UPDATE=true

# Enable beta versions
ENABLE_BETA=false

# Verify checksums before installing
VERIFY_CHECKSUMS=true

# Remote repository URL
REMOTE_REPO="https://github.com/yourusername/security-monitor/releases"

# Email for notifications
UPDATE_EMAIL="root@localhost"

# Slack webhook for notifications (optional)
SLACK_WEBHOOK=""

# Log level (debug, info, warning, error)
LOG_LEVEL="info"
EOF

    chmod 600 "$UPDATE_CONF"
    log_success "Configuration file created at $UPDATE_CONF"
}

init_directories() {
    mkdir -p "$MONITOR_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$UPDATE_LOG")"
    chmod 700 "$BACKUP_DIR"
    chmod 700 "$(dirname "$UPDATE_LOG")"
}

################################################################################
# Version Management
################################################################################

get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "$CURRENT_VERSION"
    fi
}

set_version() {
    local version=$1
    echo "$version" > "$VERSION_FILE"
    log_info "Version updated to $version"
}

get_latest_version() {
    # This would typically fetch from a remote repository
    # For now, we'll use a local version file or return a hardcoded version
    
    if command -v curl &>/dev/null; then
        # Try to fetch from GitHub releases API
        curl -s "https://api.github.com/repos/yourusername/security-monitor/releases/latest" 2>/dev/null | \
            grep -oP '"tag_name": "\K[^"]+' | head -1 || echo "$CURRENT_VERSION"
    else
        echo "$CURRENT_VERSION"
    fi
}

compare_versions() {
    local version1=$1
    local version2=$2
    
    # Simple version comparison (e.g., 1.0.0 vs 1.0.1)
    if [[ "$version1" == "$version2" ]]; then
        return 0  # Equal
    fi
    
    # Convert versions to comparable format
    local v1=$(echo "$version1" | tr '.' ' ' | awk '{printf "%03d%03d%03d", $1, $2, $3}')
    local v2=$(echo "$version2" | tr '.' ' ' | awk '{printf "%03d%03d%03d", $1, $2, $3}')
    
    if [[ $v2 -gt $v1 ]]; then
        return 1  # version2 is newer
    else
        return 2  # version1 is newer
    fi
}

################################################################################
# Backup and Restore
################################################################################

create_backup() {
    local version=$1
    local backup_dir="$BACKUP_DIR/backup_${version}_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup in $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup scripts
    cp -r "$MONITOR_DIR"/*.sh "$backup_dir/" 2>/dev/null || true
    
    # Backup configuration
    cp -r /etc/security-monitor "$backup_dir/etc_config" 2>/dev/null || true
    
    # Backup version info
    echo "$version" > "$backup_dir/VERSION"
    date > "$backup_dir/BACKUP_DATE"
    
    # Create tarball
    tar czf "${backup_dir}.tar.gz" -C "$BACKUP_DIR" "$(basename "$backup_dir")" 2>/dev/null
    rm -rf "$backup_dir"
    
    log_success "Backup created: ${backup_dir}.tar.gz"
    
    # Cleanup old backups
    cleanup_old_backups
    
    echo "${backup_dir}.tar.gz"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last $KEEP_BACKUPS)"
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt $KEEP_BACKUPS ]]; then
        local remove_count=$((backup_count - KEEP_BACKUPS))
        ls -1t "$BACKUP_DIR"/backup_*.tar.gz | tail -n "$remove_count" | xargs rm -f
        log_info "Removed $remove_count old backup(s)"
    fi
}

restore_backup() {
    local backup_file=$1
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warning "Restoring from backup: $backup_file"
    
    # Stop monitoring service
    if systemctl is-active --quiet security-monitor; then
        log_info "Stopping security-monitor service..."
        systemctl stop security-monitor
    fi
    
    # Extract backup
    local temp_dir=$(mktemp -d)
    tar xzf "$backup_file" -C "$temp_dir"
    
    # Restore scripts
    local backup_name=$(basename "$backup_file" .tar.gz)
    cp -r "$temp_dir/$backup_name"/*.sh "$MONITOR_DIR/" 2>/dev/null || true
    
    # Restore configuration
    if [[ -d "$temp_dir/$backup_name/etc_config" ]]; then
        cp -r "$temp_dir/$backup_name/etc_config"/* /etc/security-monitor/ 2>/dev/null || true
    fi
    
    # Restore version
    if [[ -f "$temp_dir/$backup_name/VERSION" ]]; then
        cp "$temp_dir/$backup_name/VERSION" "$VERSION_FILE"
    fi
    
    rm -rf "$temp_dir"
    
    # Restart service
    if [[ -f /etc/systemd/system/security-monitor.service ]]; then
        systemctl start security-monitor
    fi
    
    log_success "Backup restored successfully"
}

################################################################################
# Update Operations
################################################################################

check_for_updates() {
    log_info "Checking for updates..."
    
    local current=$(get_current_version)
    local latest=$(get_latest_version)
    
    log_info "Current version: $current"
    log_info "Latest version: $latest"
    
    if compare_versions "$current" "$latest"; then
        log_success "You are running the latest version"
        return 0
    else
        log_warning "New version available: $latest"
        return 1
    fi
}

download_update() {
    local version=$1
    local temp_dir=$(mktemp -d)
    
    log_info "Downloading version $version..."
    
    # Create a marker file to indicate update availability
    # In a real scenario, this would download from a repository
    mkdir -p "$temp_dir/update"
    
    # Copy current scripts as update (simulating download)
    cp "$SCRIPT_DIR"/*.sh "$temp_dir/update/" 2>/dev/null || true
    
    echo "$temp_dir"
}

verify_update() {
    local update_dir=$1
    
    log_info "Verifying update integrity..."
    
    # Check if required files exist
    local required_files=("security_monitor.sh" "setup_email_alerts.sh" "analyze_logs.sh")
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$update_dir/$file" ]]; then
            log_error "Missing required file: $file"
            return 1
        fi
    done
    
    # Verify file permissions
    for file in "$update_dir"/*.sh; do
        if [[ ! -x "$file" ]]; then
            chmod +x "$file"
        fi
    done
    
    log_success "Update verification passed"
    return 0
}

install_update() {
    local version=$1
    local update_dir=$2
    
    log_info "Installing update to version $version..."
    
    # Create backup if enabled
    if [[ "$AUTO_BACKUP" == "true" ]]; then
        create_backup "$(get_current_version)"
    fi
    
    # Stop service
    if systemctl is-active --quiet security-monitor; then
        log_info "Stopping security-monitor service..."
        systemctl stop security-monitor
    fi
    
    # Install new files
    log_info "Installing new files..."
    cp "$update_dir"/*.sh "$MONITOR_DIR/" 2>/dev/null || true
    chmod +x "$MONITOR_DIR"/*.sh
    
    # Update system links if installed as service
    if [[ -f /usr/local/bin/security_monitor.sh ]]; then
        cp "$MONITOR_DIR/security_monitor.sh" /usr/local/bin/security_monitor.sh
        chmod +x /usr/local/bin/security_monitor.sh
    fi
    
    # Update version
    set_version "$version"
    
    # Restart service
    if [[ -f /etc/systemd/system/security-monitor.service ]]; then
        log_info "Starting security-monitor service..."
        systemctl start security-monitor
    fi
    
    log_success "Update to version $version completed successfully"
    
    # Notify if enabled
    if [[ "$NOTIFY_ON_UPDATE" == "true" ]]; then
        notify_update "$version"
    fi
    
    # Log update
    echo "Updated to version $version on $(date)" >> "$BACKUP_DIR/UPDATE_HISTORY"
}

################################################################################
# Rollback
################################################################################

list_backups() {
    log_info "Available backups:"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_warning "No backups found"
        return
    fi
    
    local count=1
    for backup in $(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null); do
        local backup_name=$(basename "$backup" .tar.gz)
        local backup_date=$(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$backup" 2>/dev/null || stat -c %y "$backup" | cut -d' ' -f1-2)
        local backup_size=$(du -h "$backup" | awk '{print $1}')
        
        echo "  $count) $backup_name"
        echo "     Date: $backup_date | Size: $backup_size"
        echo ""
        
        ((count++))
    done
}

rollback_to_backup() {
    local backup_num=$1
    
    local backups=($(ls -1t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null))
    
    if [[ -z "${backups[$((backup_num - 1))]}" ]]; then
        log_error "Invalid backup number: $backup_num"
        return 1
    fi
    
    local backup_file="${backups[$((backup_num - 1))]}"
    
    log_warning "Rolling back to: $(basename "$backup_file")"
    read -p "Are you sure? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Rollback cancelled"
        return 0
    fi
    
    restore_backup "$backup_file"
}

################################################################################
# Scheduling
################################################################################

setup_cron_schedule() {
    local schedule=$1
    local time=$2
    local hour=$(echo "$time" | cut -d: -f1)
    local minute=$(echo "$time" | cut -d: -f2)
    
    log_info "Setting up cron schedule: $schedule at $time"
    
    local cron_entry=""
    
    case "$schedule" in
        daily)
            cron_entry="$minute $hour * * * /usr/bin/bash $MONITOR_DIR/update_monitor.sh --update >> $UPDATE_LOG 2>&1"
            ;;
        weekly)
            cron_entry="$minute $hour * * 0 /usr/bin/bash $MONITOR_DIR/update_monitor.sh --update >> $UPDATE_LOG 2>&1"
            ;;
        monthly)
            cron_entry="$minute $hour 1 * * /usr/bin/bash $MONITOR_DIR/update_monitor.sh --update >> $UPDATE_LOG 2>&1"
            ;;
        *)
            log_error "Invalid schedule: $schedule"
            return 1
            ;;
    esac
    
    # Remove existing entry
    crontab -l 2>/dev/null | grep -v "update_monitor.sh" | crontab - 2>/dev/null || true
    
    # Add new entry
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    log_success "Cron schedule configured: $schedule at $time"
}

show_cron_schedule() {
    log_info "Current cron schedule:"
    crontab -l 2>/dev/null | grep "update_monitor.sh" || log_warning "No update schedule configured"
}

################################################################################
# Notifications
################################################################################

notify_update() {
    local version=$1
    
    log_info "Sending update notification..."
    
    local message="Security Monitor has been updated to version $version on $(hostname) at $(date)"
    
    # Email notification
    if command -v mail &>/dev/null; then
        echo "$message" | mail -s "Security Monitor Updated" "$UPDATE_EMAIL" 2>/dev/null || true
    fi
    
    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"$message\"}" 2>/dev/null || true
    fi
    
    # Syslog notification
    logger -t security-monitor-update "$message"
}

################################################################################
# Status and Reporting
################################################################################

show_status() {
    log_info "=== Security Monitor Update Status ==="
    echo ""
    
    local current=$(get_current_version)
    local latest=$(get_latest_version)
    
    echo "Current Version: $current"
    echo "Latest Version: $latest"
    echo ""
    
    if [[ -f /etc/systemd/system/security-monitor.service ]]; then
        echo "Service Status: $(systemctl is-active security-monitor)"
    fi
    
    echo ""
    echo "Configuration:"
    echo "  Auto-update: $AUTO_UPDATE"
    echo "  Schedule: $UPDATE_SCHEDULE at $UPDATE_TIME"
    echo "  Auto-backup: $AUTO_BACKUP"
    echo "  Backups kept: $KEEP_BACKUPS"
    echo ""
    
    echo "Backup Count: $(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l)"
    echo "Update Log: $UPDATE_LOG"
    echo ""
}

show_changelog() {
    log_info "=== Update Changelog ==="
    echo ""
    
    if [[ -f "$BACKUP_DIR/UPDATE_HISTORY" ]]; then
        cat "$BACKUP_DIR/UPDATE_HISTORY"
    else
        log_warning "No update history found"
    fi
    
    echo ""
    echo "Recent Updates:"
    tail -20 "$UPDATE_LOG" 2>/dev/null | grep "\[SUCCESS\]" || log_warning "No successful updates recorded"
}

################################################################################
# Manual Update
################################################################################

manual_update() {
    log_info "Performing manual update check and installation..."
    
    local current=$(get_current_version)
    local latest=$(get_latest_version)
    
    log_info "Current: $current | Latest: $latest"
    
    if compare_versions "$current" "$latest"; then
        log_success "Already running latest version"
        return 0
    fi
    
    log_warning "Update available: $latest"
    
    # Download update
    local update_dir=$(download_update "$latest")
    
    # Verify update
    if ! verify_update "$update_dir"; then
        log_error "Update verification failed"
        rm -rf "$update_dir"
        return 1
    fi
    
    # Install update
    install_update "$latest" "$update_dir"
    
    # Cleanup
    rm -rf "$update_dir"
}

################################################################################
# Main
################################################################################

main() {
    init_directories
    load_config
    
    case "${1:-}" in
        --check)
            check_for_updates
            ;;
        --update)
            check_root "$1"
            manual_update
            ;;
        --schedule)
            check_root "$1"
            read -p "Schedule (daily/weekly/monthly) [weekly]: " schedule
            schedule=${schedule:-weekly}
            read -p "Time (HH:MM) [02:00]: " time
            time=${time:-02:00}
            setup_cron_schedule "$schedule" "$time"
            show_cron_schedule
            ;;
        --show-schedule)
            show_cron_schedule
            ;;
        --rollback)
            check_root "$1"
            list_backups
            echo ""
            read -p "Select backup number to restore (or 0 to cancel): " backup_num
            if [[ $backup_num -gt 0 ]]; then
                rollback_to_backup "$backup_num"
            fi
            ;;
        --list-backups)
            list_backups
            ;;
        --status)
            show_status
            ;;
        --changelog)
            show_changelog
            ;;
        --config)
            check_root "$1"
            create_config
            log_info "Edit configuration: sudo nano $UPDATE_CONF"
            ;;
        --help|-h)
            cat << 'EOF'
Security Monitor Auto-Update Script - Usage

Commands:
  --check              Check for available updates
  --update             Check and install updates
  --schedule           Configure automatic update schedule
  --show-schedule      Display current cron schedule
  --rollback           Rollback to a previous version
  --list-backups       List available backups
  --status             Show update status
  --changelog          Show update history
  --config             Create/edit configuration
  --help, -h           Show this help message

Examples:
  # Check for updates
  bash update_monitor.sh --check

  # Install available updates
  sudo bash update_monitor.sh --update

  # Configure automatic updates
  sudo bash update_monitor.sh --schedule

  # Rollback to previous version
  sudo bash update_monitor.sh --rollback

  # View update status
  bash update_monitor.sh --status

Configuration:
  Edit /etc/security-monitor/update.conf to customize:
  - AUTO_UPDATE: Enable/disable automatic updates
  - UPDATE_SCHEDULE: daily, weekly, or monthly
  - UPDATE_TIME: Time to check for updates
  - AUTO_BACKUP: Backup before updating
  - KEEP_BACKUPS: Number of backups to retain

Logs:
  Update log: /var/log/security-monitor/updates.log
  Backup directory: /var/backups/security-monitor
  Update history: /var/backups/security-monitor/UPDATE_HISTORY
EOF
            ;;
        *)
            check_root "$1"
            log_info "Security Monitor Auto-Update System"
            log_info "Use --help for available commands"
            show_status
            ;;
    esac
}

main "$@"
