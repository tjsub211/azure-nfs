#!/usr/bin/env bash
# 安装 PC WiFi 热点：5GHz hostapd + dnsmasq（部署前改 hostapd.conf 与网卡名）
set -euo pipefail

IF="${WLAN_IF:-wlan0}"
NAME="${HOTSPOT_NAME:-pc-hotspot}"
CTL=/usr/local/bin/pc-hotspot-hostapd-ctl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 清理旧 NM 热点配置"
for old in "$NAME" pc-hotspot Hotspot; do
  nmcli connection down "$old" 2>/dev/null || true
  nmcli connection delete "$old" 2>/dev/null || true
  sudo nmcli connection delete "$old" 2>/dev/null || true
done
sudo rm -f "/etc/NetworkManager/system-connections/${NAME}.nmconnection" 2>/dev/null || true

echo "==> 安装 hostapd 配置"
sudo install -d /etc/hostapd
sudo install -m 644 "$SCRIPT_DIR/hostapd.conf" "/etc/hostapd/${NAME}.conf"
sudo install -m 755 "$SCRIPT_DIR/hostapd-ctl.sh" "$CTL"

echo "==> 安装 systemd 单元"
sudo tee /etc/systemd/system/hostapd@.service >/dev/null <<'EOF'
[Unit]
Description=hostapd AP %i
PartOf=pc-hotspot.service
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/hostapd /etc/hostapd/%i.conf
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/pc-hotspot.service >/dev/null <<EOF
[Unit]
Description=PC WiFi Hotspot (hostapd + dnsmasq)
After=network-online.target
Wants=network-online.target
Conflicts=hostapd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$CTL start
ExecStop=$CTL stop

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

BIN="${HOME}/bin"
mkdir -p "$BIN"
ln -sf "$SCRIPT_DIR/hotspot-toggle.sh" "$BIN/pc-hotspot-toggle.sh"
chmod +x "$SCRIPT_DIR/hotspot-toggle.sh"

echo "==> 同步 configs/ 备份"
CONFIGS_DIR="$SCRIPT_DIR/../configs"
OWNER="${SUDO_USER:-${USER:-$(id -un)}}"
mkdir -p "$CONFIGS_DIR"
sudo chown -R "$OWNER:$OWNER" "$CONFIGS_DIR" 2>/dev/null || true
cp "$SCRIPT_DIR/hostapd.conf" "$CONFIGS_DIR/hostapd.conf"
cp "$SCRIPT_DIR/dnsmasq.conf" "$CONFIGS_DIR/dnsmasq.conf"

echo ""
echo "OK: hostapd 已安装（实例名 ${NAME}）"
echo "    请编辑 /etc/hostapd/${NAME}.conf 设置 SSID 与 wpa_passphrase"
echo "    无线网卡: ${IF}（可用环境变量 WLAN_IF 覆盖）"
echo ""
echo "启动: sudo $CTL start"
echo "开关: ~/bin/pc-hotspot-toggle.sh"
echo "停止: sudo $CTL stop"
echo "状态: sudo $CTL status"
echo "开机自启（可选）: sudo systemctl enable pc-hotspot.service"
