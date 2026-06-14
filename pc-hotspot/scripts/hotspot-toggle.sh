#!/usr/bin/env bash
# 切换 hostapd 热点
set -euo pipefail

CTL=/usr/local/bin/pc-hotspot-hostapd-ctl
IF="${WLAN_IF:-wlan0}"
HOTSPOT="${HOTSPOT_NAME:-pc-hotspot}"

notify() {
  notify-send "$@"
}

is_hotspot_on() {
  systemctl is-active --quiet "hostapd@${HOTSPOT}" 2>/dev/null &&
    iw dev "$IF" info 2>/dev/null | grep -q 'type AP'
}

hotspot_info() {
  iw dev "$IF" info 2>/dev/null | grep -E 'ssid|channel|width' | tr '\n' ' ' || true
}

turn_off() {
  sudo "$CTL" stop
  notify "热点已关闭" "hostapd 已停止。" \
    -i network-wireless-disconnected -a pc-hotspot
}

turn_on() {
  if ! sudo "$CTL" start; then
    notify "热点启动失败" "请运行：journalctl -u hostapd@${HOTSPOT} -n 20" \
      -u critical -a pc-hotspot
    exit 1
  fi

  sleep 1
  if ! is_hotspot_on; then
    notify "热点启动失败" "hostapd 未进入 AP 模式，请检查日志。" \
      -u critical -a pc-hotspot
    exit 1
  fi

  local info
  info=$(hotspot_info)
  notify "热点已开启" "${info}\n密码见 /etc/hostapd/${HOTSPOT}.conf" \
    -i network-wireless -a pc-hotspot
}

if is_hotspot_on; then
  turn_off
else
  turn_on
fi
