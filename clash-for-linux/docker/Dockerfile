# ============================================================================
# clash-for-linux — Docker image
# ============================================================================
FROM alpine:3.20

LABEL org.opencontainers.image.title="clash-for-linux"
LABEL org.opencontainers.image.description="Modern Clash Meta proxy (mihomo)"
LABEL org.opencontainers.image.source="https://github.com/111wukong/clash-for-linux"

# Install mihomo + dependencies
RUN set -ex && \
    apk add --no-cache curl ca-certificates tzdata && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64)  MARCH="amd64" ;; \
      aarch64) MARCH="arm64" ;; \
      armv7l)  MARCH="armv7" ;; \
      *) echo "Unsupported: $ARCH"; exit 1 ;; \
    esac && \
    MIHOMO_URL=$(curl -sL "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | \
      grep "browser_download_url" | grep "mihomo-linux-${MARCH}" | grep -v "\.pdb\." | grep -v "compatible" | head -1 | cut -d'"' -f4) && \
    curl -sL "$MIHOMO_URL" -o /tmp/mihomo.tgz && \
    tar -xzf /tmp/mihomo.tgz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/mihomo && \
    rm -f /tmp/mihomo.tgz && \
    mkdir -p /etc/clash /opt/clash/logs

# Download dashboard
RUN DASH_URL=$(curl -sL "https://api.github.com/repos/MetaCubeX/metacubexd/releases/latest" | \
      grep "browser_download_url" | grep -i dist | grep -E "\.(tgz|tar\.gz)$" | head -1 | cut -d'"' -f4) && \
    curl -sL "$DASH_URL" -o /tmp/dash.tgz && \
    mkdir -p /opt/clash/dashboard && \
    tar -xzf /tmp/dash.tgz -C /opt/clash/dashboard/ && \
    rm -f /tmp/dash.tgz

# Download Geo databases
RUN for f in geoip-lite.dat geosite.dat country.mmdb; do \
      curl -sL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/${f}" \
        -o "/etc/clash/${f#*-}" 2>/dev/null || true; \
    done && \
    mv /etc/clash/lite.dat /etc/clash/geoip.dat 2>/dev/null || true

# Default config
COPY <<-"CFG" /etc/clash/config.yaml
mixed-port: 7890
allow-lan: true
bind-address: "0.0.0.0"
log-level: info
external-controller: 0.0.0.0:9090
secret: ""
external-ui: /opt/clash/dashboard
mode: rule
geodata-mode: true
profile:
  store-selected: true
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  default-nameserver:
    - 223.5.5.5
    - 114.114.114.114
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.1.1.1/dns-query
  fallback-filter:
    geoip: true
rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
CFG

EXPOSE 7890 9090

VOLUME ["/etc/clash", "/opt/clash/logs"]

ENTRYPOINT ["mihomo"]
CMD ["-d", "/etc/clash"]
