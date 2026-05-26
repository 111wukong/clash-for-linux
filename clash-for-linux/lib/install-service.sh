#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Systemd service & profile installer
# ============================================================================

install_service() {
  step "Installing systemd service..."

  cat > "/etc/systemd/system/${SERVICE_NAME}" << SERVICEEOF
[Unit]
Description=Clash (mihomo) — Proxy Client
Documentation=https://wiki.metacubex.one
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${BIN_DIR}/mihomo -d ${CONF_DIR}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
LimitNPROC=512

# Security hardening
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE
NoNewPrivileges=false
ProtectSystem=strict
ProtectHome=true
PrivateDevices=false
PrivateTmp=true
ReadWritePaths=${INSTALL_DIR}
ProtectControlGroups=true
ProtectKernelModules=false
ProtectKernelTunables=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
RestrictRealtime=true
RestrictSUIDSGID=true
MemoryDenyWriteExecute=false

[Install]
WantedBy=multi-user.target
SERVICEEOF

  service_reload
  ok "Systemd service: ${SERVICE_NAME}"
}

install_update_timer() {
  step "Installing auto-update timer..."

  cat > "/etc/systemd/system/${TIMER_NAME}" << TIMEREOF
[Unit]
Description=Clash auto-update timer
Requires=${SERVICE_NAME}

[Timer]
OnCalendar=*-*-* 04:00:00
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

  cat > "/etc/systemd/system/clash-update.service" << UPDATEOF
[Unit]
Description=Clash update service (subscription + geo + core)
After=network-online.target

[Service]
Type=oneshot
ExecStart=${CLI_PATH} upgrade --quiet
UPDATEOF

  systemctl daemon-reload
  systemctl enable "$TIMER_NAME" &>/dev/null || true
  ok "Auto-update timer: daily at 04:00"
}

install_profile() {
  step "Installing shell profile..."

  cat > /etc/profile.d/clash.sh << 'PROFILEEOF'
# clash-for-linux — proxy toggle functions
# Usage: source /etc/profile.d/clash.sh

proxy_on() {
  export http_proxy="http://127.0.0.1:7890"
  export https_proxy="http://127.0.0.1:7890"
  export all_proxy="socks5://127.0.0.1:7890"
  export no_proxy="127.0.0.1,localhost,local,.local,.localdomain,.cluster.local,.svc,.internal"
  echo -e "\033[32m[✓] Proxy ON  — http://127.0.0.1:7890\033[0m"
}

proxy_off() {
  unset http_proxy https_proxy all_proxy no_proxy
  echo -e "\033[31m[✗] Proxy OFF\033[0m"
}

proxy_status() {
  local clash_state
  clash_state=$(systemctl is-active clash 2>/dev/null || echo "unknown")
  echo "Clash service: ${clash_state}"
  echo "http_proxy:    ${http_proxy:-(not set)}"
  echo "https_proxy:   ${https_proxy:-(not set)}"
  echo "all_proxy:     ${all_proxy:-(not set)}"

  # Quick connectivity test
  if [[ -n "${http_proxy:-}" ]]; then
    local ip
    ip=$(curl -s --max-time 3 --proxy http://127.0.0.1:7890 https://api.ipify.org 2>/dev/null || echo "timeout")
    echo "External IP:   ${ip}"
  fi
}

proxy_test() {
  echo "Testing proxy connectivity..."
  local result
  result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null)
  if [[ "$result" == "200" ]]; then
    echo -e "\033[32m[✓] Google: reachable (HTTP ${result})\033[0m"
  else
    echo -e "\033[31m[✗] Google: unreachable (HTTP ${result})\033[0m"
  fi

  result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://www.baidu.com 2>/dev/null)
  if [[ "$result" == "200" ]]; then
    echo -e "\033[32m[✓] Baidu:  reachable (HTTP ${result})\033[0m"
  else
    echo -e "\033[31m[✗] Baidu:  unreachable (HTTP ${result})\033[0m"
  fi
}
PROFILEEOF

  chmod +x /etc/profile.d/clash.sh
  ok "Profile: /etc/profile.d/clash.sh"
}
