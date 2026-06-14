#!/usr/bin/env bash
# [PC] 按需打开本地 ~/Share（不启热点、不挂载手机、不阻塞 Dolphin）
set -euo pipefail

SHARE_DIR="$HOME/Share"
FM="${FILE_MANAGER:-dolphin}"

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

mkdir -p "$SHARE_DIR"/{from-pc,to-pc,from-phone,to-phone}

cat > "$SHARE_DIR/.directory" <<'EOF'
[Dolphin]
PreviewsShown=false
ViewMode=1
SortBy=Name
SortOrder=Ascending
EOF

if ! command -v "$FM" >/dev/null 2>&1; then
  xdg-open "$SHARE_DIR" >/dev/null 2>&1 &
elif pgrep -x dolphin >/dev/null 2>&1; then
  dolphin --select "$SHARE_DIR" >/dev/null 2>&1 &
else
  nohup dolphin "$SHARE_DIR" >/dev/null 2>&1 &
fi

echo "[OK] 已打开 $SHARE_DIR（本地目录，与热点/手机无关）"
