# Moe Social (萌社交)

一个使用 Flutter 构建的可爱风格社交网络应用，旨在为用户提供现代化、直观且充满活力的社交体验。

## 功能特性

### 已实现功能
- 用户认证系统（登录/注册）
- 个人资料管理
- 基础设置配置
- 跨平台支持（Android、iOS、Web、Windows、macOS、Linux）

### 建议添加功能

#### 1. 个人资料增强
- ✨ 头像和封面图上传功能
- ✨ 个人简介和兴趣标签
- ✨ 动态背景和主题选择
- ✨ 在线状态显示
- ✨ 个性化资料卡设计

#### 2. 社交互动功能
- 💬 发布动态（文字、图片、视频）
- 👍 点赞、评论、分享功能
- 👥 关注/粉丝系统
- 💌 私信功能
- 🤝 好友请求系统

#### 3. 内容发现
- 🔍 搜索功能（用户、内容、标签）
- 📊 热门话题和标签
- 🎯 推荐算法（根据兴趣推荐用户和内容）
- 📋 分类浏览（根据内容类型或兴趣分类）

#### 4. 社区功能
- 🏘️ 兴趣小组或圈子
- 🎉 活动创建和参与
- 📈 排行榜（活跃度、人气等）
- 📣 社区公告和通知

#### 5. 个性化功能
- 🎨 主题切换（亮色/暗色/萌系主题）
- 🔔 推送通知设置
- 🔒 隐私设置
- 📱 字体大小和显示效果调整

#### 6. 娱乐功能
- 😊 表情包和贴纸功能
- 📸 滤镜和美颜功能
- 🎮 小游戏或互动功能
- 📅 签到和积分系统

#### 7. 实用功能
- 📝 笔记和收藏功能
- 🔄 多账号切换
- 💾 数据备份和恢复
- 📊 个人数据分析

## 快速开始

### 前提条件

- 已安装 Flutter SDK
- 已安装 Dart SDK
- 已安装 IDE（VS Code、Android Studio 或 IntelliJ IDEA）并配置 Flutter 插件

### 安装步骤
没有安装的话  （macOS 用户）
```bash
# 1. 安装 Flutter（会自动处理依赖和路径）
brew install flutter

# 2. 验证安装
flutter --version

# 3. 同样运行 doctor 检查环境
flutter doctor
```

1. 克隆仓库
2. 运行 `flutter pub get` 安装依赖
3. 运行 `flutter run` 启动应用

### 生产构建

- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`
- Windows: `flutter build windows`
- macOS: `flutter build macos`
- Linux: `flutter build linux`

## 🚀 CI/CD 与自动更新

本项目集成了 GitHub Actions 实现自动化构建与发布，并支持 App 内自动检测更新。

### 1. 自动构建发布
当推送形如 `v*` 的 Tag（例如 `v1.0.0`）到仓库时，会自动触发构建流程：
- 自动构建 Release APK
- 自动发布到 [GitHub Releases](https://github.com/xuxinzhi007/moe_social/releases)

**操作命令**：
```bash
git tag v1.0.3
git push origin v1.0.3
```

### 2. 产物下载
构建完成后，APK 文件会出现在 Releases 页面：
- **下载地址**: [Releases 页面](https://github.com/xuxinzhi007/moe_social/releases)
- **文件名**: `app-release.apk`

### 3. 检查更新
App 内置了更新检测功能：
- **检测原理**: 对比本地版本与 [GitHub API](https://api.github.com/repos/xuxinzhi007/moe_social/releases/latest) 返回的最新 Tag。
- **操作方式**: 进入 `设置` -> `常规设置` -> 点击 `软件版本` 即可手动检查。

### 4. 进阶：配置 Release 签名（解决覆盖安装问题）
默认情况下，GitHub Actions 使用临时签名，导致新版本无法覆盖旧版本（需卸载重装）。
若需实现平滑更新，请按以下步骤配置固定签名：

1.  **生成签名文件** (在终端执行)：
    ```bash
    keytool -genkey -v -keystore android/app/release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key -storepass 123456 -keypass 123456 -dname "CN=MoeSocial, OU=MoeSocial, O=MoeSocial, L=Unknown, S=Unknown, C=CN"
    ```

2.  **配置 Gradle** (`android/app/build.gradle.kts`)：
    ```kotlin
    signingConfigs {
        create("release") {
            keyAlias = "key"
            keyPassword = "123456"
            storeFile = file("release.jks")
            storePassword = "123456"
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    ```

3.  **允许提交签名文件**：
    修改 `.gitignore`，找到 `**/*.jks`，在前面加 `#` 注释掉。

4.  **提交代码**：将 `release.jks` 和修改后的 `build.gradle.kts` 推送到仓库。

## 项目结构

```
moe_social/
├── android/           # Android 平台特定代码
├── ios/               # iOS 平台特定代码
├── lib/               # 主要 Dart 源代码
│   ├── auth_service.dart   # 认证逻辑
│   ├── login_page.dart     # 登录页面
│   ├── main.dart           # 应用入口
│   ├── profile_page.dart   # 用户个人资料页面
│   ├── register_page.dart  # 注册页面
│   └── settings_page.dart  # 设置页面
├── linux/             # Linux 平台特定代码
├── macos/             # macOS 平台特定代码
├── test/              # 单元测试和 widget 测试
├── web/               # Web 平台特定代码
└── windows/           # Windows 平台特定代码
```

## 使用技术

- Flutter
- Dart
- Material Design

## 许可证

MIT License

## 贡献

欢迎贡献！请随时提交 Pull Request。

---

# Moe Social (English Version)

A cute-style social networking application built with Flutter, designed to provide users with a modern, intuitive, and vibrant social experience.

## Features

### Implemented Features
- User authentication system (login/register)
- Basic profile management
- Settings configuration
- Cross-platform support (Android, iOS, Web, Windows, macOS, Linux)

### Suggested Features to Add

#### 1. Enhanced Profile
- ✨ Avatar and cover image upload
- ✨ Personal bio and interest tags
- ✨ Dynamic backgrounds and theme selection
- ✨ Online status display
- ✨ Personalized profile card design

#### 2. Social Interaction
- 💬 Post updates (text, images, videos)
- 👍 Like, comment, share functionality
- 👥 Follow/follower system
- 💌 Private messaging
- 🤝 Friend request system

#### 3. Content Discovery
- 🔍 Search functionality (users, content, tags)
- 📊 Trending topics and tags
- 🎯 Recommendation algorithm (user and content recommendations based on interests)
- 📋 Category browsing (by content type or interest category)

#### 4. Community Features
- 🏘️ Interest groups or circles
- 🎉 Event creation and participation
- 📈 Leaderboards (activity, popularity, etc.)
- 📣 Community announcements and notifications

#### 5. Personalization
- 🎨 Theme switching (light/dark/cute themes)
- 🔔 Push notification settings
- 🔒 Privacy settings
- 📱 Font size and display adjustment

#### 6. Entertainment Features
- 😊 Emoji and sticker functionality
- 📸 Filters and beauty effects
- 🎮 Mini-games or interactive features
- 📅 Check-in and points system

#### 7. Utility Features
- 📝 Notes and favorites
- 🔄 Multiple account switching
- 💾 Data backup and recovery
- 📊 Personal data analysis

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK installed
- IDE (VS Code, Android Studio, or IntelliJ IDEA) with Flutter plugin

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the application

### Building for Production

- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`
- Windows: `flutter build windows`
- macOS: `flutter build macos`
- Linux: `flutter build linux`

## Project Structure

```
moe_social/
├── android/           # Android platform specific code
├── ios/               # iOS platform specific code
├── lib/               # Main Dart source code
│   ├── auth_service.dart   # Authentication logic
│   ├── login_page.dart     # Login screen
│   ├── main.dart           # App entry point
│   ├── profile_page.dart   # User profile screen
│   ├── register_page.dart  # Registration screen
│   └── settings_page.dart  # Settings screen
├── linux/             # Linux platform specific code
├── macos/             # macOS platform specific code
├── test/              # Unit and widget tests
├── web/               # Web platform specific code
└── windows/           # Windows platform specific code
```

## Technologies Used

- Flutter
- Dart
- Material Design

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
