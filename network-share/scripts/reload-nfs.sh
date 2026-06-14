#!/usr/bin/env bash
# [PC] 随 PC 热点启停 nfs-server；热点关时停服，避免空闲监听
# 用法: reload-nfs.sh [auto|start|stop]   — hostapd-ctl 调用 start/stop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
EXPORT_ROOT="${EXPORT_ROOT:-/export/azure-share}"
MODE="${1:-auto}"

ensure_bind_mount() {
  local share_dir="${SHARE_DIR:-$HOME/Share}"
  if mountpoint -q "$EXPORT_ROOT" 2>/dev/null; then
    return 0
  fi
  sudo mkdir -p "$EXPORT_ROOT" "$share_dir"
  if ! grep -qF "$EXPORT_ROOT" /etc/fstab 2>/dev/null; then
    echo "$share_dir $EXPORT_ROOT none bind 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
  sudo mount --bind "$share_dir" "$EXPORT_ROOT"
}

stop_nfs() {
  if systemctl is-active --quiet nfs-server 2>/dev/null; then
    echo "停止 nfs-server"
    sudo systemctl stop nfs-server 2>/dev/null || true
  fi
  if systemctl is-active --quiet nfsdcld 2>/dev/null; then
    echo "停止 nfsdcld"
    sudo systemctl stop nfsdcld 2>/dev/null || true
  fi
}

ensure_exports() {
  local ref="$SCRIPT_DIR/../configs/exports.reference"
  if [[ -f "$ref" ]] && ! grep -q insecure /etc/exports 2>/dev/null; then
    echo "[*] 更新 /etc/exports（加 insecure，供 Android NFS 客户端）"
    sudo install -m 644 "$ref" /etc/exports
  fi
}

start_nfs() {
  ensure_bind_mount
  ensure_exports
  if ! systemctl is-active --quiet nfs-server 2>/dev/null; then
    echo "启动 nfs-server"
    sudo systemctl start nfs-server 2>/dev/null || sudo systemctl start nfs-server
  else
    sudo exportfs -ra 2>/dev/null || sudo systemctl reload nfs-server 2>/dev/null || true
  fi
  echo "NFS 导出:"
  exportfs -v 2>/dev/null || sudo exportfs -v
  showmount -e localhost 2>/dev/null || sudo showmount -e localhost 2>/dev/null || true
}

case "$MODE" in
  stop)
    stop_nfs
    ;;
  start)
    start_nfs
    ;;
  auto)
    HOTSPOT="${HOTSPOT_NAME:-pc-hotspot}"
    if ! systemctl is-active --quiet "hostapd@${HOTSPOT}" 2>/dev/null; then
      stop_nfs
      exit 0
    fi
    start_nfs
    ;;
  *)
    echo "用法: $(basename "$0") [auto|start|stop]" >&2
    exit 1
    ;;
esac
