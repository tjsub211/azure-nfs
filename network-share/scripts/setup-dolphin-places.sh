#!/usr/bin/env bash
# [PC] 确保 Dolphin 的 Places 里有 ~/Share（NFS 共享），并清理 smb:// 残留书签。
# 说明：早期为治 Samba/smb:// 卡顿曾把 Share 书签移除、关预览、缩图标；现已改用
#   NFS（本地 ~/Share，无卡顿），故本脚本改为「加入 Share」，不再降级 Dolphin。
set -euo pipefail

SHARE_DIR="${SHARE_DIR:-$HOME/Share}"
PLACES="${XDG_DATA_HOME:-$HOME/.local/share}/user-places.xbel"

SHARE_DIR="$SHARE_DIR" PLACES="$PLACES" python3 <<'PY'
import os
from pathlib import Path

places = Path(os.environ["PLACES"])
share = Path(os.environ["SHARE_DIR"]).resolve()
share_href = "file://" + str(share)

if not places.is_file():
    print(f"Places: 尚无 {places}，请先打开一次 Dolphin 再运行本脚本")
    raise SystemExit(0)

text = places.read_text(encoding="utf-8")

# 1) 移除 smb:// 残留书签（仅 smb，避免历史卡顿；保留其它一切）
lines = text.splitlines(keepends=True)
out, skip, removed = [], 0, 0
for line in lines:
    if skip:
        if line.strip() == "</bookmark>":
            skip = 0
        continue
    if 'href="smb://' in line:
        skip = 1
        removed += 1
        continue
    out.append(line)
text = "".join(out)

# 2) 幂等加入 Share 书签（放在 Home 之后 / 第一个非 Home 书签之前）
added = False
if f'href="{share_href}"' not in text:
    block = (
        f' <bookmark href="{share_href}">\n'
        '  <title>NFS 共享</title>\n'
        '  <info>\n'
        '   <metadata owner="http://freedesktop.org">\n'
        '    <bookmark:icon name="folder-network"/>\n'
        '   </metadata>\n'
        '   <metadata owner="http://www.kde.org">\n'
        '    <ID>azure-share-nfs/0</ID>\n'
        '   </metadata>\n'
        '  </info>\n'
        ' </bookmark>\n'
    )
    # 插在第一个 file:// 书签（通常是 Home）之后；找不到则插在第一个 </info> 段后兜底
    home = ' <bookmark href="file://' + os.environ["HOME"] + '">'
    idx = text.find(home)
    if idx != -1:
        end = text.find('</bookmark>', idx)
        end = text.find('\n', end) + 1
        text = text[:end] + block + text[end:]
    else:
        anchor = '</info>\n'
        i = text.find(anchor)
        text = text[:i+len(anchor)] + block + text[i+len(anchor):]
    added = True

# 3) 取消隐藏 Devices 组（显示本地磁盘，正常行为）
text = text.replace(
    "<GroupState-Devices-IsHidden>true</GroupState-Devices-IsHidden>",
    "<GroupState-Devices-IsHidden>false</GroupState-Devices-IsHidden>")

places.write_text(text, encoding="utf-8")
print(f"Places: Share 书签 {'已添加' if added else '已存在'}；移除 smb 残留 {removed} 个；Devices 组已显示")
PY

echo "提示：若 Dolphin 正在运行，需重启它（或重新登录）才会刷新 Places。"
echo "打开共享：~/bin/open-share.sh"
