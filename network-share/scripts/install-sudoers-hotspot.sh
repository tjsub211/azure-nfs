#!/usr/bin/env bash
# 部署热点 ctl 的 NOPASSWD sudoers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="$SCRIPT_DIR/../configs/sudoers-azure-share.reference"
DEST=/etc/sudoers.d/azure-share
USER_NAME="${SUDOERS_USER:-$USER}"
CMD="sed 's/YOUR_USER/${USER_NAME}/' '$REF' | install -m 440 /dev/stdin '$DEST' && visudo -cf '$DEST'"

[[ -f "$REF" ]] || { echo "缺少 $REF" >&2; exit 1; }

if sudo -n true 2>/dev/null; then
  sudo bash -c "$CMD"
  echo "OK: $DEST（pc-hotspot-hostapd-ctl 免密 sudo）"
  exit 0
fi

if [[ -n "${DISPLAY:-}" ]] && command -v pkexec >/dev/null 2>&1; then
  echo "[*] 尝试 pkexec（图形授权）..."
  if pkexec bash -c "$CMD" 2>/dev/null; then
    echo "OK: $DEST（pc-hotspot-hostapd-ctl 免密 sudo）"
    exit 0
  fi
fi

echo "需要 root 密码一次性部署 sudoers："
su -c "$CMD"
echo "OK: $DEST（pc-hotspot-hostapd-ctl 免密 sudo）"
