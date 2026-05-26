#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Enhanced diagnostics
# ============================================================================

run_doctor() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║    clash-for-linux — Diagnostics         ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""

  local issues=0

  # ── System ──
  echo -e "${CYAN}── System${NC}"
  echo "  OS:       $(uname -o || uname -s) $(uname -m)"
  echo "  Kernel:   $(uname -r)"
  echo "  Distro:   $(detect_distro)"
  echo "  Arch:     $(detect_arch)"

  # ── Service ──
  echo -e "\n${CYAN}── Service${NC}"
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "  Status:   ${GREEN}running${NC}"
  else
    echo -e "  Status:   ${RED}stopped${NC}"
    ((issues++))
  fi

  local enabled_str
  enabled_str=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "unknown")
  if [[ "$enabled_str" == "enabled" ]]; then
    echo -e "  Auto-boot:${GREEN}yes${NC}"
  else
    echo -e "  Auto-boot:${YELLOW}no${NC}"
  fi

  # ── Core ──
  echo -e "\n${CYAN}── Core (mihomo)${NC}"
  if [[ -x "${BIN_DIR}/mihomo" ]]; then
    local ver size
    ver=$("${BIN_DIR}/mihomo" -v 2>&1 | head -1)
    size=$(du -h "${BIN_DIR}/mihomo" 2>/dev/null | cut -f1)
    echo -e "  Binary:   ${GREEN}$ver${NC}"
    echo "  Size:     $size"
  else
    echo -e "  Binary:   ${RED}missing${NC}"
    ((issues++))
  fi

  # ── Config ──
  echo -e "\n${CYAN}── Configuration${NC}"
  if [[ -f "${CONF_DIR}/config.yaml" ]]; then
    echo -e "  Config:   ${GREEN}exists${NC}"
    if verify_yaml "${CONF_DIR}/config.yaml"; then
      echo -e "  Syntax:   ${GREEN}valid${NC}"
    else
      echo -e "  Syntax:   ${RED}invalid YAML${NC}"
      ((issues++))
    fi

    # Check subscription URL
    local sub_url
    sub_url=$(get_subscription_url 2>/dev/null || true)
    if [[ -n "$sub_url" ]]; then
      echo -e "  Sub URL:  ${GREEN}set${NC} (${sub_url:0:60}...)"
    else
      echo -e "  Sub URL:  ${YELLOW}not set${NC}"
    fi

    # Check secret
    local secret
    secret=$(grep -oP 'secret:\s*"?\K[^"\n]+' "${CONF_DIR}/config.yaml" 2>/dev/null | head -1 | tr -d "'" || true)
    echo "  Secret:   ${secret:-(not set)}"
  else
    echo -e "  Config:   ${RED}missing${NC}"
    ((issues++))
  fi

  # ── Dashboard ──
  echo -e "\n${CYAN}── Dashboard${NC}"
  if [[ -f "${DASHBOARD_DIR}/index.html" ]] || ls "${DASHBOARD_DIR}/"*.html &>/dev/null 2>&1; then
    echo -e "  Dashboard:${GREEN}installed${NC}"
  else
    echo -e "  Dashboard:${YELLOW}not installed (using built-in API UI)${NC}"
  fi

  # ── Geo Databases ──
  echo -e "\n${CYAN}── Geo Databases${NC}"
  for db in geoip.dat geosite.dat Country.mmdb; do
    if [[ -f "${CONF_DIR}/${db}" ]]; then
      local fsize
      fsize=$(du -h "${CONF_DIR}/${db}" 2>/dev/null | cut -f1)
      echo -e "  ${db}  ${GREEN}${fsize}${NC}"
    else
      echo -e "  ${db}  ${RED}missing${NC}"
      ((issues++))
    fi
  done

  # ── Ports ──
  echo -e "\n${CYAN}── Network${NC}"
  local portmap=(
    "7890:mixed"
    "7891:socks"
    "7892:redir"
    "9090:api"
  )
  for item in "${portmap[@]}"; do
    local port="${item%%:*}" label="${item##*:}"
    if port_listening "$port"; then
      echo -e "  :${port}    ${GREEN}listening${NC} (${label})"
    else
      echo -e "  :${port}    ${YELLOW}not listening${NC} (${label})"
    fi
  done

  # Proxy env
  if [[ -n "${http_proxy:-}" ]]; then
    echo -e "  ENV proxy: ${GREEN}${http_proxy}${NC}"
  else
    echo -e "  ENV proxy: ${YELLOW}not set${NC}"
  fi

  # ── Subscription ──
  echo -e "\n${CYAN}── Subscription Status${NC}"
  local sub_url
  sub_url=$(get_subscription_url 2>/dev/null || true)
  if [[ -n "$sub_url" ]]; then
    echo "  URL:    $sub_url"
    # Quick connectivity check to subscription endpoint
    local sub_code
    sub_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$sub_url" 2>/dev/null || echo "timeout")
    if [[ "$sub_code" == "200" ]]; then
      echo -e "  Reach:  ${GREEN}accessible${NC} (HTTP 200)"
    else
      echo -e "  Reach:  ${YELLOW}HTTP ${sub_code}${NC}"
    fi
  else
    echo -e "  $ ${YELLOW}No subscription configured${NC}"
    echo "    Set: sudo clash sub set YOUR_URL"
  fi

  # ── Usage ──
  echo -e "\n${CYAN}── Resource Usage${NC}"
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    local pid cpu mem
    pid=$(systemctl show --property=MainPID --value "$SERVICE_NAME" 2>/dev/null || true)
    if [[ -n "$pid" && "$pid" != "0" ]]; then
      {
        read -r _ cpu mem _
      } < <(ps -p "$pid" -o pid= -o %cpu= -o %mem= 2>/dev/null || true)
      echo "  PID:     $pid"
      echo "  CPU:     ${cpu:-?}%"
      echo "  MEM:     ${mem:-?}%"
    fi
  fi

  # ── Auto-update ──
  echo -e "\n${CYAN}── Auto-update${NC}"
  if systemctl is-active --quiet "$TIMER_NAME" 2>/dev/null; then
    echo -e "  Timer:   ${GREEN}active${NC}"
  else
    echo -e "  Timer:   ${YELLOW}inactive${NC}"
    echo "    Enable: sudo clash timer enable"
  fi

  # ── Summary ──
  echo -e "\n${BOLD}──────────────────────────────────────────${NC}"
  if (( issues == 0 )); then
    echo -e "${GREEN}All checks passed. ✓${NC}"
  else
    echo -e "${RED}${issues} issue(s) found.${NC}"
    echo "  Run: sudo clash doctor --fix"
  fi
  echo ""
}
