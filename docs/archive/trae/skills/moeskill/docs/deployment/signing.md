# 应用签名配置

## 概述

应用签名是确保应用安全性和完整性的重要步骤，特别是在发布到应用商店时。本指南将详细介绍Moe Social项目的应用签名配置方法。

## Android 签名配置

### 1. 生成签名密钥

使用 `keytool` 命令生成签名密钥：

```bash
keytool -genkey -v -keystore moe_social.keystore -alias moe_social -keyalg RSA -keysize 2048 -validity 10000
```

执行此命令后，会提示你输入以下信息：
- 密钥库密码
- 密钥密码（可以与密钥库密码相同）
- 姓名
- 组织单位
- 组织
- 城市或地区
- 州或省份
- 国家代码

### 2. 配置签名信息

在 `android/app/build.gradle` 文件中添加签名配置：

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

### 3. 安全存储密钥

为了安全起见，不应该将密钥密码硬编码在构建文件中。建议使用以下方法：

#### 使用环境变量

```gradle
android {
    ...
    signingConfigs {
        release {
            storeFile file('moe_social.keystore')
            storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias 'moe_social'
            keyPassword System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
}
```

#### 使用属性文件

创建 `local.properties` 文件：

```properties
storePassword=your_store_password
keyPassword=your_key_password
```

然后在 `build.gradle` 中读取：

```gradle
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

android {
    ...
    signingConfigs {
        release {
            storeFile file('moe_social.keystore')
            storePassword localProperties.getProperty('storePassword')
            keyAlias 'moe_social'
            keyPassword localProperties.getProperty('keyPassword')
        }
    }
}
```

### 4. 构建签名APK

```bash
flutter build apk --release
```

构建结果位于 `build/app/outputs/apk/release/app-release.apk`

## iOS 签名配置

### 1. 准备工作

- **Apple Developer Account**：需要一个Apple开发者账号
- **证书**：创建开发和分发证书
- **Provisioning Profiles**：为应用创建Provisioning Profiles

### 2. 在Apple Developer Portal创建证书

1. 登录 [Apple Developer Portal](https://developer.apple.com/account/)
2. 导航到 "Certificates, Identifiers & Profiles"
3. 选择 "Certificates" → "+"
4. 选择 "iOS Distribution (App Store and Ad Hoc)" 或 "iOS Development"
5. 按照提示创建证书

### 3. 创建App ID

1. 在 "Identifiers" 中选择 "App IDs" → "+"
2. 输入应用名称和Bundle ID
3. 选择应用所需的服务和权限
4. 保存App ID

### 4. 创建Provisioning Profile

1. 在 "Profiles" 中选择 "+"
2. 选择 "App Store"、"Ad Hoc" 或 "Development"
3. 选择之前创建的App ID
4. 选择证书
5. 选择设备（对于Development和Ad Hoc）
6. 命名并下载Provisioning Profile

### 5. 在Xcode中配置签名

1. 打开 `ios/Runner.xcworkspace`
2. 选择 "Runner" 目标
3. 在 "Signing & Capabilities" 标签页中：
   - 选择 "Automatically manage signing"
   - 选择Team
   - Xcode会自动管理证书和Provisioning Profiles

### 6. 构建签名IPA

```bash
flutter build ios --release
```

然后使用Xcode或Transporter上传IPA到App Store Connect。

## Web 签名配置

Web应用不需要像移动应用那样进行签名，但需要确保以下安全措施：

### 1. HTTPS配置

- 确保网站使用HTTPS
- 配置SSL证书
- 强制HTTPS重定向

### 2. PWA配置

在 `web/manifest.json` 中配置PWA信息：

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

### 3. 内容安全策略

在 `web/index.html` 中添加内容安全策略：

```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self';">
```

## 桌面平台签名配置

### Windows 签名

#### 1. 获取代码签名证书

- 从证书颁发机构（CA）获取代码签名证书
- 可以使用自签名证书进行测试，但在生产环境中应该使用CA颁发的证书

#### 2. 签名应用

使用 `signtool.exe` 签名应用：

```bash
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com /d "Moe Social" build/windows/runner/Release/moe_social.exe
```

### macOS 签名

#### 1. 获取开发者证书

- 在Apple Developer Portal创建开发者证书
- 在Keychain Access中安装证书

#### 2. 签名应用

使用 `codesign` 签名应用：

```bash
codesign --deep --force --verbose --sign "Developer ID Application: Your Name" build/macos/Build/Products/Release/Moe Social.app
```

#### 3. 公证应用

在macOS 10.14.5及以上版本，需要对应用进行公证：

```bash
xcrun altool --notarize-app --primary-bundle-id "com.moe.social" --username "your_apple_id" --password "your_app_specific_password" --file MoeSocial.dmg
```

### Linux 签名

Linux应用签名不是强制的，但可以使用GPG进行签名：

```bash
gpg --detach-sign --armor build/linux/x64/release/bundle/moe_social
```

## 签名最佳实践

### 1. 密钥管理

- **安全存储**：将签名密钥存储在安全的位置
- **备份**：定期备份签名密钥
- **访问控制**：限制对签名密钥的访问
- **轮换**：定期轮换签名密钥

### 2. 构建流程

- **自动化**：在CI/CD流程中自动化签名过程
- **环境变量**：使用环境变量存储密钥密码
- **日志**：记录签名过程
- **验证**：验证签名是否成功

### 3. 安全性

- **使用强密码**：为密钥库和密钥使用强密码
- **定期更新**：定期更新签名证书
- **审计**：定期审计签名过程
- **合规**：确保签名过程符合应用商店的要求

## 常见问题

### Android 签名问题

- **密钥库文件丢失**：如果密钥库文件丢失，将无法更新应用。请确保备份密钥库文件。
- **密码忘记**：如果忘记密钥库或密钥密码，将无法更新应用。请确保记录密码。
- **证书过期**：如果证书过期，需要创建新的签名密钥和证书。

### iOS 签名问题

- **证书过期**：证书过期后需要重新创建。
- **Provisioning Profile 过期**：Provisioning Profile过期后需要重新创建。
- **Team 变更**：如果更换了Apple Developer Team，需要更新签名配置。

### 桌面平台签名问题

- **证书过期**：证书过期后需要更新。
- **签名验证失败**：确保使用正确的证书和密码。
- **公证失败**：确保应用符合Apple的公证要求。

## 总结

应用签名是确保应用安全性和完整性的重要步骤，也是发布到应用商店的必要条件。本指南提供了详细的签名配置步骤和最佳实践，帮助开发者顺利完成应用签名过程。

在实际开发中，应根据目标平台的要求，正确配置签名信息，并确保签名密钥的安全管理，以确保应用能够成功发布和更新。