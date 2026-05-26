# clash-for-linux

**现代化的 Linux Clash 代理管理工具** 🚀

基于 [mihomo](https://github.com/MetaCubeX/mihomo)（Clash Meta）内核，一键安装、自动更新，支持 TUN / Fake-IP / Redirect 三种代理模式。

## 快速开始

```bash
git clone https://github.com/111wukong/clash-for-linux.git
cd clash-for-linux/clash-for-linux
sudo bash install.sh
```

## 特性

- ✨ 一键安装，自动检测 CPU 架构
- 🎛️ TUN / Fake-IP / Redirect 三种代理模式，一键切换
- 📡 智能订阅管理（base64 自动解码 + YAML 合并）
- 🔄 每日自动更新（订阅 + Geo 数据库 + 内核）
- 🖥️ 内置 metacubexd Web 管理面板
- 🩺 全面诊断工具（`clash doctor`）
- 📊 实时流量统计与连接监控
- 💾 配置备份/恢复
- 🐳 Docker 支持
- 🛡️ systemd 安全沙箱隔离

## 完整文档

详细使用文档：[clash-for-linux/README.md](clash-for-linux/README.md)

## 环境要求

- Linux（x86_64 / arm64 / armv7）
- systemd（主流发行版均支持）
- curl、tar、openssl

测试过的发行版：Ubuntu 20.04+ / Debian 11+ / CentOS 7+ / Rocky Linux / Arch Linux

## 许可证

MIT
