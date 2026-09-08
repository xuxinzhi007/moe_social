# API调试指南

## 🔍 已添加的调试功能

应用现在会在控制台输出详细的API请求和响应信息：

```
📡 API Request: POST http://...
📤 Request Body: {...}
📥 API Response: 200
📥 Response JSON: {...}
```

如果出错，会显示：
```
❌ 网络连接错误: ...
❌ 请求URL: ...
```

> 说明：为了避免刷屏与泄露敏感信息，现在默认**不再全量打印 Response Body**，而是输出**脱敏后的 JSON 摘要**：
> - `avatar/user_avatar/images/password` 等字段会显示为 `<omitted>`
> - 超长内容会自动截断

### 🔧 日志开关（需要更详细时再打开）

在 `lib/services/api_service.dart` 中：
- `_enableApiLog`: 是否开启 API 日志（仅 Debug 生效）
- `_verboseApiLog`: 是否输出超详细日志（会非常吵，默认关闭）

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

**症状**: 看到 `http://http://...` (重复的http://)，或改了地址但请求还是发往旧地址

**格式要求**（`lib/utils/config.dart` 的两个常量）：
- ✅ 正确: `http://47.106.175.49:8888`
- ❌ 错误: `http://http://47.106.175.49:8888`（重复 scheme）
- ❌ 错误: `http://47.106.175.49:8888/`（末尾斜杠）
- ❌ 错误: `http://47.106.175.49:8888/api`（带路径）

> ⚠️ **真正的坑是它不报错**：`ApiService._normalizeBaseUrl()`（`api_service.dart:172`）对格式不合法的地址返回 `null`，`_applyApiEnvironment()` 拿到 `null` 就**跳过赋值、保留上一个值**。所以写错地址的表现不是异常，而是「请求发往一个你没填过的地址」。
> `test/utils/config_test.dart` 有一条专门断言两个 URL 都是 `http(s)`、host 非空、无路径、无末尾斜杠，就是为了在 CI 里把这类静默失败变成红灯。

### 3. CORS跨域问题

**症状**: 浏览器控制台显示CORS错误

**解决方法**: 后端已配置CORS，确保后端服务已重启

### 4. 真机 / 模拟器连接本地服务

**基址只有一处**：`lib/utils/config.dart` → `ApiEnvConfig.developmentUrl`。改完**完整重启** App（Stop + Run），const 不参与热重载。

> ⚠️ 旧文档里「按 `Platform.isAndroid` 分支返回地址」「模拟器自动使用 `10.0.2.2` / `localhost`，无需修改配置」的机制**已不存在**。现在没有按平台自动选择，模拟器也不会自动帮你换地址——填错就是连不上。

1. 获取电脑 IP：
   ```bash
   # Windows
   ipconfig

   # Mac/Linux
   ifconfig
   ```

2. 按下表填 `developmentUrl`：

   | 运行目标 | `developmentUrl` 填什么 |
   |----------|------------------------|
   | Android 真机 / iOS 真机 | `http://<电脑局域网IP>:8888`（手机与电脑同一网段） |
   | Android 模拟器 | `http://10.0.2.2:8888`（`10.0.2.2` 是模拟器里的宿主机别名） |
   | iOS 模拟器 | `http://127.0.0.1:8888`（与宿主机共享网络栈） |
   | Web（Chrome） | `http://127.0.0.1:8888` |

   > `127.0.0.1` 在**真机**上指向手机自己，永远连不上电脑，这是最常见的一个坑。

3. 或者直接切到线上：把 `ApiEnvConfig.isProduction` 改为 `true`，走 `productionUrl`（见下节）。

## 📱 不同环境的API地址配置

| 环境 | 取哪个常量 | 当前值 |
|------|-----------|--------|
| 本地（`isProduction = false`） | `ApiEnvConfig.developmentUrl` | `http://192.168.124.36:8888`（开发机局域网 IP，换机器/换网段要改） |
| 线上（`isProduction = true`） | `ApiEnvConfig.productionUrl` | `http://47.106.175.49:8888` |

所有平台共用这两个常量，没有按平台分叉。若临时用穿透域名（cpolar / ngrok），把它填进 `productionUrl`，`ApiService` 会自动附加隧道绕过头；隧道失效就更新该值。

细节与发版把关见 [环境配置说明.md](./环境配置说明.md)。

## 🔧 快速切换环境

改 `lib/utils/config.dart`：

```dart
class ApiEnvConfig {
  static const bool isProduction = false; // true = 线上；false = 本地
}
```

改完完整重启 App。**不要**再去 `lib/services/api_service.dart` 找 `_isProduction`——那个字段已经删除，`api_service.dart` 只在启动时通过 `ApiService.initBaseUrl()` 读取 `ApiEnvConfig`。

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

4. **临时切到线上 API 验证**
   - 如果本地连接有问题，可以临时连线上环境排查
   - 在 `lib/utils/config.dart` 把 `ApiEnvConfig.isProduction` 改为 `true`
   - `const` 不参与热重载，改完必须 **Stop + Run 完整重启** App
   - 验证完记得改回 `false`：发版 CI 会断言它为 `true`，但日常开发提交应保持 `false`

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

