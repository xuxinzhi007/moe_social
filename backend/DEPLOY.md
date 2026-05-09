# 萌社区后端服务部署文档

## 项目结构

```
backend/
├── Dockerfile          # 单容器版本（同时运行 API + RPC）
├── Dockerfile.api      # API 服务容器
├── Dockerfile.rpc      # RPC 服务容器
├── docker-compose.yml  # 多容器编排
├── api/                # API 服务代码
├── rpc/                # RPC 服务代码
├── config/             # 配置文件
└── ...
```

## 部署方式

### 方式一：使用 docker-compose（推荐）

#### 1. 构建并运行

```bash
# 在 backend 目录执行
docker-compose up -d --build
```

#### 2. 查看服务状态

```bash
docker-compose ps
```

#### 3. 查看日志

```bash
# 查看 API 服务日志
docker logs moe-social-api

# 查看 RPC 服务日志
docker logs moe-social-rpc
```

#### 4. 停止服务

```bash
docker-compose down
```

### 方式二：单独构建运行

#### 构建 RPC 服务

```bash
docker build -t moe-social-rpc -f Dockerfile.rpc .
docker run -d -p 8080:8080 --name moe-social-rpc moe-social-rpc
```

#### 构建 API 服务

```bash
docker build -t moe-social-api -f Dockerfile.api .
docker run -d -p 8888:8888 --name moe-social-api --link moe-social-rpc:rpc moe-social-api
```

### 方式三：单容器运行（快速部署）

```bash
docker build -t moe-social .
docker run -d -p 8888:8888 -p 8080:8080 --name moe-social moe-social
```

## 配置说明

### 1. 数据库配置

修改 `config/config.yaml` 中的数据库配置：

```yaml
database:
  host: "数据库地址"
  port: 3306
  user: "数据库用户名"
  password: "数据库密码"
  dbname: "go_react_demo"
  charset: "utf8mb4"
  parseTime: true
  loc: "Local"
```

### 2. Ollama 配置

修改 `config/config.yaml` 中的 Ollama 配置：

```yaml
ollama:
  base_url: "http://Ollama服务地址:11434"
  timeout_seconds: 300
```

### 3. API 配置

修改 `api/etc/super-direct.yaml` 中的 RPC 服务地址：

```yaml
SuperRpc:
  Endpoints:
  - rpc:8080  # 使用容器名称作为主机名
  NonBlock: true
```

## 端口说明

| 服务 | 容器端口 | 主机端口 | 用途 |
|------|----------|----------|------|
| API  | 8888     | 8888     | HTTP API 服务 |
| RPC  | 8080     | 8080     | gRPC 服务 |

## 常见问题

### 1. RPC 服务连接失败

**症状**：API 服务日志显示 `dial tcp: lookup rpc: no such host`

**解决方案**：
- 使用 docker-compose 部署，确保两个服务在同一个网络中
- 单独部署时，使用 `--link` 参数连接两个容器
- 检查 `super-direct.yaml` 中的 RPC 地址配置

### 2. 数据库连接失败

**症状**：RPC 服务日志显示数据库连接错误

**解决方案**：
- 确保数据库服务正在运行
- 检查 `config/config.yaml` 中的数据库配置
- 确保数据库用户有正确的权限

### 3. Ollama 连接失败

**症状**：API 服务日志显示 Ollama 连接错误

**解决方案**：
- 确保 Ollama 服务正在运行
- 检查 `config/config.yaml` 中的 Ollama 地址配置
- 确保容器可以访问 Ollama 服务

### 4. 图片上传失败

**症状**：图片上传接口返回错误

**解决方案**：
- 确保 `data/images` 目录存在且有写入权限
- 检查 `super-direct.yaml` 中的图片存储配置

## 版本信息

- Go 版本：1.25.5
- Docker 版本：推荐 20.10+  
- docker-compose 版本：推荐 1.29+