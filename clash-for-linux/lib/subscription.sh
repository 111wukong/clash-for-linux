#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Subscription management
# ============================================================================

# --- Parse & merge subscription ---
subscription_update() {
  local url="$1" merge="${2:-true}"

  step "Fetching subscription..."

  local raw tmpfile
  raw=$(mktemp)
  tmpfile=$(mktemp)

  # Download with retry
  local retries=3
  while (( retries > 0 )); do
    if curl -fsSL --connect-timeout 10 --max-time 60 \
       -H "User-Agent: clash-meta/1.0" "$url" -o "$raw" 2>/dev/null; then
      break
    fi
    warn "Download attempt $(( 4 - retries )) failed, retrying..."
    (( retries-- ))
    sleep 2
  done

  if [[ $retries -eq 0 ]]; then
    rm -f "$raw" "$tmpfile"
    error "Failed to download subscription after 3 attempts."
  fi

  # Try base64 decode (subscriptions often base64-encoded)
  if ! grep -q "proxies:" "$raw" 2>/dev/null; then
    if ! base64 -d "$raw" > "$tmpfile" 2>/dev/null; then
      warn "Failed to decode subscription (may already be plaintext)"
      cp "$raw" "$tmpfile"
    fi
    mv "$tmpfile" "$raw"
  fi

  # Validate
  if ! grep -qE "proxies:|proxy-providers:|proxy-groups:" "$raw" 2>/dev/null; then
    rm -f "$raw"
    error "Subscription file does not contain valid proxy config."
  fi

  ok "Downloaded $(wc -l < "$raw") lines"

  if [[ "$merge" == "true" ]]; then
    step "Merging subscription..."
    python3 - "${CONF_DIR}/config.yaml" "$raw" << 'PYEOF'
import sys, yaml

with open(sys.argv[1]) as f:
    base = yaml.safe_load(f) or {}
with open(sys.argv[2]) as f:
    sub = yaml.safe_load(f) or {}

# Merge proxy-related keys from subscription
for key in ('proxies', 'proxy-groups', 'proxy-providers', 'rule-providers', 'rules'):
    if key in sub:
        base[key] = sub[key]

with open(sys.argv[1], 'w') as f:
    yaml.dump(base, f, allow_unicode=True, default_flow_style=False, sort_keys=False, width=120)
PYEOF
    ok "Merged subscription into config"
  else
    cp "$raw" "${CONF_DIR}/config.yaml"
    ok "Saved as new config (no merge)"
  fi

  rm -f "$raw"
}

# --- Auto-detect subscription URL from config/env ---
get_subscription_url() {
  local url
  # From env
  url="${CLASH_URL:-}"
  # From config
  if [[ -z "$url" && -f "${CONF_DIR}/config.yaml" ]]; then
    url=$(grep "subscription-url:" "${CONF_DIR}/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d "'\"" || true)
  fi
  # From .env file
  if [[ -z "$url" && -f "${INSTALL_DIR}/.env" ]]; then
    url=$(grep "^CLASH_URL=" "${INSTALL_DIR}/.env" 2>/dev/null | cut -d= -f2- | tr -d "'\" \t" || true)
  fi
  if [[ "$url" == "null" || "$url" == '""' || "$url" == "''" ]]; then url=""; fi
  echo "$url"
}

# --- Set subscription URL ---
subscription_set() {
  local url="$1"
  mkdir -p "$INSTALL_DIR"
  cat > "${INSTALL_DIR}/.env" <<< "CLASH_URL=\"${url}\""
  info "Subscription URL saved: ${url:0:50}..."
}

# --- Update Geo databases ---
update_geodata() {
  step "Updating Geo databases..."
  local files=(
    "geoip-lite.dat:geoip.dat"
    "geosite.dat:geosite.dat"
    "country.mmdb:Country.mmdb"
  )

  for pair in "${files[@]}"; do
    local remote="${pair%%:*}" local="${pair##*:}"
    if curl -fsSL --connect-timeout 10 --max-time 120 \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/${remote}" \
      -o "${CONF_DIR}/${local}.tmp" 2>/dev/null; then
      mv "${CONF_DIR}/${local}.tmp" "${CONF_DIR}/${local}"
      ok "Updated ${local}"
    else
      fail "Failed: ${local}"
    fi
  done
}
