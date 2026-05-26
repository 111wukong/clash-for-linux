#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Dashboard install
# ============================================================================

install_dashboard() {
  step "Installing management dashboard..."

  local dash_url
  dash_url=$(curl -sL "https://api.github.com/repos/${METACUBEXD_REPO}/releases/latest" \
    | grep "browser_download_url" \
    | grep -i "dist" \
    | grep -E "\.(tgz|tar\.gz|zip)$" \
    | head -1 \
    | cut -d'"' -f4)

  if [[ -z "$dash_url" ]]; then
    # Try yacd as fallback
    dash_url=$(curl -sL "https://api.github.com/repos/MetaCubeX/Yacd-meta/releases/latest" \
      | grep "browser_download_url" \
      | grep -i "dist" \
      | grep -E "\.(tgz|tar\.gz)$" \
      | head -1 \
      | cut -d'"' -f4)
  fi

  if [[ -z "$dash_url" ]]; then
    warn "No dashboard found. Using mihomo built-in UI."
    return
  fi

  rm -rf "$DASHBOARD_DIR"
  mkdir -p "$DASHBOARD_DIR"

  local ext="${dash_url##*.}"
  if [[ "$ext" == "zip" ]]; then
    curl -fsSL "$dash_url" -o "/tmp/clash-dash.zip"
    unzip -qo "/tmp/clash-dash.zip" -d "$DASHBOARD_DIR" 2>/dev/null
    rm -f "/tmp/clash-dash.zip"
  else
    curl -fsSL "$dash_url" -o "/tmp/clash-dash.tgz"
    tar -xzf "/tmp/clash-dash.tgz" -C "$DASHBOARD_DIR" 2>/dev/null
    rm -f "/tmp/clash-dash.tgz"
  fi

  # Find index.html (may be nested)
  if [[ ! -f "${DASHBOARD_DIR}/index.html" ]]; then
    local found
    found=$(find "$DASHBOARD_DIR" -name "index.html" -type f 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      local parent
      parent=$(dirname "$found")
      if [[ "$parent" != "$DASHBOARD_DIR" ]]; then
        mv "$parent"/* "$DASHBOARD_DIR/" 2>/dev/null
        rm -rf "$parent"
      fi
    fi
  fi

  local file_count
  file_count=$(find "$DASHBOARD_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  ok "Dashboard: metacubexd ($file_count files)"
}
