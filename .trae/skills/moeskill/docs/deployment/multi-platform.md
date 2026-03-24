# 多平台构建指南

## 概述

Moe Social项目支持多个平台，包括Android、iOS、Web、Windows、macOS和Linux。本指南将详细介绍如何为不同平台构建应用。

## 支持的平台

| 平台 | 支持状态 | 构建命令 |
|------|----------|----------|
| Android | ✅ 支持 | `flutter build apk` |
| iOS | ✅ 支持 | `flutter build ios` |
| Web | ✅ 支持 | `flutter build web` |
| Windows | ✅ 支持 | `flutter build windows` |
| macOS | ✅ 支持 | `flutter build macos` |
| Linux | ✅ 支持 | `flutter build linux` |

## 环境准备

### 通用环境

1. **Flutter SDK**：安装最新版本的Flutter SDK
2. **Dart SDK**：Flutter会自动安装Dart SDK
3. **Git**：用于版本控制

### 平台特定环境

#### Android

- **Android Studio**：安装Android Studio
- **Android SDK**：安装Android SDK
- **Java JDK**：安装Java JDK 8或更高版本

#### iOS

- **macOS**：需要macOS操作系统
- **Xcode**：安装Xcode 13或更高版本
- **CocoaPods**：安装CocoaPods

#### Web

- **Chrome**：用于Web开发和测试
- **Web服务器**：可选，用于本地测试

#### Windows

- **Windows 10或更高版本**
- **Visual Studio**：安装Visual Studio 2022或更高版本，包含"使用C++的桌面开发"工作负载

#### macOS

- **macOS 10.15或更高版本**
- **Xcode**：安装Xcode 13或更高版本

#### Linux

- **Ubuntu 18.04或更高版本**
- **CMake**：安装CMake 3.10或更高版本
- **Ninja**：安装Ninja构建系统
- **GTK开发库**：安装GTK 3开发库

## 构建步骤

### 1. 准备项目

```bash
# 克隆项目
git clone https://github.com/yourusername/moe_social.git
cd moe_social

# 安装依赖
flutter pub get

# 生成必要的文件
flutter pub run build_runner build
```

### 2. 构建Android应用

```bash
# 构建debug版本
flutter build apk

# 构建release版本
flutter build apk --release

# 构建特定架构
flutter build apk --release --target-platform android-arm64
```

构建结果位于 `build/app/outputs/apk/release/app-release.apk`

### 3. 构建iOS应用

```bash
# 构建debug版本
flutter build ios

# 构建release版本
flutter build ios --release

# 构建特定架构
flutter build ios --release --target-platform ios-arm64
```

构建结果位于 `build/ios/iphoneos/Runner.app`

### 4. 构建Web应用

```bash
# 构建debug版本
flutter build web

# 构建release版本
flutter build web --release

# 构建特定模式
flutter build web --release --web-renderer canvaskit
```

构建结果位于 `build/web` 目录

### 5. 构建Windows应用

```bash
# 构建debug版本
flutter build windows

# 构建release版本
flutter build windows --release
```

构建结果位于 `build/windows/runner/Release` 目录

### 6. 构建macOS应用

```bash
# 构建debug版本
flutter build macos

# 构建release版本
flutter build macos --release
```

构建结果位于 `build/macos/Build/Products/Release` 目录

### 7. 构建Linux应用

```bash
# 构建debug版本
flutter build linux

# 构建release版本
flutter build linux --release
```

构建结果位于 `build/linux/x64/release/bundle` 目录

## 平台特定配置

### Android配置

#### 应用签名

1. **创建签名密钥**：
   ```bash
   keytool -genkey -v -keystore moe_social.keystore -alias moe_social -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **配置签名**：在 `android/app/build.gradle` 中添加签名配置
   ```gradle
   android {
       ...
       signingConfigs {
           release {
               storeFile file('moe_social.keystore')
               storePassword 'your_store_password'
               keyAlias 'moe_social'
               keyPassword 'your_key_password'
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               ...
           }
       }
   }
   ```

#### 权限配置

在 `android/app/src/main/AndroidManifest.xml` 中配置权限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- 其他权限 -->
</manifest>
```

### iOS配置

#### 应用签名

1. **创建证书**：在Apple Developer Portal创建开发和分发证书
2. **配置Provisioning Profiles**：为应用创建Provisioning Profiles
3. **配置Xcode**：在Xcode中配置签名设置

#### 权限配置

在 `ios/Runner/Info.plist` 中配置权限：

```xml
<key>NSCameraUsageDescription</key>
<string>需要访问相机来扫描二维码</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册来选择图片</string>
<!-- 其他权限 -->
```

### Web配置

#### 域名配置

在 `web/index.html` 中配置域名和标题：

```html
<title>Moe Social</title>
<base href="/">
```

#### PWA配置

在 `web/manifest.json` 中配置PWA设置：

```json
{
  "name": "Moe Social",
  "short_name": "Moe Social",
  "description": "Moe Social - 社交应用",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#4285f4",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

### Windows配置

#### 应用图标

在 `windows/runner/resources` 中替换应用图标

#### 应用清单

在 `windows/runner/Runner.rc` 中配置应用信息：

```rc
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904b0"
        BEGIN
            VALUE "CompanyName", "Moe Social"
            VALUE "FileDescription", "Moe Social Application"
            VALUE "FileVersion", "1.0.0.0"
            VALUE "InternalName", "Moe Social"
            VALUE "LegalCopyright", "Copyright (C) 2023 Moe Social"
            VALUE "OriginalFilename", "moe_social.exe"
            VALUE "ProductName", "Moe Social"
            VALUE "ProductVersion", "1.0.0.0"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END
```

### macOS配置

#### 应用图标

在 `macos/Runner/Assets.xcassets/AppIcon.appiconset` 中替换应用图标

#### 应用信息

在Xcode中配置应用信息：
1. 打开 `macos/Runner.xcworkspace`
2. 选择Runner目标
3. 在"General"标签页中配置应用信息

### Linux配置

#### 应用图标

在 `linux/runner/data/icons` 中替换应用图标

#### 应用信息

在 `linux/runner/CMakeLists.txt` 中配置应用信息：

```cmake
set(APPLICATION_NAME "Moe Social")
set(APPLICATION_VERSION "1.0.0")
set(APPLICATION_DESCRIPTION "Moe Social Application")
```

## 性能优化

### 平台特定优化

#### Android

- **启用R8混淆**：在 `android/app/build.gradle` 中启用R8混淆
- **使用AAB格式**：使用Android App Bundle格式减小应用大小
- **配置ProGuard**：使用ProGuard进一步减小应用大小

#### iOS

- **启用bitcode**：在Xcode中启用bitcode
- **使用App Thinning**：利用App Thinning减小应用大小
- **优化资源**：压缩图片和其他资源

#### Web

- **使用canvaskit渲染器**：对于复杂应用使用canvaskit渲染器
- **启用缓存**：配置浏览器缓存
- **优化资源**：压缩JavaScript和CSS文件

#### 桌面平台

- **优化启动时间**：减少启动时的资源加载
- **使用原生组件**：对于性能敏感的部分使用原生组件
- **内存管理**：合理管理内存使用

## 测试策略

### 平台特定测试

#### Android

- **设备测试**：在不同Android设备上测试
- ** emulator测试**：使用Android模拟器测试
- **兼容性测试**：测试不同Android版本的兼容性

#### iOS

- **设备测试**：在不同iOS设备上测试
- **模拟器测试**：使用iOS模拟器测试
- **App Store审核测试**：模拟App Store审核流程

#### Web

- **浏览器测试**：在不同浏览器中测试
- **响应式测试**：测试不同屏幕尺寸
- **性能测试**：测试Web性能

#### 桌面平台

- **功能测试**：测试桌面特定功能
- **性能测试**：测试桌面性能
- **用户体验测试**：测试桌面用户体验

## 发布策略

### 应用商店发布

#### Android

1. **创建应用**：在Google Play Console创建应用
2. **上传AAB**：上传Android App Bundle
3. **填写信息**：填写应用信息和截图
4. **提交审核**：提交应用审核

#### iOS

1. **创建应用**：在App Store Connect创建应用
2. **上传IPA**：使用Xcode或Transporter上传IPA
3. **填写信息**：填写应用信息和截图
4. **提交审核**：提交应用审核

#### Web

1. **选择托管服务**：选择Web托管服务
2. **部署应用**：部署Web应用
3. **配置域名**：配置自定义域名
4. **设置HTTPS**：启用HTTPS

#### 桌面平台

1. **创建安装包**：创建平台特定的安装包
2. **分发渠道**：选择分发渠道
3. **更新机制**：实现自动更新机制
4. **签名验证**：对应用进行签名

## 常见问题

### Android构建问题

- **构建失败**：检查依赖和配置
- **签名错误**：检查签名配置
- **权限问题**：检查权限配置

### iOS构建问题

- **证书问题**：检查证书和Provisioning Profiles
- **依赖问题**：检查CocoaPods依赖
- **Xcode配置**：检查Xcode配置

### Web构建问题

- **资源加载**：检查资源路径
- **浏览器兼容性**：检查浏览器兼容性
- **性能问题**：优化Web性能

### 桌面平台构建问题

- **依赖问题**：检查平台特定依赖
- **编译错误**：检查代码中的平台特定代码
- **打包问题**：检查打包配置

## 总结

多平台构建是Moe Social项目的重要特性，通过Flutter的跨平台能力，可以在多个平台上构建统一的应用体验。本指南提供了详细的多平台构建步骤和最佳实践，帮助开发者顺利构建和发布应用。

在实际开发中，应根据目标平台的特性和要求，选择合适的构建策略和优化方案，确保应用在各平台上都能提供良好的用户体验。