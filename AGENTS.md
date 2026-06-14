# Agent 入口

NFS 共享：PC `network-share/` + 热点 `pc-hotspot/` → 手机 `nfs-saf/` App。

```bash
~/bin/pc-hotspot-toggle.sh
cd nfs-saf && ./build-and-install.sh
```

查手机 IP：`adb shell ip -4 -o addr show wlan0`（需 USB 调试时）。
