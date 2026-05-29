# go-zero框架

## 概述

go-zero是一个集成了各种工程实践的高性能Go微服务框架，本项目使用go-zero构建后端API服务。go-zero提供了丰富的功能，包括路由、中间件、配置管理、监控等，帮助开发者快速构建高性能、可靠的微服务。

## 项目结构

```
backend/
├── api/              # API服务
│   ├── etc/          # 配置文件
│   ├── internal/     # 内部实现
│   │   ├── handler/  # 请求处理器
│   │   ├── logic/    # 业务逻辑
│   │   ├── middleware/ # 中间件
│   │   ├── svc/      # 服务上下文
│   │   └── types/    # 数据类型
│   ├── super.api     # API定义文件
│   └── super.go      # 服务入口
├── config/           # 配置文件
├── model/            # 数据库模型
├── rpc/              # RPC服务
├── scripts/          # 脚本文件
└── utils/            # 工具类
```

## 核心概念

### 1. API定义

使用go-zero的API语法定义接口：

```go
// super.api
type (  
    LoginRequest {
        Username string `json:"username"`
        Password string `json:"password"`
    }

    LoginResponse {
        Token string `json:"token"`
        User UserInfo `json:"user"`
    }

    UserInfo {
        Id       string `json:"id"`
        Username string `json:"username"`
        Email    string `json:"email"`
    }
)

@server (
    prefix: /api
    middleware: Auth
)

route {
    post /login LoginHandler
    get /user/:id GetUserHandler
    put /user UpdateUserHandler
    delete /user/:id DeleteUserHandler
}
```

### 2. 生成代码

使用go-zero的工具生成代码：

```bash
# 安装go-zero工具
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 生成API代码
goctl api go -api super.api -dir .
```

### 3. 服务启动

```go
// super.go
package main

import (
    "flag"
    "fmt"

    "github.com/zeromicro/go-zero/core/conf"
    "github.com/zeromicro/go-zero/rest"
    "backend/api/internal/config"
    "backend/api/internal/handler"
    "backend/api/internal/svc"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

func main() {
    flag.Parse()

    var c config.Config
    conf.MustLoad(*configFile, &c)

    server := rest.MustNewServer(c.RestConf)
    defer server.Stop()

    ctx := svc.NewServiceContext(c)
    handler.RegisterHandlers(server, ctx)

    fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
    server.Start()
}
```

### 4. 配置管理

```yaml
# etc/super.yaml
Name: Super
Host: 0.0.0.0
Port: 8888
Timeout: 600000

Auth:
  AccessSecret: "u8K9x2L1n4Q7v5Z0m3P6r9Y2b5X8j1W4"
  AccessExpire: 86400

Database:
  Host: "127.0.0.1"
  Port: 3306
  User: "root"
  Password: "123456"
  Dbname: "go_react_demo"
```

## 核心组件

### 1. Handler

处理HTTP请求：

```go
// internal/handler/loginhandler.go
package handler

import (
    "net/http"

    "github.com/zeromicro/go-zero/rest/httpx"
    "backend/api/internal/logic"
    "backend/api/internal/svc"
    "backend/api/internal/types"
)

func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        var req types.LoginRequest
        if err := httpx.Parse(r, &req); err != nil {
            httpx.Error(w, err)
            return
        }

        l := logic.NewLoginLogic(r.Context(), svcCtx)
        resp, err := l.Login(&req)
        if err != nil {
            httpx.Error(w, err)
        } else {
            httpx.Ok(w, resp)
        }
    }
}
```

### 2. Logic

业务逻辑处理：

```go
// internal/logic/loginlogic.go
package logic

import (
    "context"
    "errors"

    "backend/api/internal/svc"
    "backend/api/internal/types"
    "backend/model"
    "backend/utils"
)

type LoginLogic struct {
    ctx    context.Context
    svcCtx *svc.ServiceContext
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
    return &LoginLogic{
        ctx:    ctx,
        svcCtx: svcCtx,
    }
}

func (l *LoginLogic) Login(req *types.LoginRequest) (*types.LoginResponse, error) {
    // 查询用户
    user, err := l.svcCtx.UserModel.FindByUsername(req.Username)
    if err != nil {
        return nil, errors.New("用户不存在")
    }

    // 验证密码
    if !utils.VerifyPassword(user.Password, req.Password) {
        return nil, errors.New("密码错误")
    }

    // 生成Token
    token, err := utils.GenerateToken(user.Id, l.svcCtx.Config.Auth.AccessSecret, l.svcCtx.Config.Auth.AccessExpire)
    if err != nil {
        return nil, errors.New("生成token失败")
    }

    return &types.LoginResponse{
        Token: token,
        User: types.UserInfo{
            Id:       user.Id,
            Username: user.Username,
            Email:    user.Email,
        },
    }, nil
}
```

### 3. ServiceContext

服务上下文，管理依赖：

```go
// internal/svc/servicecontext.go
package svc

import (
    "backend/api/internal/config"
    "backend/model"
)

type ServiceContext struct {
    Config     config.Config
    UserModel  model.UserModel
    PostModel  model.PostModel
    CommentModel model.CommentModel
}

func NewServiceContext(c config.Config) *ServiceContext {
    return &ServiceContext{
        Config:     c,
        UserModel:  model.NewUserModel(c.Database),
        PostModel:  model.NewPostModel(c.Database),
        CommentModel: model.NewCommentModel(c.Database),
    }
}
```

### 4. Middleware

中间件处理：

```go
// internal/middleware/authmiddleware.go
package middleware

import (
    "net/http"
    "strings"

    "github.com/zeromicro/go-zero/rest/httpx"
    "backend/api/internal/config"
    "backend/utils"
)

func AuthMiddleware(c config.Config) func(next http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // 从Header获取token
            auth := r.Header.Get("Authorization")
            if auth == "" {
                httpx.Error(w, errors.New("未授权"))
                return
            }

            // 解析token
            parts := strings.SplitN(auth, " ", 2)
            if !(len(parts) == 2 && parts[0] == "Bearer") {
                httpx.Error(w, errors.New("无效的授权格式"))
                return
            }

            // 验证token
            claims, err := utils.ParseToken(parts[1], c.Auth.AccessSecret)
            if err != nil {
                httpx.Error(w, errors.New("无效的token"))
                return
            }

            // 将用户ID存储到上下文
            r = r.WithContext(context.WithValue(r.Context(), "userId", claims.UserId))
            next.ServeHTTP(w, r)
        })
    }
}
```

## 数据库操作

### GORM集成

```go
// model/user.go
package model

import (
    "gorm.io/gorm"
)

type User struct {
    Id       string `gorm:"primaryKey" json:"id"`
    Username string `gorm:"uniqueIndex" json:"username"`
    Password string `json:"-"`
    Email    string `gorm:"uniqueIndex" json:"email"`
    Avatar   string `json:"avatar"`
    IsVip    bool   `json:"isVip"`
}

type UserModel struct {
    db *gorm.DB
}

func NewUserModel(db *gorm.DB) *UserModel {
    return &UserModel{db: db}
}

func (m *UserModel) FindByUsername(username string) (*User, error) {
    var user User
    err := m.db.Where("username = ?", username).First(&user).Error
    return &user, err
}

func (m *UserModel) Create(user *User) error {
    return m.db.Create(user).Error
}

func (m *UserModel) Update(user *User) error {
    return m.db.Save(user).Error
}

func (m *UserModel) Delete(id string) error {
    return m.db.Delete(&User{}, "id = ?", id).Error
}
```

## 配置管理

### 配置结构

```go
// internal/config/config.go
package config

import (
    "github.com/zeromicro/go-zero/rest"
)

type Config struct {
    rest.RestConf
    Auth struct {
        AccessSecret string
        AccessExpire int64
    }
    Database struct {
        Host     string
        Port     int
        User     string
        Password string
        Dbname   string
    }
    Ollama struct {
        BaseUrl        string
        TimeoutSeconds int
    }
}
```

### 配置加载

```go
// 加载配置
var c config.Config
conf.MustLoad(*configFile, &c)

// 访问配置
fmt.Println(c.Host)
fmt.Println(c.Port)
fmt.Println(c.Auth.AccessSecret)
```

## 性能优化

1. **连接池**：使用数据库连接池
2. **缓存**：合理使用缓存减少数据库查询
3. **并发**：使用goroutine处理并发任务
4. **限流**：实现请求限流防止过载
5. **监控**：集成Prometheus监控

## 错误处理

### 统一错误响应

```go
// utils/error.go
package utils

import (
    "net/http"

    "github.com/zeromicro/go-zero/rest/httpx"
)

type ErrorResponse struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

func Error(w http.ResponseWriter, code int, message string) {
    httpx.Error(w, ErrorResponse{
        Code:    code,
        Message: message,
    })
}

func BadRequest(w http.ResponseWriter, message string) {
    Error(w, http.StatusBadRequest, message)
}

func Unauthorized(w http.ResponseWriter, message string) {
    Error(w, http.StatusUnauthorized, message)
}

func Forbidden(w http.ResponseWriter, message string) {
    Error(w, http.StatusForbidden, message)
}

func InternalServerError(w http.ResponseWriter, message string) {
    Error(w, http.StatusInternalServerError, message)
}
```

## 部署与运行

### 本地运行

```bash
# 进入API目录
cd backend/api

# 运行服务
go run super.go

# 构建服务
go build -o super-api .
./super-api -f etc/super.yaml
```

### 容器化部署

```dockerfile
# Dockerfile
FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod tidy
RUN go build -o super-api ./api

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/api/super-api .
COPY --from=builder /app/api/etc /app/etc

EXPOSE 8888

CMD ["./super-api", "-f", "etc/super.yaml"]
```

### 环境变量

```yaml
# etc/super.yaml
Name: Super
Host: ${HOST:0.0.0.0}
Port: ${PORT:8888}

Auth:
  AccessSecret: ${ACCESS_SECRET:u8K9x2L1n4Q7v5Z0m3P6r9Y2b5X8j1W4}
  AccessExpire: ${ACCESS_EXPIRE:86400}

Database:
  Host: ${DB_HOST:127.0.0.1}
  Port: ${DB_PORT:3306}
  User: ${DB_USER:root}
  Password: ${DB_PASSWORD:123456}
  Dbname: ${DB_NAME:go_react_demo}
```

## 监控与日志

### 日志配置

```go
// super.go
package main

import (
    "flag"
    "fmt"

    "github.com/zeromicro/go-zero/core/conf"
    "github.com/zeromicro/go-zero/core/logx"
    "github.com/zeromicro/go-zero/rest"
    "backend/api/internal/config"
    "backend/api/internal/handler"
    "backend/api/internal/svc"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

func main() {
    flag.Parse()

    var c config.Config
    conf.MustLoad(*configFile, &c)

    // 配置日志
    logx.MustSetup(logx.LogConf{
        ServiceName: c.Name,
        Mode:        "file",
        Path:        "logs",
        Level:       "info",
    })

    server := rest.MustNewServer(c.RestConf)
    defer server.Stop()

    ctx := svc.NewServiceContext(c)
    handler.RegisterHandlers(server, ctx)

    fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
    server.Start()
}
```

### 监控集成

```go
// super.go
package main

import (
    "flag"
    "fmt"

    "github.com/zeromicro/go-zero/core/conf"
    "github.com/zeromicro/go-zero/rest"
    "github.com/zeromicro/go-zero/rest/httpx"
    "backend/api/internal/config"
    "backend/api/internal/handler"
    "backend/api/internal/svc"
)

var configFile = flag.String("f", "etc/super.yaml", "the config file")

func main() {
    flag.Parse()

    var c config.Config
    conf.MustLoad(*configFile, &c)

    server := rest.MustNewServer(c.RestConf, rest.WithPrometheus())
    defer server.Stop()

    ctx := svc.NewServiceContext(c)
    handler.RegisterHandlers(server, ctx)

    fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
    server.Start()
}
```

## 最佳实践

1. **代码生成**：使用goctl工具生成代码，减少重复工作
2. **分层架构**：清晰的Handler -> Logic -> Model分层
3. **配置管理**：使用统一的配置管理
4. **错误处理**：统一的错误响应格式
5. **中间件**：合理使用中间件处理横切关注点
6. **数据库操作**：使用GORM进行数据库操作
7. **性能优化**：合理使用缓存和并发
8. **监控日志**：集成监控和日志系统
9. **安全性**：注意密码加密和token验证
10. **可测试性**：编写单元测试和集成测试

## 常见问题

1. **API代码生成失败**
   - 检查API定义文件语法
   - 确保goctl工具版本正确
   - 检查目录结构

2. **服务启动失败**
   - 检查配置文件
   - 确保数据库连接正常
   - 检查端口是否被占用

3. **数据库操作错误**
   - 检查数据库连接配置
   - 确保数据库表结构正确
   - 检查SQL语句

4. **Token验证失败**
   - 检查token生成和解析逻辑
   - 确保AccessSecret一致
   - 检查token过期时间

5. **性能问题**
   - 检查数据库查询
   - 优化缓存策略
   - 考虑使用并发处理

## 总结

go-zero是一个功能强大的Go微服务框架，通过本指南的学习，您应该能够掌握go-zero的基本使用方法，包括API定义、代码生成、服务启动、数据库操作等。在实际开发中，应遵循最佳实践，合理使用框架提供的功能，构建高性能、可靠的后端服务。