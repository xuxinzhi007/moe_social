# Moe Auto — 原生 Android RPA

**Moe 专属** 免 Root 自动化工具（对标 [自动化编辑器](http://www.autoeditor.cn/) / 自动精灵 / 按键精灵 的 **执行引擎 + 脚本层**）。

> 当前放在 `moe_social/moe-auto/`，后续可整目录拆成独立仓库 `moe-auto-android`。

## 能力（MVP）

| 模块 | 说明 |
|------|------|
| **无障碍服务** | 点击、滑动、返回/Home、按文字/坐标操作 |
| **脚本引擎** | JSON 步骤列表，顺序执行，可循环 |
| **前台服务** | 脚本运行中保活 + 通知栏停止 |
| **Compose 控制台** | 权限引导、示例脚本、运行日志 |

## 环境准备

### 1. SDK 路径

本机完整 SDK 一般在：

```text
~/Library/Android/sdk
```

**不要**使用只有 `cmdline-tools` 的目录（例如错误的 `ANDROID_HOME=/Users/xxx/sdk/Android`）。

首次克隆后：

```bash
cp local.properties.example local.properties
# 编辑 sdk.dir 为你的 SDK 路径
```

已为你生成 `local.properties` 时可直接构建。

### 2. 推荐环境变量（写入 `~/.zshrc`）

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

### 3. 网络

- Gradle 发行包：腾讯云镜像（`gradle-wrapper.properties`）
- Maven 依赖：阿里云镜像（`settings.gradle.kts`）
- SDK 组件：**不联网自动下载**（`gradle.properties` 里 `android.builder.sdkDownload=false`），只用本机已装 Platform 36 + Build-Tools 36.1.0

### 4. 构建卡在 CONFIGURING / `dl.google.com` 超时？

**主要原因**：Gradle 在联网拉 Google SDK 清单，国内常会卡住；**不是 App 代码坏了**。

本项目已做两处规避：

1. `gradle.properties` → `android.builder.sdkDownload=false`（不自动联网下 SDK）
2. `compileSdk` 对齐本机 **android-36.1**（需 AGP **8.13.2+**）

处理步骤：

```bash
./scripts/ensure-sdk.sh          # 检查本机 SDK
./gradlew --stop
./gradlew :app:assembleDebug
```

本机需已安装（Android Studio → SDK Manager）：

- **Android SDK Platform 36.1**（目录 `platforms/android-36.1`）
- **Android SDK Build-Tools 36.1.0**

若仍卡在 `dl.google.com`：先 `Ctrl+C` 中断，改用 **Android Studio → Build → Build APK(s)**，或开代理后再编。

> 警告 `SDK XML versions up to 3 but version 4`：命令行 tools 与 Studio 版本不一致，一般**可忽略**，不影响出包。

### 5. 无 adb：只导出 APK 装手机

```bash
./gradlew :app:assembleDebug
```

APK：`app/build/outputs/apk/debug/app-debug.apk` →  AirDrop/微信传到手机安装即可。

## 测试与运行

### 方式 A：一键脚本（推荐）

连接 USB 调试的真机后：

```bash
cd moe-auto
./scripts/run-debug.sh
```

会依次：单元测试 → 编译 APK → 安装 → 启动 App。

### 方式 B：分步命令

```bash
cd moe-auto

# JVM 单元测试（脚本 JSON 解析，无需真机）
./gradlew :app:testDebugUnitTest

# 编译 Debug APK
./gradlew :app:assembleDebug

# 安装到已连接设备
./gradlew :app:installDebug

# 启动
adb shell am start -n com.moe.auto/.MainActivity
```

APK 路径：`app/build/outputs/apk/debug/app-debug.apk`

### 方式 C：Android Studio

1. **File → Open** → 选择 `moe-auto/`
2. 等待 Gradle Sync
3. 连接真机 → 点 **Run ▶**

### 真机功能验收

| 步骤 | 操作 | 预期 |
|------|------|------|
| 1 | 打开 Moe Auto | 主页与示例脚本列表 |
| 2 | 开启无障碍服务 | 状态显示「已开启」 |
| 3 | 运行「桌面滑动 + Home」 | 日志有步骤，桌面发生滑动 |
| 4 | 运行「打开系统设置」 | 系统设置被拉起 |
| 5 | 点停止 / 通知栏停止 | 脚本中断 |

查看原生日志：

```bash
adb logcat -s MoeAutoA11y
```

## 与 Flutter 主 App 的关系

- `android/.../AutoGLMService.kt`：历史实验，不再扩展。
- 新功能一律在 `moe-auto/` 实现。

## 脚本格式

见 `app/src/main/assets/scripts/` 与 `docs/script-format.md`。

## 文档

- [架构与路线图](docs/ARCHITECTURE.md)
- [脚本 DSL](docs/script-format.md)
