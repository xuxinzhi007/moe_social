# Backend Service

基于 go-zero 框架开发的用户管理和 VIP 会员系统后端服务。

## 📋 项目简介

本项目是一个完整的用户管理和 VIP 会员系统后端服务，采用微服务架构设计，提供用户注册、登录、信息管理以及 VIP 会员套餐、订单、记录等完整功能。

## 🏗️ 技术栈

- **框架**: [go-zero](https://github.com/zeromicro/go-zero) v1.9.3
- **数据库**: MySQL (使用 GORM)
- **认证**: JWT (golang-jwt/jwt/v5)
- **RPC**: gRPC (Protocol Buffers)
- **配置管理**: Viper
- **密码加密**: bcrypt (golang.org/x/crypto)

## 📁 项目结构

```
backend/
├── api/                    # API 服务层
│   ├── internal/
│   │   ├── config/         # 配置
│   │   ├── handler/        # HTTP 处理器
│   │   │   ├── user/       # 用户相关处理器
│   │   │   └── vip/        # VIP 相关处理器
│   │   ├── logic/          # 业务逻辑层
│   │   └── svc/            # 服务上下文
│   ├── super.api           # API 定义文件
│   ├── super.go            # API 服务入口
├── rpc/                    # RPC 服务层
│   ├── internal/
│   │   ├── config/         # 配置
│   │   ├── logic/          # RPC 业务逻辑
│   │   ├── server/         # gRPC 服务器
│   │   └── svc/            # 服务上下文
│   ├── super.proto         # Protocol Buffers 定义
│   └── super.go            # RPC 服务入口
├── model/                  # 数据模型
│   ├── user.go            # 用户模型
│   ├── vip_plan.go        # VIP 套餐模型
│   ├── vip_order.go       # VIP 订单模型
│   └── vip_record.go      # VIP 记录模型
├── utils/                  # 工具函数
│   ├── db.go              # 数据库工具
│   └── jwt.go             # JWT 工具
├── config/                 # 配置文件
│   └── config.yaml        # 应用配置
├── go.mod                  # Go 模块依赖
├── go.sum                  # 依赖校验和
└── Makefile                # make gen / make gen-rpc / make gen-api
```

## 🚀 快速开始

### 前置要求

- Go 1.25.5 或更高版本
- MySQL 5.7 或更高版本
- goctl 工具（go-zero 代码生成工具）

### 安装 goctl

```bash
go install github.com/zeromicro/go-zero/tools/goctl@latest
```

### 配置数据库

1. 创建 MySQL 数据库：

```sql
CREATE DATABASE go_react_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. 修改配置文件 `config/config.yaml`：

```yaml
server:
  port: 8080
  host: "0.0.0.0"

database:
  host: "127.0.0.1"
  port: 3306
  user: "root"
  password: "your_password"
  dbname: "go_react_demo"
  charset: "utf8mb4"
  parseTime: true
  loc: "Local"
```

### 安装依赖

```bash
go mod download
```

### 生成代码

#### 生成 RPC / API 代码

在 **`backend` 目录**执行（需已安装 GNU Make 与 goctl）：

```bash
cd backend
make gen
```

仅 RPC：`make gen-rpc`；仅 API：`make gen-api`。参数与注释见根目录 `Makefile`。

手动执行 RPC（与 Makefile 中 `gen-rpc` 一致）：

```bash
cd backend
goctl rpc protoc rpc/super.proto --go_out=. --go-grpc_out=. --zrpc_out=./rpc -I rpc --go_opt=module=backend --go-grpc_opt=module=backend --client=false
```

手动执行 API：

```bash
cd backend/api
goctl api go -api super.api -dir ./
```

### 运行服务

#### 运行 RPC 服务

```bash
cd rpc
go run super.go -f etc/super.yaml
```

#### 运行 API 服务

```bash
cd api
go run super.go -f etc/super.yaml
```

API 服务默认运行在 `http://localhost:8080`

## 📚 API 文档

### 用户相关 API

#### 用户注册
- **POST** `/api/user/register`
- **请求体**:
```json
{
  "username": "testuser",
  "password": "password123",
  "email": "test@example.com"
}
```

#### 用户登录
- **POST** `/api/user/login`
- **请求体**:
```json
{
  "username": "testuser",  // 或使用 email
  "password": "password123"
}
```
- **响应**: 返回用户信息和 JWT Token

#### 获取用户信息
- **GET** `/api/user/:user_id`

#### 更新用户信息
- **PUT** `/api/user/:user_id`
- **请求体**:
```json
{
  "username": "newname",
  "email": "newemail@example.com",
  "avatar": "avatar_url"
}
```

#### 更新用户密码
- **PUT** `/api/user/:user_id/password`
- **请求体**:
```json
{
  "old_password": "oldpass",
  "new_password": "newpass"
}
```

#### 删除用户
- **DELETE** `/api/user/:user_id`

#### 获取用户列表
- **GET** `/api/users?page=1&page_size=10`

#### 获取用户总数
- **GET** `/api/users/count`

### VIP 相关 API

#### 获取 VIP 套餐列表
- **GET** `/api/vip/plans`

#### 获取单个 VIP 套餐
- **GET** `/api/vip/plans/:plan_id`

#### 创建 VIP 套餐（管理员）
- **POST** `/api/vip/plans`
- **请求体**:
```json
{
  "name": "月度VIP",
  "description": "30天VIP会员",
  "price": 29.9,
  "duration_days": 30
}
```

#### 创建 VIP 订单
- **POST** `/api/user/:user_id/vip/orders`
- **请求体**:
```json
{
  "plan_id": "plan_id_here"
}
```

#### 获取用户 VIP 订单列表
- **GET** `/api/user/:user_id/vip/orders?page=1&page_size=10`

#### 获取用户 VIP 历史记录
- **GET** `/api/user/:user_id/vip/records?page=1&page_size=10`

#### 获取用户 VIP 状态
- **GET** `/api/user/:user_id/vip`

#### 检查用户是否为 VIP
- **GET** `/api/user/:user_id/vip/check`

#### 更新自动续费设置
- **PUT** `/api/user/:user_id/vip/auto-renew`
- **请求体**:
```json
{
  "auto_renew": true
}
```

#### 同步用户 VIP 状态
- **POST** `/api/user/:user_id/vip/sync`

#### 获取用户活跃 VIP 记录
- **GET** `/api/user/:user_id/vip/active`

## 🔧 配置说明

### 数据库配置

项目使用 GORM 进行数据库操作，支持自动迁移。数据库连接配置在 `config/config.yaml` 中。

### JWT 配置

JWT 密钥和过期时间在 `utils/jwt.go` 中配置，默认过期时间为 24 小时。生产环境建议将密钥配置到环境变量或配置文件中。

## 🗄️ 数据模型

### User（用户）
- ID: 主键
- Username: 用户名（唯一）
- Password: 密码（bcrypt 加密）
- Email: 邮箱（唯一）
- IsVip: VIP 状态
- VipStartAt: VIP 开始时间
- VipEndAt: VIP 结束时间
- CreatedAt: 创建时间
- UpdatedAt: 更新时间

### VipPlan（VIP 套餐）
- ID: 主键
- Name: 套餐名称
- Description: 套餐描述
- Price: 价格
- DurationDays: 时长（天）
- CreatedAt: 创建时间
- UpdatedAt: 更新时间

### VipOrder（VIP 订单）
- ID: 主键
- UserID: 用户ID
- PlanID: 套餐ID
- PlanName: 套餐名称
- Amount: 订单金额
- Status: 订单状态
- CreatedAt: 创建时间
- PaidAt: 支付时间

### VipRecord（VIP 记录）
- ID: 主键
- UserID: 用户ID
- PlanID: 套餐ID
- PlanName: 套餐名称
- StartAt: 开始时间
- EndAt: 结束时间
- Status: 状态
- CreatedAt: 创建时间

## 🔐 安全特性

- 密码使用 bcrypt 加密存储
- JWT Token 认证
- 数据库连接池管理
- 输入验证和错误处理

## 📝 开发指南

### 添加新的 API

1. 在 `api/super.api` 中定义新的 API 接口
2. 在 `backend` 下运行 `make gen-api`（或 `make gen`）生成代码
3. 在 `api/internal/logic` 中实现业务逻辑

### 添加新的 RPC 方法

1. 在 `rpc/super.proto` 中定义新的 RPC 方法
2. 在 `backend` 下运行 `make gen-rpc`（或 `make gen`）生成代码
3. 在 `rpc/internal/logic` 中实现业务逻辑

## 🐛 常见问题

### 数据库连接失败

- 检查 MySQL 服务是否启动
- 确认配置文件中的数据库连接信息正确
- 确认数据库已创建

### 代码生成失败

- 确认已安装 goctl 工具
- 检查 API 定义文件或 proto 文件语法是否正确

## 📄 许可证

本项目采用 MIT 许可证。

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

## 📮 联系方式

如有问题或建议，请通过 Issue 联系。

