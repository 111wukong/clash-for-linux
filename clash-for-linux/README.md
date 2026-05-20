# clash-for-linux

**Modern Clash proxy client for Linux servers.**  
Powered by [mihomo](https://github.com/MetaCubeX/mihomo) (Clash Meta) — the next-generation core with TUN support, better performance, and broader protocol compatibility.

## Features

- **One-command install** — automatically downloads the latest mihomo core, GeoIP/GeoSite databases, and metacubexd dashboard
- **Systemd integration** — proper service lifecycle management (start/stop/restart/enable)
- **TUN mode** — system-wide transparent proxy, no manual proxy configuration needed
- **DNS hijacking** — intercepts DNS queries for better routing
- **Dashboard** — built-in metacubexd web UI at `http://localhost:9090`
- **Auto-update** — subscription refresh and core updates via `clash update`
- **Security hardening** — systemd sandboxing, non-privileged operation
- **Diagnostics** — `clash doctor` runs comprehensive health checks

## Quick Start

### 1. Install

```bash
git clone https://github.com/111wukong/clash-for-linux.git
cd clash-for-linux/clash-for-linux
sudo bash install.sh
```

The script will:
- Detect your CPU architecture (x86_64 / arm64 / armv7)
- Download the latest mihomo release from GitHub
- Download GeoIP, GeoSite databases and Country.mmdb
- Download metacubexd dashboard
- Generate a secure default configuration
- Install systemd service
- Install environment profile (`/etc/profile.d/clash.sh`)

### 2. Configure subscription

Edit the config file:

```bash
sudo vim /opt/clash/conf/config.yaml
```

Add your proxy provider under `proxy-providers:` section. Example:

```yaml
proxy-providers:
  provider1:
    type: http
    url: "YOUR_SUBSCRIPTION_URL"
    interval: 3600
    path: ./providers/provider1.yaml
    health-check:
      enable: true
      url: http://www.gstatic.com/generate_204
      interval: 300
```

Or set the URL directly:

```bash
echo 'subscription-url: "YOUR_SUBSCRIPTION_URL"' | sudo tee -a /opt/clash/conf/config.yaml
```

### 3. Start the service

```bash
sudo clash start
```

### 4. Enable proxy

```bash
source /etc/profile.d/clash.sh
proxy_on
```

### 5. Verify

```bash
clash status
curl -I https://www.google.com
```

## Usage

### Management Commands

| Command | Description |
|---------|-------------|
| `sudo clash start` | Start the Clash service |
| `sudo clash stop` | Stop the Clash service |
| `sudo clash restart` | Restart Clash |
| `clash status` | Show service status, ports, and secret |
| `sudo clash update` | Update subscription and restart |
| `clash logs` | View recent logs |
| `clash logs -f` | Follow logs in real-time |
| `clash secret` | Print the dashboard secret |
| `clash doctor` | Run diagnostics |

### Environment Functions

| Function | Description |
|----------|-------------|
| `proxy_on` | Set http_proxy/https_proxy environment variables |
| `proxy_off` | Unset proxy environment variables |
| `proxy_status` | Show current proxy state |

## Dashboard

Open your browser to `http://<server-ip>:9090`

- **API Base URL**: `http://<server-ip>:9090`
- **Secret**: run `clash secret`

## Project Structure

```
clash-for-linux/
├── install.sh            # One-click setup script
├── clash.sh              # Management CLI (symlinked to /usr/local/bin/clash)
├── .env                  # Subscription URL configuration
├── conf/
│   └── config.yaml       # Main configuration file
└── README.md
```

**Runtime directories (created by install.sh):**

```
/opt/clash/
├── bin/mihomo            # mihomo core binary
├── conf/
│   ├── config.yaml       # Main config
│   ├── geoip.dat         # GeoIP database
│   ├── geosite.dat       # GeoSite database
│   └── Country.mmdb      # MMDB for geoip
├── dashboard/            # metacubexd web UI
└── logs/clash.log        # Service logs
```

## Requirements

- Linux (RHEL/Debian/Arch)
- root/sudo access
- curl, wget, tar, systemctl
- Python 3 (optional, for smart subscription merging)

## Uninstall

```bash
sudo systemctl stop clash
sudo systemctl disable clash
sudo rm -f /etc/systemd/system/clash.service
sudo rm -rf /opt/clash
sudo rm -f /etc/profile.d/clash.sh
sudo rm -f /usr/local/bin/clash
```

## Migrating from v1

If you were using the old version with `start.sh` / `shutdown.sh`:

1. Back up your old config: `cp /path/to/old/clash/conf/config.yaml ~/backup.yaml`
2. Run the new install script
3. Apply your subscription settings

## Troubleshooting

- **"Failed to start"**: Run `clash doctor` to check all components
- **Port conflicts**: Edit `/opt/clash/conf/config.yaml` and change port numbers
- **TUN errors**: Ensure the kernel module is loaded: `sudo modprobe tun`
- **DNS not working**: Check firewall rules for port 53

## Security Notes

- The service runs under systemd sandboxing with limited capabilities
- Only `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE` are granted
- Private /tmp and /home are enforced
- Dashboard should be firewalled in production environments

## License

MIT
