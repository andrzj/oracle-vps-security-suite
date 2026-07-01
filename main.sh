#!/usr/bin/env bash
# =============================================================================
# main.sh — Oracle Cloud VPS Unified Security Installer
# =============================================================================
# Guided, interactive setup that walks through every layer of the stack:
#
#   Phase 1 — System Hardening   (SSH, UFW, Fail2Ban, kernel, auto-updates)
#   Phase 2 — Security Monitoring (real-time log monitoring as a service)
#   Phase 3 — Dashboard Config    (sudoers install + Coolify env var reference)
#   Phase 4 — Dashboard Deploy    (Coolify UI walkthrough guide)
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
    echo -e "  ${CYAN}Phase 3${RESET}  Dashboard Config    — Install sudoers + Coolify env var reference"
    echo -e "  ${CYAN}Phase 4${RESET}  Dashboard Deploy    — Coolify UI walkthrough guide"
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
    echo    "  This phase installs the sudoers configuration that lets the"
    echo    "  dashboard container read host security data (UFW, Fail2Ban, logs)."
    echo    "  It also prints the environment variables you will need to enter"
    echo    "  in the Coolify UI during Phase 4."
    echo

    if state_done "dashboard_config"; then
        warn "Dashboard was already configured in a previous run. Skipping."
        return 0
    fi

    # ── Sudoers ───────────────────────────────────────────────────────────────
    step "Installing sudoers configuration..."
    local sudoers_src="$DASHBOARD_DIR/sudoers-dashboard.conf"
    if [[ -f "$sudoers_src" ]]; then
        cp "$sudoers_src" /etc/sudoers.d/dashboard
        chmod 440 /etc/sudoers.d/dashboard
        if visudo -c &>/dev/null; then
            success "Sudoers configuration installed and validated."
            info "The dashboard container can now read UFW rules, Fail2Ban status, and system logs."
        else
            error "Sudoers file failed validation. Removing to prevent lockout."
            rm -f /etc/sudoers.d/dashboard
            warn "Install sudoers manually after fixing the file:"
            warn "  sudo cp $sudoers_src /etc/sudoers.d/dashboard && sudo chmod 440 /etc/sudoers.d/dashboard"
        fi
    else
        warn "sudoers-dashboard.conf not found at $sudoers_src"
        warn "Make sure you cloned the full repository. Skipping sudoers install."
    fi

    # ── Generate JWT secret ───────────────────────────────────────────────────
    echo
    step "Generating a JWT secret for Coolify..."
    local jwt_secret
    jwt_secret=$(openssl rand -hex 64)
    success "JWT secret generated."

    # ── Print Coolify env var reference ───────────────────────────────────────
    echo
    divider
    echo -e "\n  ${BOLD}${CYAN}Coolify Environment Variables${RESET}"
    echo    "  Copy these values into Coolify → your app → Environment Variables"
    echo    "  before triggering the first deployment."
    echo
    echo -e "  ${BOLD}Variable              Value${RESET}"
    echo    "  ──────────────────────────────────────────────────────────────"

    local detected_ip
    detected_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "<your-home-ip>")

    echo -e "  ${CYAN}DOMAIN${RESET}                <your-dashboard-domain>  (e.g. security.example.com)"
    echo -e "  ${CYAN}TRUSTED_IP${RESET}            ${detected_ip}  (your home/office IP — detected above)"
    echo -e "  ${CYAN}JWT_SECRET${RESET}            ${jwt_secret}"
    echo -e "  ${CYAN}SQLITE_DB_PATH${RESET}        /app/data/security-dashboard.db"
    echo -e "  ${CYAN}NODE_ENV${RESET}              production"
    echo
    echo -e "  ${DIM}TRUSTED_IP is used by Coolify's built-in IP allowlist (not a Caddyfile).${RESET}"
    echo -e "  ${DIM}SQLITE_DB_PATH must match the Coolify persistent volume mount path.${RESET}"
    echo -e "  ${DIM}The JWT_SECRET above was freshly generated — copy it now.${RESET}"
    divider
    echo
    echo -e "  ${BOLD}Admin account:${RESET}"
    echo    "  The dashboard has no default credentials. On first visit you will"
    echo    "  see a setup screen to create your admin username and password."
    echo

    save_state "dashboard_config"
    echo
    success "Phase 3 complete."
}

# =============================================================================
# PHASE 4 — DASHBOARD DEPLOY (COOLIFY)
# =============================================================================
phase_dashboard_deploy() {
    divider
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════╗"
    echo    "║  Phase 4 — Dashboard Deploy (Coolify)    ║"
    echo -e "╚══════════════════════════════════════════╝${RESET}"
    echo
    echo    "  Coolify is already installed on your VPS. This phase walks you"
    echo    "  through connecting the GitHub repository and triggering the first"
    echo    "  deployment entirely from the Coolify web UI."
    echo

    # ── Verify Coolify is running ─────────────────────────────────────────
    step "Verifying Coolify is reachable..."
    if curl -sf --max-time 5 http://localhost:8000 > /dev/null 2>&1 || \
       curl -sf --max-time 5 http://localhost:3000 > /dev/null 2>&1; then
        success "Coolify appears to be running."
    else
        warn "Could not reach Coolify on localhost:8000 or localhost:3000."
        info "Make sure Coolify is installed and running before proceeding."
        info "Install guide: https://coolify.io/docs/installation"
    fi

    # ── DNS check ─────────────────────────────────────────────────────────────
    echo
    step "Checking DNS (optional but recommended before deploying)..."
    local vps_ip
    vps_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "")
    if [[ -n "$vps_ip" ]]; then
        info "This VPS public IP: ${vps_ip}"
        info "Create a DNS A record pointing your dashboard domain to ${vps_ip}"
        info "before Coolify can provision a TLS certificate."
    fi

    # ── Step-by-step Coolify walkthrough ────────────────────────────────
    echo
    divider
    echo -e "\n  ${BOLD}${CYAN}Coolify Deployment Steps${RESET}"
    echo    "  Open the Coolify web UI and follow these steps:"
    echo
    echo -e "  ${BOLD}Step 1 — Create a new resource${RESET}"
    echo    "  Projects → your project → + New Resource"
    echo    "  → Public Repository"
    echo
    echo -e "  ${BOLD}Step 2 — Set the repository URL${RESET}"
    echo    "  Repository URL: https://github.com/andrzj/oracle-vps-security-suite"
    echo    "  Branch: main"
    echo    "  Build Pack: Dockerfile"
    echo
    echo -e "  ${BOLD}Step 3 — Set the build context${RESET}"
    echo    "  In the resource settings → Build:"
    echo    "  Dockerfile location: vps-security-dashboard/Dockerfile"
    echo    "  Build context:       vps-security-dashboard"
    echo
    echo -e "  ${BOLD}Step 4 — Add environment variables${RESET}"
    echo    "  In the resource settings → Environment Variables,"
    echo    "  add the values printed in Phase 3 above:"
    echo
    echo    "    DOMAIN              <your-dashboard-domain>"
    echo    "    TRUSTED_IP          <your-home-ip>"
    echo    "    JWT_SECRET          <generated-in-phase-3>"
    echo    "    SQLITE_DB_PATH      /app/data/security-dashboard.db"
    echo    "    NODE_ENV            production"
    echo
    echo -e "  ${BOLD}Step 5 — Configure persistent storage${RESET}"
    echo    "  In the resource settings → Storages:"
    echo    "  Add a volume mount:"
    echo    "    Source (host path): /opt/vps-dashboard-data"
    echo    "    Destination:        /app/data"
    echo    "  This persists the SQLite database across redeployments."
    echo
    echo -e "  ${BOLD}Step 6 — Configure the domain${RESET}"
    echo    "  In the resource settings → Domains:"
    echo    "  Add your dashboard domain (e.g. security.example.com)"
    echo    "  Enable HTTPS (Let's Encrypt) — Coolify handles this automatically."
    echo
    echo -e "  ${BOLD}Step 7 — (Optional) Restrict access by IP${RESET}"
    echo    "  In the resource settings → Network:"
    echo    "  Add your TRUSTED_IP to the IP Allowlist."
    echo    "  This blocks all other IPs at the Coolify proxy level."
    echo
    echo -e "  ${BOLD}Step 8 — Deploy${RESET}"
    echo    "  Click \"Deploy\" (or \"Redeploy\")."
    echo    "  Coolify will clone the repo, build the Docker image on this VPS,"
    echo    "  and start the container. Watch the build log in the Coolify UI."
    echo
    echo -e "  ${BOLD}Step 9 — First-run admin setup${RESET}"
    echo    "  Open https://<your-dashboard-domain> in your browser."
    echo    "  You will see a setup screen to create your admin account."
    echo    "  Credentials are stored in the SQLite database (bcrypt-hashed)."
    divider
    echo

    if confirm "  Have you completed the Coolify deployment steps above?"; then
        save_state "dashboard_deploy"
        success "Phase 4 complete. Dashboard deployment initiated via Coolify."
    else
        info "No problem — you can complete the Coolify steps at any time."
        info "Re-run main.sh to resume from where you left off."
        info "Full guide: $SCRIPT_DIR/vps-security-dashboard/DEPLOYMENT.md"
    fi
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================
final_summary() {
    local vps_ip
    vps_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "<your-vps-ip>")

    divider
    echo
    echo -e "${GREEN}${BOLD}  ✔  Host setup complete!${RESET}"
    echo
    echo -e "  ${BOLD}VPS IP:${RESET}          ${vps_ip}"
    echo -e "  ${BOLD}Install log:${RESET}     ${LOG_FILE}"
    echo
    divider
    echo
    echo -e "  ${BOLD}What was installed on this host:${RESET}"
    echo -e "  ${GREEN}✔${RESET}  System hardening (SSH, UFW, Fail2Ban, kernel, AIDE)"
    echo -e "  ${GREEN}✔${RESET}  Security monitoring service (systemd)"
    echo -e "  ${GREEN}✔${RESET}  Sudoers config for dashboard host access"
    echo
    echo -e "  ${BOLD}Next step:${RESET}"
    echo    "  Complete the Coolify deployment steps shown in Phase 4 above."
    echo    "  Full guide: $SCRIPT_DIR/vps-security-dashboard/DEPLOYMENT.md"
    echo
    divider
    echo
    echo -e "  ${BOLD}Quick reference (post-deployment):${RESET}"
    echo
    echo -e "  ${CYAN}# View dashboard container logs${RESET}"
    echo    "  # In Coolify UI → your resource → Logs tab"
    echo    "  # Or on the host:"
    echo    "  docker logs \$(docker ps -qf name=vps-security-dashboard) -f"
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
    echo -e "  ${CYAN}# Backup the SQLite database${RESET}"
    echo    "  cp /opt/vps-dashboard-data/security-dashboard.db \\"
    echo    "     /opt/vps-dashboard-data/security-dashboard-\$(date +%F).db"
    echo
    echo -e "  ${CYAN}# Redeploy after a git push${RESET}"
    echo    "  # Coolify auto-redeploys on push to main (if webhook is configured)"
    echo    "  # Or trigger manually: Coolify UI → your resource → Redeploy"
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
