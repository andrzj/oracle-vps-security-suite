#!/usr/bin/env bash
# =============================================================================
# main.sh — Oracle Cloud VPS Unified Security Installer
# =============================================================================
# Guided, interactive setup that walks through every layer of the stack:
#
#   Phase 1 — System Hardening   (SSH, UFW, Fail2Ban, kernel, auto-updates)
#   Phase 2 — Security Monitoring (real-time log monitoring as a service)
#   Phase 3 — Dashboard Config    (collect env vars, configure Caddy)
#   Phase 4 — Dashboard Deploy    (Docker Compose up, health check)
#
# Usage:
#   git clone https://github.com/andrzj/oracle-vps-security-suite.git
#   cd oracle-vps-security-suite
#   sudo bash main.sh
#
# Requirements: Debian/Ubuntu, sudo, internet access
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║          Oracle Cloud VPS — Security Suite Installer         ║"
    echo "  ║                  github.com/andrzj/oracle-vps-security-suite ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

step()    { echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
success() { echo -e "${GREEN}✔  $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠  $*${RESET}"; }
error()   { echo -e "${RED}✖  $*${RESET}"; }
info()    { echo -e "${DIM}   $*${RESET}"; }
divider() { echo -e "\n${DIM}──────────────────────────────────────────────────────────────${RESET}"; }

ask() {
    # ask <variable_name> <prompt> [default]
    local var="$1"
    local prompt="$2"
    local default="${3:-}"
    local input

    if [[ -n "$default" ]]; then
        echo -ne "${BOLD}${prompt}${RESET} ${DIM}[${default}]${RESET}: "
    else
        echo -ne "${BOLD}${prompt}${RESET}: "
    fi

    read -r input
    if [[ -z "$input" && -n "$default" ]]; then
        input="$default"
    fi
    printf -v "$var" '%s' "$input"
}

ask_secret() {
    # ask_secret <variable_name> <prompt>
    local var="$1"
    local prompt="$2"
    local input

    echo -ne "${BOLD}${prompt}${RESET} ${DIM}(hidden)${RESET}: "
    read -rs input
    echo
    printf -v "$var" '%s' "$input"
}

confirm() {
    # confirm <prompt> — returns 0 for yes, 1 for no
    local prompt="$1"
    local answer
    echo -ne "${BOLD}${prompt}${RESET} ${DIM}[y/N]${RESET}: "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root or with sudo."
        echo "  Run: sudo bash main.sh"
        exit 1
    fi
}

require_debian() {
    if ! grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
        error "This installer requires a Debian or Ubuntu system."
        exit 1
    fi
}

check_internet() {
    if ! curl -sf --max-time 5 https://api.github.com > /dev/null 2>&1; then
        error "No internet connection detected. Please check your network."
        exit 1
    fi
}

# ── Script directory (works even when called from another path) ───────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
DASHBOARD_DIR="$SCRIPT_DIR/vps-security-dashboard"
DOCKER_DIR="$DASHBOARD_DIR/docker"
LOG_FILE="/var/log/vps-security-installer.log"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Installation state tracking ───────────────────────────────────────────────
STATE_FILE="/var/lib/vps-security-installer.state"

save_state() { echo "$1" >> "$STATE_FILE"; }
state_done() { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }

# =============================================================================
# WELCOME SCREEN
# =============================================================================
welcome() {
    print_banner
    echo -e "  ${BOLD}Welcome!${RESET} This installer will set up a fully hardened and monitored"
    echo    "  Oracle Cloud free tier VPS with a browser-based security dashboard."
    echo
    echo    "  The installer will guide you through four phases:"
    echo
    echo -e "  ${CYAN}Phase 1${RESET}  System Hardening    — SSH, UFW firewall, Fail2Ban, kernel"
    echo -e "  ${CYAN}Phase 2${RESET}  Security Monitoring — Real-time log monitoring service"
    echo -e "  ${CYAN}Phase 3${RESET}  Dashboard Config    — Collect credentials and configure Caddy"
    echo -e "  ${CYAN}Phase 4${RESET}  Dashboard Deploy    — Docker Compose launch and health check"
    echo
    echo -e "  ${DIM}Estimated time: 5–10 minutes${RESET}"
    echo -e "  ${DIM}Log file: ${LOG_FILE}${RESET}"
    divider

    if ! confirm "Ready to begin?"; then
        echo "Installer cancelled."
        exit 0
    fi
}

# =============================================================================
# PHASE 1 — SYSTEM HARDENING
# =============================================================================
phase_hardening() {
    divider
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════╗"
    echo    "║  Phase 1 — System Hardening              ║"
    echo -e "╚══════════════════════════════════════════╝${RESET}"
    echo
    echo    "  This phase will harden your VPS at the OS level:"
    echo -e "  ${DIM}• Update system packages and enable automatic security updates${RESET}"
    echo -e "  ${DIM}• Harden SSH (disable root login, disable password auth)${RESET}"
    echo -e "  ${DIM}• Configure UFW firewall with sensible defaults${RESET}"
    echo -e "  ${DIM}• Install and configure Fail2Ban for brute-force protection${RESET}"
    echo -e "  ${DIM}• Apply kernel hardening parameters (sysctl)${RESET}"
    echo -e "  ${DIM}• Install AIDE file integrity monitoring${RESET}"
    echo

    if state_done "hardening"; then
        warn "System hardening was already completed in a previous run. Skipping."
        return 0
    fi

    # ── SSH port ──────────────────────────────────────────────────────────────
    echo -e "  ${BOLD}SSH Configuration${RESET}"
    echo    "  The default SSH port is 22. Changing it to a non-standard port"
    echo    "  significantly reduces automated scan noise."
    echo
    local ssh_port
    ask ssh_port "  SSH port to use" "22"

    if [[ ! "$ssh_port" =~ ^[0-9]+$ ]] || (( ssh_port < 1 || ssh_port > 65535 )); then
        warn "Invalid port number. Defaulting to 22."
        ssh_port=22
    fi

    if [[ "$ssh_port" != "22" ]]; then
        warn "You are changing SSH to port ${ssh_port}."
        echo    "  IMPORTANT: Before closing this session, open a NEW terminal and"
        echo    "  verify you can connect on the new port. Also update your Oracle"
        echo    "  Cloud Security List to allow TCP port ${ssh_port}."
        echo
        if ! confirm "  I understand. Proceed with port ${ssh_port}?"; then
            ssh_port=22
            info "Keeping SSH on port 22."
        fi
    fi

    # ── Optional 2FA ─────────────────────────────────────────────────────────
    local enable_2fa=false
    echo
    echo -e "  ${BOLD}SSH Two-Factor Authentication (2FA)${RESET}"
    echo    "  Adds Google Authenticator TOTP to SSH login."
    echo    "  You will need the Google Authenticator app on your phone."
    echo
    if confirm "  Enable SSH 2FA?"; then
        enable_2fa=true
    fi

    # ── Run hardening script ──────────────────────────────────────────────────
    step "Running system hardening script..."

    if [[ ! -f "$SCRIPTS_DIR/hardening/debian_security_hardening.sh" ]]; then
        error "Hardening script not found at $SCRIPTS_DIR/hardening/debian_security_hardening.sh"
        exit 1
    fi

    # Pass SSH port as environment variable so the hardening script can use it
    SSH_PORT="$ssh_port" bash "$SCRIPTS_DIR/hardening/debian_security_hardening.sh"
    success "System hardening complete."

    if [[ "$enable_2fa" == true ]]; then
        step "Setting up SSH 2FA..."
        bash "$SCRIPTS_DIR/hardening/setup_ssh_2fa.sh"
        success "SSH 2FA configured."
    fi

    save_state "hardening"

    # ── Verification ─────────────────────────────────────────────────────────
    step "Verifying hardening..."
    bash "$SCRIPTS_DIR/utilities/verify_security.sh" || warn "Some checks did not pass — review the output above."

    echo
    success "Phase 1 complete."

    if [[ "$ssh_port" != "22" ]]; then
        echo
        warn "SSH port changed to ${ssh_port}. Test your connection NOW in a new terminal:"
        echo -e "  ${BOLD}ssh -p ${ssh_port} -i your-key.pem ubuntu@YOUR_VPS_IP${RESET}"
        echo
        if ! confirm "  Confirmed — I can connect on port ${ssh_port}. Continue?"; then
            error "Aborting to allow you to fix SSH access. Re-run main.sh when ready."
            exit 1
        fi
    fi
}

# =============================================================================
# PHASE 2 — SECURITY MONITORING
# =============================================================================
phase_monitoring() {
    divider
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════╗"
    echo    "║  Phase 2 — Security Monitoring           ║"
    echo -e "╚══════════════════════════════════════════╝${RESET}"
    echo
    echo    "  This phase installs the real-time security monitoring service:"
    echo -e "  ${DIM}• Monitors SSH login attempts, sudo usage, and firewall blocks${RESET}"
    echo -e "  ${DIM}• Runs as a systemd service (starts automatically on boot)${RESET}"
    echo -e "  ${DIM}• Writes security alerts to /var/log/security-monitor.log${RESET}"
    echo -e "  ${DIM}• Optionally sends email alerts for critical events${RESET}"
    echo

    if state_done "monitoring"; then
        warn "Security monitoring was already installed in a previous run. Skipping."
        return 0
    fi

    if [[ ! -f "$SCRIPTS_DIR/monitoring/security_monitor.sh" ]]; then
        error "Monitoring script not found at $SCRIPTS_DIR/monitoring/security_monitor.sh"
        exit 1
    fi

    step "Installing security monitoring service..."
    bash "$SCRIPTS_DIR/monitoring/security_monitor.sh" --install
    success "Security monitoring service installed and started."

    # ── Optional email alerts ─────────────────────────────────────────────────
    echo
    echo -e "  ${BOLD}Email Alerts (optional)${RESET}"
    echo    "  Configure email notifications for critical security events."
    echo
    if confirm "  Configure email alerts now?"; then
        bash "$SCRIPTS_DIR/monitoring/setup_email_alerts.sh"
    else
        info "Skipping email alerts. You can configure them later by running:"
        info "  sudo bash scripts/monitoring/setup_email_alerts.sh"
    fi

    # ── Schedule automatic updates ────────────────────────────────────────────
    echo
    echo -e "  ${BOLD}Automatic Monitoring Updates (optional)${RESET}"
    echo    "  Schedule weekly automatic updates for the monitoring scripts."
    echo
    if confirm "  Enable weekly auto-updates for monitoring scripts?"; then
        bash "$SCRIPTS_DIR/updates/update_monitor.sh" --schedule
        success "Weekly auto-updates scheduled."
    fi

    save_state "monitoring"
    echo
    success "Phase 2 complete."
    info "Check monitoring status anytime: sudo systemctl status security-monitor"
}

# =============================================================================
# PHASE 3 — DASHBOARD CONFIGURATION
# =============================================================================
phase_dashboard_config() {
    divider
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════╗"
    echo    "║  Phase 3 — Dashboard Configuration       ║"
    echo -e "╚══════════════════════════════════════════╝${RESET}"
    echo
    echo    "  This phase collects the credentials needed to run the security"
    echo    "  dashboard and writes them to the Docker environment file."
    echo

    if state_done "dashboard_config"; then
        warn "Dashboard was already configured in a previous run."
        if ! confirm "  Re-configure? (This will overwrite the existing .env file)"; then
            return 0
        fi
    fi

    if [[ ! -d "$DOCKER_DIR" ]]; then
        error "Dashboard docker directory not found at $DOCKER_DIR"
        echo  "  Make sure you cloned the full repository."
        exit 1
    fi

    # ── Collect values ────────────────────────────────────────────────────────
    echo -e "  ${BOLD}Step 3a — Domain${RESET}"
    echo    "  The domain you will use to access the dashboard."
    echo    "  Example: security.yourdomain.com"
    echo
    local domain
    ask domain "  Dashboard domain"
    while [[ -z "$domain" ]]; do
        warn "Domain cannot be empty."
        ask domain "  Dashboard domain"
    done

    echo
    echo -e "  ${BOLD}Step 3b — Trusted IP${RESET}"
    echo    "  Only this IP address will be allowed to access the dashboard."
    echo    "  All other IPs will receive a connection refused response."
    echo
    local detected_ip
    detected_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "")
    if [[ -n "$detected_ip" ]]; then
        info "Detected your current IP: ${detected_ip}"
    fi
    local trusted_ip
    ask trusted_ip "  Your trusted IP address" "${detected_ip}"
    while [[ -z "$trusted_ip" ]]; do
        warn "Trusted IP cannot be empty."
        ask trusted_ip "  Your trusted IP address"
    done

    echo
    echo -e "  ${BOLD}Step 3c — JWT Secret${RESET}"
    echo    "  A strong random secret used to sign session cookies."
    echo    "  Leave blank to auto-generate a secure 64-character secret."
    echo
    local jwt_secret
    ask_secret jwt_secret "  JWT secret (blank to auto-generate)"
    if [[ -z "$jwt_secret" ]]; then
        jwt_secret=$(openssl rand -hex 64)
        success "Auto-generated JWT secret."
    fi

    echo
    echo -e "  ${BOLD}Step 3d — Admin Account${RESET}"
    echo    "  The dashboard uses self-contained authentication — no external platform needed."
    echo    "  On first visit, you will be prompted to create your admin account in the browser."
    echo    "  Your credentials will be stored securely (bcrypt) in the local SQLite database."
    echo
    info "No credentials to enter here. The first-run setup screen handles account creation."
    local sqlite_db_path
    sqlite_db_path="/app/data/security-dashboard.db"

    # ── Write .env file ───────────────────────────────────────────────────────
    step "Writing environment file..."
    cat > "$DOCKER_DIR/.env" <<EOF
# VPS Security Dashboard — Environment Configuration
# Generated by main.sh on $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Permissions: chmod 600 .env

# ── Domain & Network ──────────────────────────────────────────────────────────
DOMAIN=${domain}
TRUSTED_IP=${trusted_ip}

# ── Security ──────────────────────────────────────────────────────────────────
JWT_SECRET=${jwt_secret}

# ── Database ──────────────────────────────────────────────────────────────────
# SQLite file path inside the container. Persisted via Docker named volume.
SQLITE_DB_PATH=${sqlite_db_path}

# ── Runtime ───────────────────────────────────────────────────────────────────
NODE_ENV=production
EOF
    chmod 600 "$DOCKER_DIR/.env"
    success "Environment file written to $DOCKER_DIR/.env (permissions: 600)"

    # ── Update Caddyfile ──────────────────────────────────────────────────────
    step "Configuring Caddyfile..."
    local caddyfile="$DOCKER_DIR/caddy/Caddyfile"
    if [[ -f "$caddyfile" ]]; then
        sed -i \
            -e "s/YOUR_DOMAIN/${domain}/g" \
            -e "s/YOUR_HOME_IP/${trusted_ip}/g" \
            "$caddyfile"
        success "Caddyfile updated with domain '${domain}' and IP '${trusted_ip}'."
    else
        warn "Caddyfile not found at $caddyfile — you will need to configure it manually."
    fi

    # ── Sudoers ───────────────────────────────────────────────────────────────
    step "Installing sudoers configuration..."
    local sudoers_src="$DOCKER_DIR/sudoers-dashboard.conf"
    if [[ -f "$sudoers_src" ]]; then
        cp "$sudoers_src" /etc/sudoers.d/dashboard
        chmod 440 /etc/sudoers.d/dashboard
        if sudo visudo -c &>/dev/null; then
            success "Sudoers configuration installed and validated."
        else
            error "Sudoers file failed validation. Removing to prevent lockout."
            rm -f /etc/sudoers.d/dashboard
            warn "Install sudoers manually: sudo cp $sudoers_src /etc/sudoers.d/dashboard"
        fi
    else
        warn "sudoers-dashboard.conf not found. Skipping — install manually if needed."
    fi

    save_state "dashboard_config"
    echo
    success "Phase 3 complete."
}

# =============================================================================
# PHASE 4 — DASHBOARD DEPLOY
# =============================================================================
phase_dashboard_deploy() {
    divider
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════╗"
    echo    "║  Phase 4 — Dashboard Deploy               ║"
    echo -e "╚══════════════════════════════════════════╝${RESET}"
    echo
    echo    "  This phase checks Docker is installed, then launches the"
    echo    "  security dashboard stack with Docker Compose."
    echo

    # ── Docker check ─────────────────────────────────────────────────────────
    step "Checking Docker installation..."
    if ! command -v docker &>/dev/null; then
        warn "Docker is not installed. Installing now..."
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "$SUDO_USER" 2>/dev/null || true
        success "Docker installed."
    else
        success "Docker found: $(docker --version)"
    fi

    if ! docker compose version &>/dev/null; then
        warn "Docker Compose plugin not found. Installing..."
        apt-get install -y docker-compose-plugin
        success "Docker Compose installed."
    else
        success "Docker Compose found: $(docker compose version)"
    fi

    # ── DNS check ────────────────────────────────────────────────────────────
    local domain
    domain=$(grep "^DOMAIN=" "$DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2)
    if [[ -n "$domain" ]]; then
        step "Checking DNS for ${domain}..."
        local resolved_ip
        resolved_ip=$(dig +short "$domain" 2>/dev/null | head -1)
        local vps_ip
        vps_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "")

        if [[ -z "$resolved_ip" ]]; then
            warn "DNS for '${domain}' does not resolve yet."
            info "Point an A record to your VPS IP (${vps_ip}) before Caddy can obtain a TLS certificate."
            info "You can still deploy now — Caddy will retry certificate issuance automatically."
        elif [[ "$resolved_ip" == "$vps_ip" ]]; then
            success "DNS resolves correctly: ${domain} → ${resolved_ip}"
        else
            warn "DNS mismatch: ${domain} resolves to ${resolved_ip}, but this VPS IP is ${vps_ip}."
            info "Update your DNS A record to point to ${vps_ip}."
        fi
    fi

    # ── Deploy ────────────────────────────────────────────────────────────────
    step "Launching Docker Compose stack..."
    cd "$DOCKER_DIR"
    docker compose pull 2>/dev/null || true
    docker compose up -d --build

    # ── Health check ─────────────────────────────────────────────────────────
    step "Waiting for containers to become healthy..."
    local retries=12
    local healthy=false
    for (( i=1; i<=retries; i++ )); do
        local app_status caddy_status
        app_status=$(docker compose ps --format json 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Health','unknown'))" \
            2>/dev/null || echo "unknown")

        if docker compose ps | grep -q "healthy"; then
            healthy=true
            break
        fi
        echo -ne "  Attempt ${i}/${retries}...\r"
        sleep 5
    done

    echo
    if [[ "$healthy" == true ]]; then
        success "All containers are healthy."
    else
        warn "Containers may still be starting. Check with: docker compose ps"
    fi

    docker compose ps

    save_state "dashboard_deploy"
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================
final_summary() {
    local domain
    domain=$(grep "^DOMAIN=" "$DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "your-domain.com")
    local trusted_ip
    trusted_ip=$(grep "^TRUSTED_IP=" "$DOCKER_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "your-ip")

    divider
    echo
    echo -e "${GREEN}${BOLD}  ✔  Installation complete!${RESET}"
    echo
    echo -e "  ${BOLD}Dashboard URL:${RESET}   https://${domain}"
    echo -e "  ${BOLD}Accessible from:${RESET} ${trusted_ip} only"
    echo -e "  ${BOLD}Install log:${RESET}     ${LOG_FILE}"
    echo
    divider
    echo
    echo -e "  ${BOLD}Quick reference:${RESET}"
    echo
    echo -e "  ${CYAN}# View dashboard logs${RESET}"
    echo    "  cd $DOCKER_DIR && docker compose logs -f"
    echo
    echo -e "  ${CYAN}# Check monitoring service${RESET}"
    echo    "  sudo systemctl status security-monitor"
    echo
    echo -e "  ${CYAN}# View security alerts${RESET}"
    echo    "  sudo bash $SCRIPTS_DIR/monitoring/security_monitor.sh --view-alerts"
    echo
    echo -e "  ${CYAN}# Analyse logs${RESET}"
    echo    "  bash $SCRIPTS_DIR/monitoring/analyze_logs.sh"
    echo
    echo -e "  ${CYAN}# Update your trusted IP (if it changes)${RESET}"
    echo    "  nano $DOCKER_DIR/caddy/Caddyfile"
    echo    "  cd $DOCKER_DIR && docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile"
    echo
    echo -e "  ${CYAN}# Backup the SQLite database${RESET}"
    echo    "  docker run --rm -v vps-security-dashboard_app_data:/data \\"
    echo    "    -v \$(pwd):/backup alpine \\"
    echo    "    cp /data/security-dashboard.db /backup/security-dashboard-\$(date +%F).db"
    echo
    divider
    echo
    echo -e "  ${DIM}Full documentation: $SCRIPT_DIR/vps-security-dashboard/DEPLOYMENT.md${RESET}"
    echo
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
main() {
    require_root
    require_debian
    check_internet

    # Initialise state file
    mkdir -p "$(dirname "$STATE_FILE")"
    touch "$STATE_FILE"

    welcome
    phase_hardening
    phase_monitoring
    phase_dashboard_config
    phase_dashboard_deploy
    final_summary
}

main "$@"
