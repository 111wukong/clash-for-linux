# clash-for-linux

**现代化的 Linux Clash 代理客户端。**  
基于 [mihomo](https://github.com/MetaCubeX/mihomo)（原 Clash Meta）内核，支持 TUN 模式、更好的性能和更广泛的协议兼容性。

## 功能特性

- **一键安装** — 自动下载最新 mihomo 内核、GeoIP/GeoSite 数据库、metacubexd 面板
- **Systemd 集成** — 完整的服务生命周期管理（启动/停止/重启/开机自启）
- **TUN 模式** — 系统级透明代理，无需手动配置代理
- **DNS 劫持** — 拦截 DNS 查询实现更优路由
- **管理面板** — 内置 metacubexd Web UI，访问 `http://localhost:9090`
- **自动更新** — `clash update` 一键刷新订阅和更新内核
- **安全加固** — systemd 沙箱隔离，最小权限原则
- **诊断工具** — `clash doctor` 全面健康检查

## 快速开始

### 1. 安装

```bash
git clone https://github.com/111wukong/clash-for-linux.git
cd clash-for-linux/clash-for-linux
sudo bash install.sh
```

安装脚本会自动完成以下操作：
- 检测 CPU 架构（x86_64 / arm64 / armv7）
- 从 GitHub 下载最新 mihomo 内核
- 下载 GeoIP、GeoSite 数据库和 Country.mmdb
- 下载 metacubexd 管理面板
- 生成安全默认配置
- 安装 systemd 服务
- 安装环境变量配置（`/etc/profile.d/clash.sh`）

### 2. 配置订阅

编辑配置文件：

```bash
sudo vim /opt/clash/conf/config.yaml
```

在 `proxy-providers:` 部分添加你的代理订阅。示例：

```yaml
proxy-providers:
  provider1:
    type: http
    url: "你的订阅地址"
    interval: 3600
    path: ./providers/provider1.yaml
    health-check:
      enable: true
      url: http://www.gstatic.com/generate_204
      interval: 300
```

也可以直接设置订阅 URL：

```bash
echo 'subscription-url: "你的订阅地址"' | sudo tee -a /opt/clash/conf/config.yaml
```

### 3. 启动服务

```bash
sudo clash start
```

### 4. 开启代理

```bash
source /etc/profile.d/clash.sh
proxy_on
```

### 5. 验证

```bash
clash status
curl -I https://www.google.com
```

## 使用方法

### 管理命令

| 命令 | 说明 |
|------|------|
| `sudo clash start` | 启动 Clash 服务 |
| `sudo clash stop` | 停止 Clash 服务 |
| `sudo clash restart` | 重启 Clash 服务 |
| `clash status` | 查看服务状态、端口和密钥 |
| `sudo clash update` | 更新订阅并重启 |
| `clash logs` | 查看最近日志 |
| `clash logs -f` | 实时跟踪日志 |
| `clash secret` | 打印面板密钥 |
| `clash doctor` | 运行诊断检查 |

### 环境函数

| 函数 | 说明 |
|------|------|
| `proxy_on` | 设置 http_proxy/https_proxy 环境变量 |
| `proxy_off` | 取消代理环境变量 |
| `proxy_status` | 查看当前代理状态 |

## 管理面板

浏览器打开 `http://<服务器IP>:9090`

- **API Base URL**: `http://<服务器IP>:9090`
- **Secret**: 运行 `clash secret` 获取

## 项目结构

```
clash-for-linux/
├── install.sh            # 一键安装脚本
├── clash.sh              # 管理命令行工具（会软链到 /usr/local/bin/clash）
├── .env                  # 订阅地址配置
├── conf/
│   └── config.yaml       # 主配置文件（安装后生成）
└── README.md
```

**运行时目录（由 install.sh 创建）：**

```
/opt/clash/
├── bin/mihomo            # mihomo 内核二进制
├── conf/
│   ├── config.yaml       # 主配置
│   ├── geoip.dat         # GeoIP 数据库
│   ├── geosite.dat       # GeoSite 数据库
│   └── Country.mmdb      # IP 地理位置数据库
├── dashboard/            # metacubexd Web 面板
└── logs/clash.log        # 服务日志
```

## 系统要求

- Linux 系统（RHEL/Debian/Arch）
- root/sudo 权限
- curl, wget, tar, systemctl
- Python 3（可选，用于智能订阅合并）

## 卸载

```bash
sudo systemctl stop clash
sudo systemctl disable clash
sudo rm -f /etc/systemd/system/clash.service
sudo rm -rf /opt/clash
sudo rm -f /etc/profile.d/clash.sh
sudo rm -f /usr/local/bin/clash
```

## 从旧版迁移

如果你正在使用旧版的 `start.sh` / `shutdown.sh`：

1. 备份旧配置：`cp /path/to/old/clash/conf/config.yaml ~/backup.yaml`
2. 运行新的安装脚本
3. 重新配置订阅

## 常见问题

- **服务启动失败**：运行 `clash doctor` 检查各组件状态
- **端口冲突**：编辑 `/opt/clash/conf/config.yaml` 修改端口号
- **TUN 错误**：确保内核模块已加载：`sudo modprobe tun`
- **DNS 不工作**：检查防火墙是否放行了 53 端口

## 安全说明

- 服务在 systemd 沙箱中运行，仅授予最小权限
- 仅授权 `CAP_NET_ADMIN`、`CAP_NET_RAW`、`CAP_NET_BIND_SERVICE` 三个能力
- 强制隔离 /tmp 和 /home
- 生产环境下建议对管理面板配置防火墙

## 许可证

MIT
