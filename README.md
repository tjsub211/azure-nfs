# AzureNFS

PC 开 NFS 共享，手机用 **AzureNFS** App（Android SAF 文档提供者）在系统文件管理器里读写。

## 组成

| 目录 | 作用 |
|------|------|
| [`nfs-saf/`](nfs-saf/) | 安卓客户端 APK 源码，`./build-and-install.sh` 构建安装 |
| [`pc-hotspot/`](pc-hotspot/) | PC WiFi 热点（手机连上后才能访问 NFS） |
| [`network-share/`](network-share/) | PC 端 NFS 服务端部署与日常脚本 |

## 快速开始

```bash
# 1. PC：编辑 pc-hotspot/scripts/hostapd.conf（SSID、密码、网卡）后部署
bash pc-hotspot/scripts/setup-hotspot.sh
bash network-share/scripts/setup-network-share.sh

# 2. 开热点（NFS 随热点启停）
~/bin/pc-hotspot-toggle.sh

# 3. 手机：构建安装 App，添加连接 <PC网关IP>:/export/azure-share
cd nfs-saf && ./build-and-install.sh
```

共享目录：`~/Share`（`from-pc` / `to-pc` 等）。`exports.reference` 中的客户端网段需与热点网段一致。
