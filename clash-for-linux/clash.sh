#!/usr/bin/env bash
# ============================================================================
# clash — Management CLI for clash-for-linux
# Usage: clash {start|stop|restart|status|update|logs|secret}
# ============================================================================
set -euo pipefail

INSTALL_DIR="/opt/clash"
CONF_DIR="${INSTALL_DIR}/conf"
BIN_DIR="${INSTALL_DIR}/bin"
LOG_DIR="${INSTALL_DIR}/logs"
SERVICE="clash.service"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This command requires root. Try: sudo clash $*"
    fi
}

cmd_start() {
    require_root
    systemctl start "$SERVICE"
    systemctl enable "$SERVICE" &>/dev/null || true
    info "Clash started."
}

cmd_stop() {
    require_root
    systemctl stop "$SERVICE"
    info "Clash stopped."
}

cmd_restart() {
    require_root
    systemctl restart "$SERVICE"
    info "Clash restarted."
}

cmd_status() {
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo -e "${GREEN}●${NC} Clash is running"
    else
        echo -e "${RED}●${NC} Clash is stopped"
    fi
    echo ""
    echo "  Service:  $(systemctl is-active "$SERVICE" 2>/dev/null || echo 'unknown')"
    echo "  Enabled:  $(systemctl is-enabled "$SERVICE" 2>/dev/null || echo 'unknown')"
    echo ""
    if command -v ss &>/dev/null; then
        echo "  Ports:"
        for port in 7890 7891 7892 7893 9090; do
            if ss -tlnp | grep -q ":$port "; then
                echo "    ${port} — listening"
            fi
        done
    fi
    echo ""
    echo "  Dashboard: http://localhost:9090"
    local secret
    secret=$(grep '^secret:' "${CONF_DIR}/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
    echo "  Secret:    ${secret:-N/A}"
}

cmd_update() {
    require_root
    info "Updating subscription..."
    local url
    url=$(grep 'subscription-url:' "${CONF_DIR}/config.yaml" 2>/dev/null | awk '{print $2}')
    if [[ -z "$url" || "$url" == "null" ]]; then
        warn "No subscription URL configured. Set 'subscription-url' in config.yaml"
        warn "or run with: clash update URL"
        exit 0
    fi

    local tmpfile
    tmpfile=$(mktemp)
    if curl -sL --connect-timeout 10 --max-time 30 "$url" -o "$tmpfile"; then
        if grep -q "proxies:" "$tmpfile" 2>/dev/null; then
            # Merge subscription into config
            local merge_script
            merge_script=$(mktemp)
            cat > "$merge_script" << 'PYEOF'
import sys, yaml
with open('/opt/clash/conf/config.yaml') as f:
    base = yaml.safe_load(f) or {}
with open(sys.argv[1]) as f:
    sub = yaml.safe_load(f) or {}
for key in ['proxies', 'proxy-groups', 'rules', 'proxy-providers']:
    if key in sub:
        base[key] = sub[key]
with open('/opt/clash/conf/config.yaml', 'w') as f:
    yaml.dump(base, f, allow_unicode=True, default_flow_style=False)
PYEOF

            if python3 "$merge_script" "$tmpfile" 2>/dev/null; then
                info "Subscription merged. Restarting..."
                systemctl restart "$SERVICE"
                info "Update complete."
            else
                warn "Merge failed (python3/yaml required). Using raw subscription."
                cp "$tmpfile" "${CONF_DIR}/config.yaml"
                systemctl restart "$SERVICE"
            fi
            rm -f "$merge_script"
        else
            cp "$tmpfile" "${CONF_DIR}/config.yaml"
            info "Subscription saved. Restarting..."
            systemctl restart "$SERVICE"
            info "Update complete."
        fi
    else
        error "Failed to download subscription: $url"
    fi
    rm -f "$tmpfile"
}

cmd_logs() {
    if [[ $# -gt 0 && "$1" == "-f" || "$1" == "--follow" ]]; then
        shift
        if [[ -f "${LOG_DIR}/clash.log" ]]; then
            tail -f "${LOG_DIR}/clash.log"
        else
            journalctl -fu "$SERVICE"
        fi
    else
        if [[ -f "${LOG_DIR}/clash.log" ]]; then
            tail -n 50 "${LOG_DIR}/clash.log"
        else
            journalctl -u "$SERVICE" --no-pager -n 50
        fi
    fi
}

cmd_secret() {
    local secret
    secret=$(grep '^secret:' "${CONF_DIR}/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
    if [[ -n "$secret" ]]; then
        echo "$secret"
    else
        error "Secret not found in config.yaml"
    fi
}

cmd_doctor() {
    echo "=== clash-for-linux Diagnostics ==="
    echo ""

    # Service
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Service: running"
    else
        echo -e "${RED}[✗]${NC} Service: not running"
    fi

    # Binary
    if [[ -x "${BIN_DIR}/mihomo" ]]; then
        local ver
        ver=$("${BIN_DIR}/mihomo" -v 2>&1 | head -1)
        echo -e "${GREEN}[✓]${NC} Core: ${ver}"
    else
        echo -e "${RED}[✗]${NC} Core: not found at ${BIN_DIR}/mihomo"
    fi

    # Config
    if [[ -f "${CONF_DIR}/config.yaml" ]]; then
        echo -e "${GREEN}[✓]${NC} Config: exists"
    else
        echo -e "${RED}[✗]${NC} Config: missing at ${CONF_DIR}/config.yaml"
    fi

    # Dashboard
    if [[ -d "${INSTALL_DIR}/dashboard" ]] && ls "${INSTALL_DIR}/dashboard/"*.html &>/dev/null 2>&1; then
        echo -e "${GREEN}[✓]${NC} Dashboard: installed"
    else
        echo -e "${YELLOW}[!]${NC} Dashboard: not installed (will use built-in)"
    fi

    # Geo databases
    for db in geoip.dat geosite.dat Country.mmdb; do
        if [[ -f "${CONF_DIR}/${db}" ]]; then
            echo -e "${GREEN}[✓]${NC} ${db}: present"
        else
            echo -e "${YELLOW}[!]${NC} ${db}: missing"
        fi
    done

    # Ports
    for port in 7890 7891 9090; do
        if ss -tlnp | grep -q ":$port "; then
            echo -e "${GREEN}[✓]${NC} Port ${port}: listening"
        else
            echo -e "${YELLOW}[!]${NC} Port ${port}: not listening"
        fi
    done

    # Environment
    if [[ -n "${http_proxy:-}" ]]; then
        echo -e "${GREEN}[✓]${NC} http_proxy: set (${http_proxy})"
    else
        echo -e "${YELLOW}[!]${NC} http_proxy: not set (run proxy_on)"
    fi
}

# --- Main dispatch ---
main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        start)   cmd_start ;;
        stop)    cmd_stop ;;
        restart) cmd_restart ;;
        status)  cmd_status ;;
        update)  cmd_update "$@" ;;
        logs)    cmd_logs "$@" ;;
        secret)  cmd_secret ;;
        doctor)  cmd_doctor ;;
        help|--help|-h)
            echo "Usage: clash {command}"
            echo ""
            echo "Commands:"
            echo "  start       Start the Clash service"
            echo "  stop        Stop the Clash service"
            echo "  restart     Restart the Clash service"
            echo "  status      Show service status and port info"
            echo "  update      Update subscription and restart"
            echo "  logs        Show recent logs (use -f to follow)"
            echo "  secret      Print the dashboard secret"
            echo "  doctor      Run diagnostic checks"
            echo "  help        Show this help"
            ;;
        *)
            error "Unknown command: $cmd. Use: clash help"
            ;;
    esac
}

main "$@"
