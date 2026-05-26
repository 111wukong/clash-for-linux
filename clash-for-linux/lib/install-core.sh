#!/usr/bin/env bash
# ============================================================================
# clash-for-linux — Core binary install
# ============================================================================

install_core() {
  local arch="$1"
  step "Installing mihomo core (${arch})..."

  local url
  url=$(github_latest_url "$MIHOMO_REPO" "mihomo-linux-${arch}")
  if [[ -z "$url" ]]; then
    # Fallback: companion mode
    url=$(github_latest_url "$MIHOMO_REPO" "mihomo-linux-${arch}-compatible")
  fi
  [[ -z "$url" ]] && error "No release found for ${arch}. Check https://github.com/${MIHOMO_REPO}/releases"

  local filename
  filename=$(basename "$url")
  info "Downloading $filename"
  curl -fsSL --connect-timeout 10 --max-time 120 "$url" -o "/tmp/${filename}"

  mkdir -p "$BIN_DIR"
  local old_size=0 new_size
  [[ -f "${BIN_DIR}/mihomo" ]] && old_size=$(stat -c%s "${BIN_DIR}/mihomo" 2>/dev/null || stat -f%z "${BIN_DIR}/mihomo" 2>/dev/null || echo 0)

  # Extract archive
  if [[ "$filename" == *.gz ]] || [[ "$filename" == *.tgz ]]; then
    tar -xzf "/tmp/${filename}" -C "$BIN_DIR/" --strip-components=1 2>/dev/null || \
    tar -xzf "/tmp/${filename}" -C "$BIN_DIR/" 2>/dev/null
  elif [[ "$filename" == *.zip ]]; then
    unzip -qo "/tmp/${filename}" -d "$BIN_DIR/" 2>/dev/null
  else
    mv "/tmp/${filename}" "${BIN_DIR}/mihomo" 2>/dev/null
  fi

  # Locate the binary
  if [[ ! -f "${BIN_DIR}/mihomo" ]]; then
    local found
    found=$(find "$BIN_DIR" -type f -name "mihomo*" -not -name "*.pdb" 2>/dev/null | head -1)
    [[ -n "$found" ]] && mv "$found" "${BIN_DIR}/mihomo"
  fi

  [[ ! -f "${BIN_DIR}/mihomo" ]] && error "Failed to locate mihomo binary after extraction."

  chmod +x "${BIN_DIR}/mihomo"
  new_size=$(stat -c%s "${BIN_DIR}/mihomo" 2>/dev/null || stat -f%z "${BIN_DIR}/mihomo" 2>/dev/null || echo 0)

  local ver
  ver=$("${BIN_DIR}/mihomo" -v 2>&1 | head -1 || echo "unknown")
  ok "Core: $ver ($(( new_size / 1024 / 1024 ))MB)"

  rm -f "/tmp/${filename}"
}

update_core() {
  require_root
  local arch arch_str
  arch=$(detect_arch)
  arch_str=$(uname -m)

  step "Checking for core updates..."
  if [[ ! -f "${BIN_DIR}/mihomo" ]]; then
    warn "No existing core found. Installing fresh."
    install_core "$arch"
    return
  fi

  local latest_version current_version
  latest_version=$(curl -sL "https://api.github.com/repos/${MIHOMO_REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  current_version=$("${BIN_DIR}/mihomo" -v 2>&1 | head -1 | grep -oP 'v?\d+\.\d+\.\d+' || echo "unknown")

  if [[ -z "$latest_version" ]]; then
    warn "Could not check latest version. Forcing download..."
    install_core "$arch"
  elif [[ "$current_version" == "$latest_version" ]] || [[ "v${current_version}" == "$latest_version" ]]; then
    info "Core is up to date ($current_version)."
  else
    info "Update available: $current_version → $latest_version"
    install_core "$arch"
  fi
}
