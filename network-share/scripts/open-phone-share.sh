#!/usr/bin/env bash
# [PC] 提示如何在手机上通过 AzureNFS App 访问共享
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo
echo "=== 手机访问 PC 共享（NFS）==="
echo "客户端:  AzureNFS App（Android SAF 文档提供者）"
echo "NFS:     <PC网关IP>:/export/azure-share"
echo
echo "构建+安装:  cd $PROJECT/nfs-saf && ./build-and-install.sh"
echo "使用:       App 内添加连接（主机填 PC 热点网关 IP）"
echo "详见:       $PROJECT/nfs-saf/README.md"
