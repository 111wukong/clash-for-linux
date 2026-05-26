#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Network & backup helpers
# ============================================================================

# --- Configure firewall redirect rules ---
setup_firewall() {
  local action="${1:-enable}"
  step "Configuring iptables redirect..."

  if ! command -v iptables &>/dev/null; then
    warn "iptables not found. Skipping firewall setup."
    return
  fi

  if [[ "$action" == "disable" ]]; then
    iptables -t nat -D OUTPUT -p tcp -j REDIRECT --to-port 7892 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp -j REDIRECT --to-port 7892 2>/dev/null || true
    ok "Firewall redirect rules removed"
  else
    iptables -t nat -A OUTPUT -p tcp --dport ! 7890 -j REDIRECT --to-port 7892 2>/dev/null || true
    ok "Firewall redirect rules applied"
  fi
}

# --- Backup config ---
backup_config() {
  require_root
  mkdir -p "$BACKUP_DIR"

  local ts backup_file
  ts=$(now_ts)
  backup_file="${BACKUP_DIR}/backup-${ts}.tar.gz"

  step "Creating backup..."
  tar -czf "$backup_file" -C "$CONF_DIR" . 2>/dev/null

  local size
  size=$(du -h "$backup_file" 2>/dev/null | cut -f1)
  info "Backup saved: ${backup_file} (${size})"

  # Keep last 10, delete older
  local count
  count=$(ls -1t "${BACKUP_DIR}"/backup-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
  if (( count > 10 )); then
    ls -1t "${BACKUP_DIR}"/backup-*.tar.gz | tail -n +11 | xargs rm -f 2>/dev/null
    ok "Pruned old backups (keeping last 10)"
  fi
}

# --- Restore config ---
restore_config() {
  require_root
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    # List available backups
    echo "Available backups:"
    echo ""
    if [[ -d "$BACKUP_DIR" ]] && ls "${BACKUP_DIR}"/backup-*.tar.gz &>/dev/null 2>&1; then
      ls -1t "${BACKUP_DIR}"/backup-*.tar.gz | while read -r f; do
        local ts size
        ts=$(echo "$(basename "$f")" | sed 's/backup-//;s/.tar.gz//')
        size=$(du -h "$f" 2>/dev/null | cut -f1)
        echo "  ${ts}  (${size})"
      done
    else
      echo "  (no backups found)"
    fi
    echo ""
    echo "To restore: sudo clash backup restore BACKUP_FILENAME"
    return
  fi

  local backup_file
  if [[ -f "$target" ]]; then
    backup_file="$target"
  elif [[ -f "${BACKUP_DIR}/backup-${target}.tar.gz" ]]; then
    backup_file="${BACKUP_DIR}/backup-${target}.tar.gz"
  elif [[ -f "${BACKUP_DIR}/${target}" ]]; then
    backup_file="${BACKUP_DIR}/${target}"
  else
    error "Backup not found: $target"
  fi

  step "Restoring from: $backup_file"

  # Stop service first
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true

  # Backup current config first
  local current_backup="${BACKUP_DIR}/pre-restore-$(now_ts).tar.gz"
  tar -czf "$current_backup" -C "$CONF_DIR" . 2>/dev/null
  info "Current config saved: $current_backup"

  # Restore
  rm -rf "${CONF_DIR:?}"/*
  tar -xzf "$backup_file" -C "$CONF_DIR" 2>/dev/null

  systemctl start "$SERVICE_NAME" 2>/dev/null || true
  info "Config restored. Service restarted."
}

# --- Traffic stats ---
show_metrics() {
  local sub_url
  sub_url=$(get_subscription_url 2>/dev/null || true)

  echo ""
  echo -e "${BOLD}── Traffic Overview${NC}"
  echo ""

  if [[ -f "${LOG_DIR}/clash.log" ]]; then
    local log_size lines
    log_size=$(du -h "${LOG_DIR}/clash.log" 2>/dev/null | cut -f1 || echo "0")
    lines=$(wc -l < "${LOG_DIR}/clash.log" 2>/dev/null || echo "0")
    echo "  Log size:   ${log_size} (${lines} lines)"
  fi

  # Try API
  local secret
  secret=$(grep -oP 'secret:\s*"?\K[^"\n]+' "${CONF_DIR}/config.yaml" 2>/dev/null | head -1 | tr -d "'" || echo "")

  echo ""
  echo -e "${BOLD}── Connection State${NC}"
  echo ""

  if port_listening "9090"; then
    if [[ -n "$secret" ]]; then
      local resp
      resp=$(curl -s --max-time 3 -H "Authorization: Bearer ${secret}" \
        "http://127.0.0.1:9090/connections" 2>/dev/null || true)
      if [[ -n "$resp" ]]; then
        local upload download conn_count
        upload=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('uploadTotal',0))" 2>/dev/null || echo "0")
        download=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('downloadTotal',0))" 2>/dev/null || echo "0")
        conn_count=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('connections',[])))" 2>/dev/null || echo "0")

        local uf df
        if command -v numfmt &>/dev/null; then
          uf=$(numfmt --to=iec "$upload" 2>/dev/null || echo "${upload}B")
          df=$(numfmt --to=iec "$download" 2>/dev/null || echo "${download}B")
        else
          uf="${upload}B"
          df="${download}B"
        fi

        echo "  Upload:     ${uf}"
        echo "  Download:   ${df}"
        echo "  Connections:${conn_count}"
      else
        warn "Could not fetch connection state"
      fi
    else
      warn "No API secret configured"
    fi
  else
    warn "API not accessible (port 9090)"
  fi

  echo ""
}
