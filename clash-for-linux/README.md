# clash-for-linux

**现代化的 Linux Clash 代理管理工具。**

基于 [mihomo](https://github.com/MetaCubeX/mihomo)（Clash Meta）内核，提供一站式安装、管理和自动更新，支持 TUN/Fake-IP/Redirect 三种代理模式。

<p align="center">
  <img src="https://img.shields.io/badge/platform-linux%20%7C%20x86__64%20%7C%20arm64%20%7C%20armv7-blue" alt="Platform">
  <img src="https://img.shields.io/badge/core-mihomo-green" alt="Core">
  <img src="https://img.shields.io/badge/ui-metacubexd-orange" alt="Dashboard">
</p>

---

## 🚀 功能特性

- ✨ **一键安装** — 自动检测架构，下载最新 mihomo 内核、geo 数据库、metacubexd 面板
- 🎛️ **三种代理模式** — TUN（推荐）、Fake-IP、Redirect，一键切换
- 📡 **智能订阅管理** — 自动 base64 解码、YAML 合并、多订阅支持
- 🔄 **自动更新** — systemd timer 每日自动更新订阅、geo 数据、内核
- 🖥️ **Web 面板** — 内置 metacubexd，访问 `http://localhost:9090`
- 🛡️ **安全加固** — systemd 沙箱隔离、iptables 规则、最小权限
- 🩺 **全面诊断** — `clash doctor` 一键检查所有组件状态
- 📊 **流量统计** — 实时上传/下载/连接数查询
- 💾 **配置备份** — 自动备份+恢复，支持多份历史
- 🐳 **Docker 支持** — 完整的 Dockerfile + docker-compose.yml
- 🎯 **规则集管理** — 远程 rule-provider 自动更新，内置常见规则

---

## 📦 快速开始

### 安装

```bash
git clone https://github.com/111wukong/clash-for-linux.git
cd clash-for-linux/clash-for-linux
sudo bash install.sh
```

安装脚本会引导你选择代理模式，并提示输入订阅地址。

### 使用代理

```bash
source /etc/profile.d/clash.sh   # 加载代理函数（只需一次）
proxy_on                          # 开启代理
proxy_test                        # 测试连通性
```

### 日常管理

```bash
sudo clash status                 # 查看状态
sudo clash update                 # 更新订阅
sudo clash logs -f                # 实时日志
sudo clash doctor                 # 系统诊断
```

---

## 📋 CLI 命令参考

### 服务管理

| 命令 | 说明 |
|-----|------|
| `clash start` | 启动服务 |
| `clash stop` | 停止服务 |
| `clash restart` | 重启服务 |
| `clash reload` | 重载配置（无需重启） |
| `clash status` | 详细状态（端口/订阅/环境变量） |

### 更新升级

| 命令 | 说明 |
|-----|------|
| `clash update` | 更新订阅 + Geo 数据库 |
| `clash update URL` | 用指定 URL 更新订阅 |
| `clash update core` | 仅更新内核 |
| `clash update geo` | 仅更新 Geo 数据库 |
| `clash upgrade` | 全面升级（内核+Geo+订阅） |

### 订阅管理

| 命令 | 说明 |
|-----|------|
| `clash sub set URL` | 设置订阅地址 |
| `clash sub get` | 查看当前订阅地址 |
| `clash sub test` | 测试订阅连通性 |

### 配置管理

| 命令 | 说明 |
|-----|------|
| `clash config show` | 查看当前配置 |
| `clash config edit` | 编辑配置文件 |
| `clash config validate` | 校验 YAML 语法 |
| `clash config backup` | 备份当前配置 |
| `clash config restore` | 列出/恢复备份 |
| `clash switch MODE` | 切换代理模式 |

### 代理模式

| 模式 | 命令 | 说明 |
|-----|------|------|
| **TUN** | `clash switch tun` | 系统级透明代理，无需手动设置（推荐） |
| **Fake-IP** | `clash switch fake-ip` | 轻量 DNS 增强模式 |
| **Redirect** | `clash switch redirect` | iptables 重定向代理（传统模式） |

### 诊断工具

| 命令 | 说明 |
|-----|------|
| `clash doctor` | 全面系统诊断（服务/内核/配置/端口/流量） |
| `clash doctor --fix` | 自动修复常见问题 |
| `clash metrics` | 查看流量和连接统计 |
| `clash logs` | 最近 50 行日志 |
| `clash logs -f` | 实时日志 |
| `clash secret` | 显示 API 密钥 |

### 环境变量函数

| 命令 | 说明 |
|-----|------|
| `proxy_on` | 开启终端代理 |
| `proxy_off` | 关闭终端代理 |
| `proxy_status` | 查看代理状态和出口 IP |
| `proxy_test` | 测试 Google / Baidu 连通性 |

### 定时任务

| 命令 | 说明 |
|-----|------|
| `clash timer enable` | 开启每日自动更新（凌晨 4 点） |
| `clash timer disable` | 关闭自动更新 |
| `clash timer status` | 查看定时器状态 |

---

## 🐳 Docker 部署

```bash
# 方式一：docker compose
cp docker/docker-compose.yml ./
docker compose up -d

# 方式二：直接 docker run（host 网络模式）
docker run -d --name clash \
  --network host \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  -v $(pwd)/config.yaml:/etc/clash/config.yaml:ro \
  ghcr.io/111wukong/clash-for-linux:latest
```

**注意：** Docker 部署使用 host 网络模式（TUN/Fake-IP 功能需要），该模式不支持 macOS/Windows Docker 桌面版，仅限 Linux 主机。

---

## 📁 目录结构

```
/opt/clash/
├── bin/
│   └── mihomo          # Clash Meta 内核
├── conf/
│   ├── config.yaml      # 主配置文件
│   ├── rules/           # 远程规则集缓存
│   ├── providers/       # 代理提供者缓存
│   ├── geoip.dat        # GeoIP 数据库
│   ├── geosite.dat      # GeoSite 数据库
│   └── Country.mmdb     # IP 地理位置数据库
├── dashboard/           # Web 管理面板
├── logs/
│   └── clash.log        # 运行日志
└── backups/             # 配置备份

/etc/
├── systemd/system/
│   ├── clash.service             # 服务定义
│   ├── clash-update.timer         # 自动更新定时器
│   └── clash-update.service      # 更新服务
└── profile.d/
    └── clash.sh         # 终端代理函数

/usr/local/bin/
└── clash                # 管理 CLI
```

---

## 🔧 配置文件说明

### 端口

| 端口 | 用途 |
|-----|------|
| 7890 | HTTP/SOCKS 混合端口 |
| 9090 | RESTful API + 面板 |

### 订阅格式

支持标准 Clash 配置订阅链接，包括：
- 明文 YAML
- Base64 编码的 YAML 内容
- `proxy-providers` 订阅格式

### 规则集

默认使用 [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) 规则集，自动每日更新：

- **reject** — 广告/跟踪域名，直接拒绝
- **direct** — 大陆直连域名
- **proxy** — 代理域名（GFW 列表）
- **gfw** — GFW 拦截域名
- **apple** — Apple 服务直连
- **google** — Google 服务直连
- **cncidr** — 中国 IP 段
- **lancidr** — 局域网 IP 段

---

## 🪲 故障排查

```bash
# 全面诊断
sudo clash doctor

# 自动修复
sudo clash doctor --fix

# 查看实时日志
sudo clash logs -f

# 测试代理连通性
proxy_test

# 手动重启
sudo clash restart
```

### 常见问题

**代理不生效？**
```bash
source /etc/profile.d/clash.sh
proxy_on
curl --proxy http://127.0.0.1:7890 https://www.google.com
```

**订阅更新失败？**
```bash
sudo clash sub test              # 测试订阅 URL 连通性
sudo clash update SUB_URL        # 手动指定 URL 更新
sudo clash update core           # 更新内核到最新
```

**服务无法启动？**
```bash
sudo clash doctor                # 查看诊断
sudo clash logs -f               # 查看错误日志
sudo journalctl -u clash -f      # 查看 systemd 日志
```

---

## 🔄 从 v1 升级

如果你是 v1 用户，升级到 v2：

```bash
cd clash-for-linux
git pull
sudo bash install.sh             # 会保留现有配置
```

v2 新增：
- `clash doctor` — 全面诊断
- `clash switch` — 模式切换
- `clash metrics` — 流量统计
- `clash config backup/restore` — 配置备份恢复
- `clash timer` — 自动更新定时器
- `clash sub set/get/test` — 订阅管理
- `proxy_test` — 代理连通性测试
- 规则集（rule-provider）自动管理
- Docker 支持

---

## 📄 相关资源

- [mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo)
- [metacubexd 面板](https://github.com/MetaCubeX/metacubexd)
- [mihomo 配置文档](https://wiki.metacubex.one)
- [Clash 规则集](https://github.com/Loyalsoldier/clash-rules)

---

## 📝 License

MIT
