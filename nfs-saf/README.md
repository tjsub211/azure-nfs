# AzureNFS —— 安卓 NFS 文档提供者（SAF）

把 PC 的 NFS 共享以 **Android 存储访问框架（SAF / DocumentsProvider）** 接入手机文件管理器。

> MiXplorer、Solid Explorer 等均**不支持** NFS。本 App 用纯 Java **[`com.emc.ecs:nfs-client`](https://github.com/EMCECS/nfs-client-java)**（NFSv3 over RPC，免 root），
> 在 `DocumentsProvider` 里实现目录列举与文件读写。

## 方案对比

| 方案 | 结论 |
|------|------|
| MiXplorer / Solid 原生 NFS | ❌ 不支持 |
| 内核 `mount -t nfs` | ❌ 通常需 root |
| **本 App：nfs-client-java + SAF** | ✅ 图形化读写、集成系统文件框架 |

## 架构

```
SettingsActivity ── 增删改连接 ──► ConnectionStore(SharedPreferences)
EditConnectionActivity                     │
                                           ▼
系统文件 / 第三方管理器 ──SAF──► NfsDocumentsProvider
                                           │
                                   NfsClientPool（NFSv3）
                                           ▼
                              PC NFS 服务器 :2049
```

## 构建 + 安装

```bash
# 手机 USB 调试；已连 PC 热点并能 ping 通网关
./build-and-install.sh
```

## 使用

1. 打开 AzureNFS →「+」→ 填 **PC 热点网关 IP**、`/export/azure-share`、uid/gid=1000 → 保存。
2. 系统「文件」侧栏选 AzureNFS，或在第三方管理器里添加「文档提供者」。

## 已知限制

- 仅 NFSv3。服务端需 `insecure,all_squash,anonuid=1000,anongid=1000`。
- 大目录列目录较慢；写入经本地 cache，关闭时回传。
