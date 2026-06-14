#!/usr/bin/env bash
# 构建 AzureShare NFS（SAF 文档提供者）Debug APK 并通过 adb 安装到手机。
#
# 依赖（本机一次性）：
#   - JDK 17（如 Temurin: /usr/lib/jvm/temurin-17-jdk）
#   - Android SDK（platform-tools + platforms;android-34 + build-tools;34.0.0）
#     默认在 ~/Android/Sdk；首次安装见 README.md
#   - adb，手机 USB 调试，已连 PC 热点并能访问网关 IP
#
# 用法：  ./build-and-install.sh
set -euo pipefail
cd "$(dirname "$0")"

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/temurin-17-jdk}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

echo "[*] JAVA_HOME=$JAVA_HOME"
echo "[*] ANDROID_HOME=$ANDROID_HOME"

./gradlew assembleDebug --no-daemon
APK="app/build/outputs/apk/debug/app-debug.apk"
echo "[*] 构建完成: $APK"

if command -v adb >/dev/null 2>&1 && [ -n "$(adb devices | sed -n '2p')" ]; then
  adb install -r "$APK"
  echo "[OK] 已安装。打开 AzureNFS，添加连接（主机填 PC 热点网关 IP）。"
  echo "     之后在系统「文件」App 或任意支持「文档提供者」的文件管理器里即可访问。"
else
  echo "[!] 未检测到 adb 设备，跳过安装。可手动: adb install -r $APK"
fi
