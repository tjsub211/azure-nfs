#!/usr/bin/env bash
# hostapd 80MHz + dnsmasq（直连有线口；按本机改 IF / UPLINK / SUBNET / GW）
set -euo pipefail

IF="${WLAN_IF:-wlan0}"
UPLINK="${UPLINK_IF:-eth0}"
SUBNET="${HOTSPOT_SUBNET:-10.0.0.0/24}"
GW="${HOTSPOT_GW:-10.0.0.1}"
DHCP_LO="${HOTSPOT_DHCP_LO:-10.0.0.10}"
DHCP_HI="${HOTSPOT_DHCP_HI:-10.0.0.254}"
HOTSPOT="${HOTSPOT_NAME:-pc-hotspot}"
MAC=$(ethtool -P "$IF" | awk '{print $3}')
RUN=/run/pc-hotspot
LEASE="/var/lib/NetworkManager/dnsmasq-${IF}.leases"
NFT=pc_hotspot_nat
UPLINK_QDISC_SAVED="${RUN}/uplink_qdisc"

add_direct_route_rules() {
  ip rule del iif "$IF" lookup main priority 48 2>/dev/null || true
  ip rule del to "$SUBNET" lookup main priority 49 2>/dev/null || true
  ip rule del from "$SUBNET" lookup main priority 50 2>/dev/null || true
  ip rule add iif "$IF" lookup main priority 48
  ip rule add to "$SUBNET" lookup main priority 49
  ip rule add from "$SUBNET" lookup main priority 50
}

del_direct_route_rules() {
  ip rule del iif "$IF" lookup main priority 48 2>/dev/null || true
  ip rule del to "$SUBNET" lookup main priority 49 2>/dev/null || true
  ip rule del from "$SUBNET" lookup main priority 50 2>/dev/null || true
}

apply_low_latency() {
  sysctl -w \
    net.ipv4.ip_forward=1 \
    net.core.default_qdisc=fq \
    net.ipv4.tcp_low_latency=1 \
    net.ipv4.tcp_fastopen=3 \
    net.ipv4.tcp_slow_start_after_idle=0 \
    net.ipv4.conf.all.rp_filter=0 \
    net.ipv4.conf."$IF".rp_filter=0 \
    net.ipv4.conf."$UPLINK".rp_filter=0 \
    net.netfilter.nf_conntrack_udp_timeout=30 \
    net.netfilter.nf_conntrack_udp_timeout_stream=60 \
    >/dev/null 2>&1 || true

  iw dev "$IF" set power_save off 2>/dev/null || true
  TC=/usr/sbin/tc
  [[ -x "$TC" ]] || TC=$(command -v tc || true)
  [[ -n "$TC" ]] && "$TC" qdisc replace dev "$IF" root noqueue 2>/dev/null || true
  [[ -z "$TC" ]] && return 0
  mkdir -p "$RUN"
  if [[ ! -f "$UPLINK_QDISC_SAVED" ]]; then
    "$TC" qdisc show dev "$UPLINK" 2>/dev/null | head -1 >"$UPLINK_QDISC_SAVED" || true
  fi
  "$TC" qdisc replace dev "$UPLINK" root fq_codel limit 10240 flows 1024 target 5ms interval 100ms 2>/dev/null || \
    "$TC" qdisc replace dev "$UPLINK" root fq 2>/dev/null || true
}

restore_uplink_qdisc() {
  [[ -f "$UPLINK_QDISC_SAVED" ]] || return 0
  TC=/usr/sbin/tc
  [[ -x "$TC" ]] || TC=$(command -v tc || true)
  [[ -n "$TC" ]] || { rm -f "$UPLINK_QDISC_SAVED"; return 0; }
  read -r saved <"$UPLINK_QDISC_SAVED" || true
  if [[ "$saved" == *"fq_codel"* ]]; then
    :
  elif [[ "$saved" == *"fq"* ]]; then
    "$TC" qdisc replace dev "$UPLINK" root fq 2>/dev/null || true
  fi
  rm -f "$UPLINK_QDISC_SAVED"
}

cleanup_hotspot_stale() {
  pkill -f "dnsmasq.*${IF}" 2>/dev/null || true
  rm -f "$LEASE"
}

reload_nfs() {
  local mode="${1:-auto}"
  local script="${RELOAD_NFS:-$HOME/bin/reload-nfs.sh}"
  [[ -x "$script" ]] || script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/network-share/scripts/reload-nfs.sh"
  [[ -x "$script" ]] || return 0
  "$script" "$mode" || true
}

start() {
  nmcli device set "$IF" managed no 2>/dev/null || true
  iw reg set CN 2>/dev/null || true

  ip link set "$IF" down 2>/dev/null || true
  ip link set "$IF" address "$MAC" up
  ip addr flush dev "$IF"
  ip addr add "${GW}/24" dev "$IF"

  apply_low_latency
  add_direct_route_rules

  nft delete table ip "$NFT" 2>/dev/null || true
  nft add table ip "$NFT"
  nft add chain ip "$NFT" postrouting '{ type nat hook postrouting priority srcnat; policy accept; }'
  nft add rule ip "$NFT" postrouting ip saddr "$SUBNET" oifname "$UPLINK" masquerade
  nft add chain ip "$NFT" forward '{ type filter hook forward priority filter; policy accept; }'
  nft add rule ip "$NFT" forward iifname "$IF" oifname "$UPLINK" accept
  nft add rule ip "$NFT" forward iifname "$UPLINK" oifname "$IF" ct state established,related accept
  nft add chain ip "$NFT" input '{ type filter hook input priority filter - 10; policy accept; }'
  nft add rule ip "$NFT" input iifname "$IF" udp dport '{ 67, 68 }' accept
  firewall-cmd --quiet --zone=trusted --change-interface="$IF" 2>/dev/null || true

  systemctl start "hostapd@${HOTSPOT}"
  for _ in $(seq 1 10); do
    iw dev "$IF" info 2>/dev/null | grep -q 'type AP' && break
    sleep 1
  done

  mkdir -p "$RUN" /var/lib/NetworkManager
  pkill -f "dnsmasq.*${IF}" 2>/dev/null || true
  rm -f "$LEASE"; touch "$LEASE"; chmod 666 "$LEASE"
  /usr/sbin/dnsmasq --conf-file=/dev/null --port=0 --no-hosts --no-resolv \
    --interface="$IF" --bind-dynamic \
    --dhcp-range="${DHCP_LO},${DHCP_HI},3600" \
    --dhcp-option=3,"$GW" --dhcp-option=6,223.5.5.5,119.29.29.29 \
    --dhcp-authoritative --dhcp-leasefile="$LEASE" &
  echo $! > "${RUN}/dnsmasq.pid"
  reload_nfs start
}

stop() {
  [ -f "${RUN}/dnsmasq.pid" ] && kill "$(cat "${RUN}/dnsmasq.pid")" 2>/dev/null || true
  rm -f "${RUN}/dnsmasq.pid"
  pkill -f "dnsmasq.*${IF}" 2>/dev/null || true
  firewall-cmd --quiet --zone=trusted --remove-interface="$IF" 2>/dev/null || true
  systemctl stop "hostapd@${HOTSPOT}" 2>/dev/null || true
  reload_nfs stop
  nft delete table ip "$NFT" 2>/dev/null || true
  del_direct_route_rules
  restore_uplink_qdisc
  ip addr flush dev "$IF" 2>/dev/null || true
  ip link set "$IF" down 2>/dev/null || true
  cleanup_hotspot_stale
}

status() {
  systemctl is-active "hostapd@${HOTSPOT}" 2>/dev/null || echo inactive
  iw dev "$IF" info 2>/dev/null | grep -E 'ssid|channel|width' || true
  pgrep -af "dnsmasq.*${IF}" || true
  TC=/usr/sbin/tc
  [[ -x "$TC" ]] || TC=$(command -v tc || true)
  [[ -n "$TC" ]] && "$TC" qdisc show dev "$IF" 2>/dev/null | head -1 || true
  [[ -n "$TC" ]] && "$TC" qdisc show dev "$UPLINK" 2>/dev/null | head -1 || true
  cat "$LEASE" 2>/dev/null || true
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  *) echo "用法: pc-hotspot-hostapd-ctl {start|stop|restart|status}"; exit 1 ;;
esac
