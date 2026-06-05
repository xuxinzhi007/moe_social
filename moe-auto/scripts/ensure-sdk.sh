#!/usr/bin/env bash
# 检查本机 SDK 是否满足 moe-auto 构建（Platform 36.1 + Build-Tools 36.1.0）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROPS="$ROOT/local.properties"

if [[ -f "$PROPS" ]]; then
  SDK_DIR="$(grep -E '^sdk\.dir=' "$PROPS" | cut -d= -f2- | sed 's/\\:/:/g')"
else
  SDK_DIR="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
fi

echo "SDK 路径: $SDK_DIR"
MISS=0

if [[ ! -d "$SDK_DIR/platforms/android-36.1" ]]; then
  echo "❌ 缺少 platforms/android-36.1"
  echo "   → Android Studio → SDK Manager → 安装 Android SDK Platform 36.1"
  MISS=1
else
  echo "✅ platforms/android-36.1"
fi

if [[ ! -d "$SDK_DIR/build-tools/36.1.0" ]]; then
  echo "❌ 缺少 build-tools/36.1.0"
  echo "   → SDK Manager → 安装 Android SDK Build-Tools 36.1.0"
  MISS=1
else
  echo "✅ build-tools/36.1.0"
fi

if [[ $MISS -ne 0 ]]; then
  exit 1
fi

echo "SDK 检查通过，可执行: ./gradlew :app:assembleDebug"
