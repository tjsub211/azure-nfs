#!/usr/bin/env bash
# [PC] 部署 NFS 导出 + ~/Share + ~/bin 链接；停用 Samba（若曾安装）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARE_DIR="$HOME/Share"
EXPORT_ROOT=/export/azure-share
BIN="$HOME/bin"

mkdir -p "$SHARE_DIR"/{from-pc,to-pc,from-phone,to-phone} "$BIN"

echo "==> 安装系统包"
"$SCRIPT_DIR/install-tools.sh"

if ! sudo -n true 2>/dev/null; then
  echo "==> 部署热点 sudoers（Agent 需 NOPASSWD）"
  if [[ -t 0 ]] && "$SCRIPT_DIR/install-sudoers-hotspot.sh"; then
    :
  else
    echo "提示: 在本机终端运行一次: bash network-share/scripts/install-sudoers-hotspot.sh" >&2
  fi
fi

echo "==> 停用 Samba（避免 Dolphin smb:// 卡顿）"
if systemctl is-active --quiet smb 2>/dev/null; then
  sudo systemctl stop smb 2>/dev/null || true
fi
if systemctl is-enabled --quiet smb 2>/dev/null; then
  sudo systemctl disable smb 2>/dev/null || true
fi

echo "==> 绑定导出目录 $EXPORT_ROOT → $SHARE_DIR"
sudo mkdir -p "$EXPORT_ROOT"
if ! grep -qF "$EXPORT_ROOT" /etc/fstab 2>/dev/null; then
  echo "$SHARE_DIR $EXPORT_ROOT none bind,nofail 0 0" | sudo tee -a /etc/fstab >/dev/null
fi
sudo mount --bind "$SHARE_DIR" "$EXPORT_ROOT" 2>/dev/null || sudo mount "$EXPORT_ROOT"

echo "==> 部署 /etc/exports"
if ! sudo test -f /etc/exports.bak-azure-share; then
  sudo cp -a /etc/exports /etc/exports.bak-azure-share 2>/dev/null || true
fi
sudo install -m 644 "$PROJECT/configs/exports.reference" /etc/exports
sudo exportfs -ra 2>/dev/null || true

echo "==> 部署 /etc/nfs.conf"
if ! sudo test -f /etc/nfs.conf.bak-azure-share; then
  sudo cp -a /etc/nfs.conf /etc/nfs.conf.bak-azure-share 2>/dev/null || true
fi
sudo install -m 644 "$PROJECT/configs/nfs.conf.reference" /etc/nfs.conf

echo "==> firewalld（若启用）放行 NFS"
if systemctl is-active --quiet firewalld 2>/dev/null; then
  sudo firewall-cmd --permanent --add-service=nfs >/dev/null 2>&1 || true
  sudo firewall-cmd --reload >/dev/null 2>&1 || true
fi

# 仅常驻 rpcbind；nfs-server 随热点启停（reload-nfs.sh）
sudo systemctl enable --now rpcbind

echo "==> 部署脚本到 ~/bin"
for name in reload-nfs open-share open-phone-share setup-dolphin-places; do
  ln -sf "$SCRIPT_DIR/${name}.sh" "$BIN/${name}.sh"
  chmod +x "$SCRIPT_DIR/${name}.sh"
done

cp "$PROJECT/docs/连接说明.txt" "$SHARE_DIR/连接说明.txt"

"$SCRIPT_DIR/setup-dolphin-places.sh"

HOTSPOT="${HOTSPOT_NAME:-pc-hotspot}"
if systemctl is-active --quiet "hostapd@${HOTSPOT}" 2>/dev/null; then
  echo "PC 热点: 运行中"
elif [[ -x /usr/local/bin/pc-hotspot-hostapd-ctl ]]; then
  echo "启动 PC 热点..."
  sudo /usr/local/bin/pc-hotspot-hostapd-ctl start
else
  echo "提示: 未安装热点，请先运行 pc-hotspot/scripts/setup-hotspot.sh" >&2
fi

"$SCRIPT_DIR/reload-nfs.sh"

echo
echo "=== 共享就绪 ==="
echo "PC 本地:   $SHARE_DIR"
echo "手机客户端: AzureNFS App → <PC网关IP>:/export/azure-share"
echo "构建安装:  cd nfs-saf && ./build-and-install.sh"
echo "开热点:    ~/bin/pc-hotspot-toggle.sh"
echo "打开共享:  ~/bin/open-share.sh"
