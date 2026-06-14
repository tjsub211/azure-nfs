#!/usr/bin/env bash
# [PC] 安装 NFS 共享所需系统包（Nobara/Fedora）
set -euo pipefail

echo "==> 安装 nfs-utils（exportfs、showmount、mount.nfs 等）"
sudo dnf install -y nfs-utils

echo "==> 启用 rpcbind（NFS 依赖）"
sudo systemctl enable --now rpcbind

echo
echo "已安装："
rpm -q nfs-utils rpcbind
command -v exportfs showmount mount.nfs
