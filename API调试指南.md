# API调试指南

## 🔍 已添加的调试功能

应用现在会在控制台输出详细的API请求和响应信息：

```
📡 API Request: POST http://...
📤 Request Body: {...}
📥 API Response: 200
📥 Response Body: {...}
```

如果出错，会显示：
```
❌ 网络连接错误: ...
❌ 请求URL: ...
```

## 🐛 常见API调用失败原因

### 1. 网络连接问题

**症状**: 看到 `无法连接到服务器` 或 `Socket错误`

**检查清单**:
- [ ] 后端服务是否正在运行？
- [ ] API地址是否正确？
- [ ] 网络是否正常？

**解决方法**:
```bash
# 检查后端服务
curl http://localhost:8888/api/user/login

# 或者使用浏览器访问
# http://localhost:8888/api/user/login
```

### 2. API地址配置错误

**症状**: 看到 `http://http://...` (重复的http://)

**解决方法**: 已修复，确保API地址格式正确：
- ✅ 正确: `http://74fd3e66.r3.cpolar.top`
- ❌ 错误: `http://http://74fd3e66.r3.cpolar.top`

### 3. CORS跨域问题

**症状**: 浏览器控制台显示CORS错误

**解决方法**: 后端已配置CORS，确保后端服务已重启

### 4. 真机连接本地服务

**Android真机需要配置电脑IP**:

1. 获取电脑IP地址:
   ```bash
   # Windows
   ipconfig
   
   # Mac/Linux
   ifconfig
   ```

2. 修改 `lib/services/api_service.dart` 第50行:
   ```dart
   } else if (Platform.isAndroid) {
     return 'http://192.168.1.16:8888'; // 替换为你的电脑IP
   }
   ```

3. 或者使用生产环境地址:
   ```dart
   static const bool _isProduction = true; // 使用生产环境
   ```

### 5. 模拟器连接本地服务

**Android模拟器**:
- 自动使用 `http://10.0.2.2:8888`
- 无需修改配置

**iOS模拟器**:
- 自动使用 `http://localhost:8888`
- 无需修改配置

## 📱 不同环境的API地址配置

### 开发环境（本地）

| 平台 | API地址 | 说明 |
|------|---------|------|
| Web | `http://localhost:8888` | 浏览器直接访问 |
| Android模拟器 | `http://10.0.2.2:8888` | 自动配置 |
| Android真机 | `http://你的电脑IP:8888` | 需要手动配置 |
| iOS模拟器 | `http://localhost:8888` | 自动配置 |
| iOS真机 | `http://你的电脑IP:8888` | 需要手动配置 |

### 生产环境（cpolar隧道）

| 平台 | API地址 | 说明 |
|------|---------|------|
| 所有平台 | `http://74fd3e66.r3.cpolar.top` | 统一使用 |

## 🔧 快速切换环境

在 `lib/services/api_service.dart` 第27行：

```dart
// 开发环境
static const bool _isProduction = false;

// 生产环境
static const bool _isProduction = true;
```

## 🧪 测试API连接

### 方法1：使用curl

```bash
# 测试登录接口
curl -X POST http://localhost:8888/api/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"12345678"}'
```

### 方法2：使用浏览器

访问: `http://localhost:8888/api/user/login`

### 方法3：查看应用日志

运行应用后，查看控制台输出：
```bash
flutter logs
```

会显示：
- 📡 API请求信息
- 📥 API响应信息
- ❌ 错误信息（如果有）

## 💡 调试技巧

1. **先测试后端服务**
   - 确保后端API可以正常访问
   - 使用curl或浏览器测试

2. **查看应用日志**
   - 运行 `flutter logs` 查看详细日志
   - 关注API请求和响应信息

3. **检查网络权限**
   - Android: 确认 `AndroidManifest.xml` 中有 `INTERNET` 权限
   - iOS: 确认 `Info.plist` 配置正确

4. **使用生产环境测试**
   - 如果本地连接有问题，临时使用生产环境地址
   - 设置 `_isProduction = true`

## 🆘 如果还是失败

1. **查看完整错误日志**
   ```bash
   flutter logs > api_error.log
   # 运行应用，尝试登录
   # 查看api_error.log文件
   ```

2. **检查后端日志**
   - 查看后端控制台输出
   - 确认请求是否到达后端

3. **测试网络连接**
   ```bash
   # 从设备/模拟器测试连接
   ping 10.0.2.2  # Android模拟器
   ping 你的电脑IP  # 真机
   ```

4. **发送错误信息**
   - 复制完整的错误日志
   - 包含API请求和响应信息

