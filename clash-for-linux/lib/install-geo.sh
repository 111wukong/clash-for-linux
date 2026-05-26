#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Geo database installer
# ============================================================================

install_geodata() {
  step "Downloading Geo databases..."
  local files=(
    "geoip-lite.dat:geoip.dat"
    "geosite.dat:geosite.dat"
    "country.mmdb:Country.mmdb"
  )

  for pair in "${files[@]}"; do
    local remote="${pair%%:*}" local="${pair##*:}"
    if curl -fsSL --connect-timeout 10 --max-time 120 \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/${remote}" \
      -o "${CONF_DIR}/${local}" 2>/dev/null; then
      ok "${local}"
    else
      fail "${local}"
    fi
  done
}

install_rule_providers() {
  step "Downloading rule providers..."
  mkdir -p "$RULES_DIR"

  local rules=(
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt:reject.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt:proxy.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt:direct.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt:gfw.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt:cncidr.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt:lancidr.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt:apple.yaml"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt:google.yaml"
  )

  local count=0
  for pair in "${rules[@]}"; do
    local url="${pair%%:*}" name="${pair##*:}"
    if curl -fsSL --connect-timeout 5 --max-time 30 "$url" -o "${RULES_DIR}/${name}" 2>/dev/null; then
      ((count++))
    fi
  done
  ok "Downloaded ${count}/8 rule sets"
}
