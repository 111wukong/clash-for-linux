#!/usr/bin/env bash
# ============================================================================
# clash-for-linux v2 — One-step installer
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/config-gen.sh"
source "${LIB_DIR}/install-core.sh"
source "${LIB_DIR}/install-dashboard.sh"
source "${LIB_DIR}/install-geo.sh"
source "${LIB_DIR}/install-service.sh"
source "${LIB_DIR}/subscription.sh"

# ============================================================================
# Pre-flight
# ============================================================================

preflight() {
  if [[ ${EUID:-0} -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash install.sh"
  fi

  local missing=()
  for cmd in curl tar gzip systemctl openssl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    warn "Missing dependencies: ${missing[*]}"
    local distro
    distro=$(detect_distro)
    case "$distro" in
      ubuntu|debian)
        echo "  Install with: apt install ${missing[*]}" ;;
      centos|rhel|fedora)
        echo "  Install with: yum install ${missing[*]}" ;;
      arch|manjaro)
        echo "  Install with: pacman -S ${missing[*]}" ;;
      *)
        echo "  Please install them manually." ;;
    esac
    exit 1
  fi
}

prompt_sub_url() {
  echo ""
  echo -e "${CYAN}Do you have a subscription URL?${NC}"
  echo "  (Leave blank to skip — you can set it later with: sudo clash sub set URL)"
  echo ""
  read -r -p "  Subscription URL: " sub_url

  if [[ -n "$sub_url" ]]; then
    echo "$sub_url" > "${INSTALL_DIR}/.env"
    echo "CLASH_URL=\"${sub_url}\"" > "${INSTALL_DIR}/.env"
    info "Subscription URL saved."
  fi
}

prompt_mode() {
  echo ""
  echo -e "${CYAN}Select proxy mode:${NC}"
  echo "  1) tun       — TUN transparent proxy (recommended, best compatibility)"
  echo "  2) fake-ip   — Fake-IP DNS enhancing (lightweight, no VPN/TUN)"
  echo "  3) redirect  — iptables redirect (legacy, requires iptables)"
  echo ""
  read -r -p "  Choice [1-3] (default: 1): " choice

  case "${choice:-1}" in
    1) MODE="tun" ;;
    2) MODE="fake-ip" ;;
    3) MODE="redirect" ;;
    *) MODE="tun" ;;
  esac
  info "Mode: $MODE"
}

# ============================================================================
# Main
# ============================================================================

main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║        clash-for-linux v2 — Installer            ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""

  preflight

  local arch
  arch=$(detect_arch)
  info "Architecture: ${arch} ($(uname -m))"
  info "Distro:       $(detect_distro)"

  # Interactive prompts
  prompt_mode
  prompt_sub_url

  # Create directories
  step "Creating directories..."
  mkdir -p "$BIN_DIR" "$CONF_DIR" "$LOG_DIR" "$DASHBOARD_DIR" "$BACKUP_DIR" "$RULES_DIR" "$PROVIDERS_DIR"
  ok "Directory structure created"

  # Install components
  install_core "$arch"
  install_dashboard
  install_geodata
  install_rule_providers

  # Generate config
  step "Generating config (mode: $MODE)..."
  local secret
  secret=$(generate_config "" "$MODE")
  ok "Config generated"

  # Install service and profile
  install_service
  install_update_timer
  install_profile

  # Install CLI symlink
  cp "${SCRIPT_DIR}/clash" "$CLI_PATH" 2>/dev/null || \
    ln -sf "${SCRIPT_DIR}/clash" "$CLI_PATH" 2>/dev/null || true
  chmod +x "$CLI_PATH" 2>/dev/null || true
  ok "CLI installed: ${CLI_PATH}"

  # Update subscription if provided
  local sub_url
  sub_url=$(get_subscription_url 2>/dev/null || true)
  if [[ -n "$sub_url" ]]; then
    subscription_update "$sub_url"
  fi

  # Start service
  step "Starting service..."
  systemctl enable "$SERVICE_NAME" &>/dev/null || true
  systemctl start "$SERVICE_NAME" 2>/dev/null || true

  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    ok "Service started successfully"
  else
    warn "Service failed to start. Check: sudo clash logs"
  fi

  # Done
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║         Installation Complete!                   ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}Quick Start:${NC}"
  echo ""
  echo "  source /etc/profile.d/clash.sh   # Load proxy functions"
  echo "  proxy_on                          # Enable proxy"
  echo "  proxy_test                        # Test connectivity"
  echo ""
  echo -e "${GREEN}Management:${NC}"
  echo ""
  echo "  sudo clash status          Service status & ports"
  echo "  sudo clash doctor          Full diagnostic"
  echo "  sudo clash update          Update subscription"
  echo "  sudo clash logs -f         Follow logs"
  echo ""
  echo -e "${GREEN}Dashboard:${NC}"
  echo ""
  echo "  URL:    http://localhost:9090"
  echo "  Secret: ${secret}"
  echo ""
  echo "  Mode:   ${MODE}"
  echo "  Config: ${CONF_DIR}/config.yaml"
  echo ""
}

main "$@"
