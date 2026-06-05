#!/usr/bin/env bash
# 编译、安装并启动 Moe Auto（需已连接真机且 adb 可用）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f local.properties ]]; then
  if [[ -d "${HOME}/Library/Android/sdk" ]]; then
    echo "sdk.dir=${HOME}/Library/Android/sdk" > local.properties
    echo "已生成 local.properties → ${HOME}/Library/Android/sdk"
  else
    echo "请先复制 local.properties.example 为 local.properties 并填写 sdk.dir"
    exit 1
  fi
fi

echo "==> 单元测试"
./gradlew :app:testDebugUnitTest --no-daemon

echo "==> 编译 Debug APK"
./gradlew :app:assembleDebug --no-daemon

ADB="${ANDROID_HOME:-${HOME}/Library/Android/sdk}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
  ADB="$(command -v adb || true)"
fi

if [[ -z "$ADB" || ! -x "$ADB" ]]; then
  echo "未找到 adb，请安装 platform-tools 或设置 ANDROID_HOME"
  echo "APK: app/build/outputs/apk/debug/app-debug.apk"
  exit 0
fi

DEVICE_COUNT="$("$ADB" devices | awk 'NR>1 && $2=="device" { c++ } END { print c+0 }')"
if [[ "$DEVICE_COUNT" -lt 1 ]]; then
  echo "未检测到已连接设备。APK 已生成："
  echo "  app/build/outputs/apk/debug/app-debug.apk"
  exit 0
fi

echo "==> 安装到设备"
./gradlew :app:installDebug --no-daemon

echo "==> 启动 App"
"$ADB" shell am start -n com.moe.auto/.MainActivity
# 运行脚本请在 App 内选择；导入/新建见「脚本列表」

echo ""
echo "真机测试：开启「Moe Auto」无障碍服务后，在 App 内运行示例脚本。"
