#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Common utilities & constants
# ============================================================================
set -euo pipefail

# --- Colour helpers ---
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# --- Paths (overridable via env) ---
INSTALL_DIR="${CLASH_INSTALL_DIR:-/opt/clash}"
BIN_DIR="${INSTALL_DIR}/bin"
CONF_DIR="${INSTALL_DIR}/conf"
LOG_DIR="${INSTALL_DIR}/logs"
DASHBOARD_DIR="${INSTALL_DIR}/dashboard"
BACKUP_DIR="${INSTALL_DIR}/backups"
RULES_DIR="${CONF_DIR}/rules"
PROVIDERS_DIR="${CONF_DIR}/providers"

SERVICE_NAME="clash.service"
TIMER_NAME="clash-update.timer"
CLI_PATH="/usr/local/bin/clash"

# --- MIHOMO / Dashboard URLs ---
MIHOMO_REPO="MetaCubeX/mihomo"
METACUBEXD_REPO="MetaCubeX/metacubexd"
RULES_DAT_REPO="MetaCubeX/meta-rules-dat"

# --- Logging ---
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()  { echo -e "${BLUE}[●]${NC} $*"; }
ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; }

# --- Root check ---
require_root() {
  if [[ ${EUID:-0} -ne 0 ]]; then
    error "This command requires root. Run: sudo clash $*"
  fi
}

# --- Detect CPU arch ---
detect_arch() {
  local a
  a=$(uname -m)
  case "$a" in
    x86_64|amd64)   echo "amd64"    ;;
    aarch64|arm64)  echo "arm64"    ;;
    armv7l|armhf)   echo "armv7"    ;;
    i386|i686)      echo "386"      ;;
    riscv64)        echo "riscv64"  ;;
    *) error "Unsupported CPU: $a"  ;;
  esac
}

# --- Detect Linux distro ---
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  elif command -v lsb_release &>/dev/null; then
    lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]'
  else
    echo "unknown"
  fi
}

# --- GitHub latest release URL ---
github_latest_url() {
  local repo="$1" match="$2"
  curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep "browser_download_url" \
    | grep "${match}" \
    | grep -v "\.pdb\." \
    | head -1 \
    | cut -d'"' -f4
}

# --- Verify config YAML syntax ---
verify_yaml() {
  local f="$1"
  python3 -c "import yaml; yaml.safe_load(open('${f}'))" 2>/dev/null
}

# --- Service helpers ---
service_running() { systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; }
service_enabled() { systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; }
service_restart() { systemctl restart "$SERVICE_NAME"; }
service_reload() { systemctl daemon-reload; }

# --- Timestamp ---
now_ts() { date '+%Y-%m%d-%H%M%S'; }

# --- Network helpers ---
port_listening() {
  ss -tlnp 2>/dev/null | grep -q ":$1 " || netstat -tlnp 2>/dev/null | grep -q ":$1 "
}
