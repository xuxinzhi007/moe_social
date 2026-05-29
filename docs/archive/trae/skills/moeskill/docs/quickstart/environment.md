# 开发环境配置

## 前端开发环境

### Flutter SDK 安装

#### Windows
1. 访问 [Flutter官网](https://flutter.dev/docs/get-started/install/windows)
2. 下载Flutter SDK
3. 解压到指定目录（如 `C:\flutter`）
4. 添加 `flutter\bin` 到系统环境变量

#### macOS
1. 使用Homebrew安装：
   ```bash
   brew install flutter
   ```
2. 或手动下载并安装

#### 验证安装
```bash
flutter --version
flutter doctor
```

### IDE配置

#### VS Code
1. 安装VS Code
2. 安装Flutter和Dart插件
3. 配置Flutter SDK路径

#### Android Studio
1. 安装Android Studio
2. 安装Flutter和Dart插件
3. 配置Flutter SDK路径

### 模拟器配置

#### Android模拟器
1. 在Android Studio中打开AVD Manager
2. 创建并启动模拟器

#### iOS模拟器（仅macOS）
1. 打开Xcode
2. 启动iOS模拟器

## 后端开发环境

### Go环境配置

1. 下载并安装Go 1.25+：
   - Windows：访问 [Go官网](https://golang.org/dl/) 下载安装包
   - macOS：`brew install go`
   - Linux：`sudo apt install golang`

2. 验证安装：
   ```bash
go version
   ```

3. 配置Go环境变量：
   ```bash
   # Windows
   set GOPATH=%USERPROFILE%\go
   set PATH=%PATH%;%GOPATH%\bin

   # macOS/Linux
   export GOPATH=$HOME/go
   export PATH=$PATH:$GOPATH/bin
   ```

### MySQL配置

1. 安装MySQL 5.7+：
   - Windows：下载安装包并安装
   - macOS：`brew install mysql`
   - Linux：`sudo apt install mysql-server`

2. 启动MySQL服务：
   ```bash
   # Windows
   net start mysql

   # macOS
   brew services start mysql

   # Linux
   sudo systemctl start mysql
   ```

3. 配置MySQL：
   - 创建用户和数据库
   - 授予权限

### Ollama配置

1. 下载并安装Ollama：
   - 访问 [Ollama官网](https://ollama.com/download)
   - 安装适合您系统的版本

2. 启动Ollama服务：
   - 安装后自动启动
   - 默认运行在 `http://127.0.0.1:11434`

3. 拉取模型：
   ```bash
   ollama pull llama3
   ```

## 环境变量配置

### 前端环境变量

在 `.env` 文件中配置：
```env
# API基础URL
API_BASE_URL=http://localhost:8888

# 其他配置
DEBUG=true
```

### 后端环境变量

在 `backend/config/config.yaml` 中配置：
```yaml
# 服务器配置
server:
  port: 8080
  host: "0.0.0.0"

# 数据库配置
database:
  host: "127.0.0.1"
  port: 3306
  user: "root"
  password: "123456"
  dbname: "go_react_demo"

# Ollama配置
ollama:
  base_url: "http://127.0.0.1:11434"
  timeout_seconds: 300
```

## 网络配置

### 代理设置

如果需要使用代理：

```bash
# 设置HTTP代理
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Flutter代理
flutter config --http-proxy http://proxy.example.com:8080
flutter config --https-proxy http://proxy.example.com:8080
```

### 国内镜像

```bash
# Flutter国内镜像
flutter config --pub-hosted-url=https://pub.flutter-io.cn

# Go国内镜像
go env -w GOPROXY=https://goproxy.cn,direct
```

## 开发工具

### 推荐工具

1. **代码编辑器**：
   - VS Code + Flutter/Dart插件
   - Android Studio

2. **数据库工具**：
   - MySQL Workbench
   - Navicat
   - DBeaver

3. **版本控制**：
   - Git
   - GitHub Desktop

4. **API测试**：
   - Postman
   - Insomnia

## 环境验证

运行以下命令验证环境配置：

```bash
# 前端环境
flutter doctor

# 后端环境
go version
mysql --version
curl http://localhost:11434/api/tags

# 项目构建
flutter build apk --debug
cd backend/api && go build
```

## 常见问题

1. **Flutter doctor 报错**
   - 按照提示安装缺失的依赖
   - 确保Android SDK和工具已安装

2. **MySQL连接失败**
   - 检查MySQL服务是否运行
   - 验证用户名和密码是否正确
   - 确保防火墙允许连接

3. **Ollama服务不可用**
   - 检查Ollama服务是否启动
   - 验证端口是否正确
   - 尝试重启Ollama服务

4. **依赖安装失败**
   - 检查网络连接
   - 尝试使用国内镜像
   - 清理缓存后重试