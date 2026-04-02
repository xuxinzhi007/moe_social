# Android真机调试说明

## ✅ 已修复的问题

### 1. 网络权限
- ✅ 添加了 `INTERNET` 权限到 `AndroidManifest.xml`
- ✅ 允许HTTP明文流量 (`usesCleartextTraffic="true"`)

### 2. API地址配置
- ✅ 根据平台自动选择API地址
  - Web: `http://localhost:8888`
  - Android模拟器: `http://10.0.2.2:8888`
  - Android真机: **需要修改为电脑的实际IP地址**

### 3. 错误处理
- ✅ 添加了全局错误捕获

## 🔧 Android真机调试步骤

### 步骤1：获取电脑IP地址

**Windows:**
```bash
ipconfig
```
查找 "IPv4 地址"，例如：`192.168.1.16`

**Mac/Linux:**
```bash
ifconfig
# 或
ip addr
```

### 步骤2：修改API地址

在 `lib/services/api_service.dart` 中，找到：

```dart
} else if (Platform.isAndroid) {
  // Android模拟器使用10.0.2.2，真机需要使用电脑IP
  // TODO: 真机测试时需要修改为电脑的实际IP地址
  // 例如：return 'http://192.168.1.16:8888';
  return 'http://10.0.2.2:8888'; // Android模拟器
}
```

**修改为：**
```dart
} else if (Platform.isAndroid) {
  // 真机测试时使用电脑的实际IP地址
  return 'http://192.168.1.16:8888'; // 替换为你的电脑IP
  // return 'http://10.0.2.2:8888'; // Android模拟器使用这个
}
```

### 步骤3：确保后端服务可访问

1. **确保后端API服务正在运行**（端口8888）
2. **确保防火墙允许8888端口**
3. **确保手机和电脑在同一WiFi网络**

### 步骤4：重新构建APK

```bash
flutter clean
flutter build apk --debug
```

### 步骤5：安装并测试

```bash
# 安装到连接的设备
flutter install

# 或手动安装
adb install build\app\outputs\flutter-apk\app-debug.apk
```

## 🐛 调试技巧

### 查看日志

```bash
# 查看Flutter日志
flutter logs

# 查看Android日志
adb logcat | grep flutter
```

### 常见问题

1. **仍然无法连接**
   - 检查手机和电脑是否在同一WiFi
   - 检查防火墙设置
   - 尝试ping电脑IP地址

2. **仍然闪退**
   - 查看日志：`flutter logs` 或 `adb logcat`
   - 检查是否有未捕获的异常

3. **网络超时**
   - 确认后端服务正在运行
   - 确认IP地址正确
   - 确认端口8888可访问

## 📝 建议

### 开发环境配置

可以创建不同环境的配置文件：

```dart
// lib/config/app_config.dart
class AppConfig {
  static const bool isDebug = true;
  
  static String get baseUrl {
    if (isDebug) {
      // 开发环境
      if (Platform.isAndroid) {
        return 'http://192.168.1.16:8888'; // 真机
        // return 'http://10.0.2.2:8888'; // 模拟器
      }
    }
    // 生产环境
    return 'https://api.yourdomain.com';
  }
}
```

### 使用环境变量

可以通过编译时参数传递：

```bash
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.16:8888
```

然后在代码中：
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8888',
);
```


