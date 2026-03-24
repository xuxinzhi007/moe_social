# 项目初始化

## 前端初始化

### 前提条件
- Flutter SDK 3.0+
- Dart SDK
- IDE（VS Code、Android Studio 或 IntelliJ IDEA）并配置 Flutter 插件

### 安装步骤
1. **克隆仓库**
   ```bash
   git clone https://github.com/xuxinzhi007/moe_social.git
   cd moe_social
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   flutter run
   ```

## 后端初始化（go-zero框架）

### 前提条件
- Go 1.25+
- MySQL 5.7+
- Ollama 服务（默认端口11434）

### 安装步骤
1. **进入后端目录**
   ```bash
   cd backend
   ```

2. **安装Go依赖**
   ```bash
   go mod tidy
   ```

3. **配置数据库**
   - 确保MySQL服务已启动
   - 创建数据库：
     ```sql
     CREATE DATABASE go_react_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
     ```

4. **配置环境**
   - 编辑 `config/config.yaml` 文件，设置数据库连接信息
   - 默认配置：
     ```yaml
     database:
       host: "127.0.0.1"
       port: 3306
       user: "root"
       password: "123456"
       dbname: "go_react_demo"
       charset: "utf8mb4"
       parseTime: true
       loc: "Local"
     ```

5. **运行后端服务**
   ```bash
   cd api
   go run super.go
   ```

## Android 开发环境注意事项

Android 模拟器/真机无法直接访问开发机的 `localhost`，项目使用 **cpolar** 内网穿透。

`lib/services/api_service.dart` 中 `_isProduction = false` 时，Android 的 `baseUrl` 是一个 cpolar 生成的公网域名（如 `https://xxxxx.cpolar.cn`）。

**每次重启 cpolar 后域名会变**，需要更新 `api_service.dart` 中对应的 Android dev URL。Web/Windows 调试不受影响，直接用 `localhost:8888`。

---

## 验证初始化

- **前端**：应用启动后，可以看到登录/注册页面
- **后端**：服务启动后，API服务运行在 `http://0.0.0.0:8888`
- **数据库**：可以通过MySQL客户端连接到 `go_react_demo` 数据库

## 常见问题

1. **Flutter依赖安装失败**
   - 确保网络连接正常
   - 尝试使用国内镜像：`flutter pub get --pub-hosted-url=https://pub.flutter-io.cn`

2. **后端服务启动失败**
   - 检查MySQL服务是否运行
   - 验证数据库连接配置是否正确
   - 确保Ollama服务已启动

3. **端口占用**
   - 前端：默认使用5000端口
   - 后端：默认使用8888端口
   - 如果端口被占用，可以修改配置文件中的端口设置

## 下一步

初始化完成后，您可以：
- 查看 [开发环境配置](./environment.md) 了解更多环境设置
- 开始实现新功能或修复Bug
- 配置CI/CD流程准备发布