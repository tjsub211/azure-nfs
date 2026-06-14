# NFS 共享（PC 服务端）

配合 [`pc-hotspot`](../pc-hotspot/) 热点与 [`nfs-saf`](../nfs-saf/) 手机 App。

```bash
bash scripts/setup-network-share.sh
~/bin/pc-hotspot-toggle.sh
```

`~/Share` bind 到 `/export/azure-share`，`reload-nfs.sh` 随热点启停 `nfs-server`。
