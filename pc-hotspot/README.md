# PC WiFi 热点

5GHz WiFi 热点（hostapd + dnsmasq）。手机连上后访问 PC 的 NFS 共享（`network-share/`）。

部署前请按本机修改：`hostapd.conf` 里的 **SSID / 密码**，脚本顶部的 **网卡名** 与 **网段**。

## 脚本

| 脚本 | 用途 |
|------|------|
| `scripts/hotspot-toggle.sh` | 开关热点 |
| `scripts/hostapd-ctl.sh` | 底层 start/stop（部署到 `/usr/local/bin/pc-hotspot-hostapd-ctl`） |
| `scripts/setup-hotspot.sh` | 一键安装到系统 |

开热点时自动 `reload-nfs.sh start`；关热点时停 `nfs-server` + `nfsdcld`。

## 默认示例（请自行修改）

- SSID：`pc-hotspot`（`hostapd.conf`）
- 网关：`10.0.0.1/24`
- DHCP：`10.0.0.10` – `10.0.0.254`
- 无线网卡：`wlan0`；上联：`eth0`

## 安装

```bash
bash scripts/setup-hotspot.sh
~/bin/pc-hotspot-toggle.sh
```
