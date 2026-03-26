# API开发

## 概述

本项目使用go-zero框架开发RESTful API，API开发是后端服务的核心部分。通过本指南，您将学习如何定义API、生成代码、实现业务逻辑以及测试API。

## API定义

### API语法

使用go-zero的API语法定义接口：

```go
// super.api
type (
    // 请求和响应结构体
    RegisterRequest {
        Username string `json:"username" validate:"required,min=3,max=50"`
        Password string `json:"password" validate:"required,min=6"`
        Email    string `json:"email" validate:"required,email"`
    }

    RegisterResponse {
        Id       string `json:"id"`
        Username string `json:"username"`
        Email    string `json:"email"`
    }

    LoginRequest {
        Username string `json:"username" validate:"required"`
        Password string `json:"password" validate:"required"`
    }

    LoginResponse {
        Token string `json:"token"`
        User  UserInfo `json:"user"`
    }

    UserInfo {
        Id       string `json:"id"`
        Username string `json:"username"`
        Email    string `json:"email"`
        Avatar   string `json:"avatar"`
        IsVip    bool   `json:"isVip"`
    }

    GetUserRequest {
        Id string `path:"id" validate:"required"`
    }

    GetUserResponse {
        User UserInfo `json:"user"`
    }

    UpdateUserRequest {
        Username string `json:"username" validate:"omitempty,min=3,max=50"`
        Email    string `json:"email" validate:"omitempty,email"`
        Avatar   string `json:"avatar"`
    }

    UpdateUserResponse {
        User UserInfo `json:"user"`
    }

    DeleteUserRequest {
        Id string `path:"id" validate:"required"`
    }

    DeleteUserResponse {
        Success bool `json:"success"`
    }
)

@server (
    prefix: /api
    group: user
    middleware: Auth
)

route {
    post   /register      RegisterHandler
    post   /login         LoginHandler     // 不需要认证
    get    /:id           GetUserHandler
    put    /               UpdateUserHandler
    delete /:id           DeleteUserHandler
}

@server (
    prefix: /api
    group: post
    middleware: Auth
)

route {
    post   /           CreatePostHandler
    get    /           GetPostsHandler
    get    /:id        GetPostHandler
    put    /:id        UpdatePostHandler
    delete /:id        DeletePostHandler
    post   /:id/like   LikePostHandler
}

@server (
    prefix: /api
    group: comment
    middleware: Auth
)

route {
    post   /           CreateCommentHandler
    get    /post/:id   GetPostCommentsHandler
    post   /:id/like  LikeCommentHandler
}
```

### 验证规则

使用validate标签定义验证规则：

- `required` - 字段必填
- `min` - 最小长度
- `max` - 最大长度
- `email` - 邮箱格式
- `omitempty` - 字段可选
- `regexp` - 正则表达式

## 代码生成

### 安装goctl工具

#### Windows

```powershell
# 安装goctl
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 验证安装
goctl --version
```

#### macOS/Linux

```bash
# 安装goctl
go install github.com/zeromicro/go-zero/tools/goctl@latest

# 验证安装
goctl --version
```

### 生成API代码

#### Windows

```powershell
# 生成API代码
goctl api go -api super.api -dir .

# 生成带注释的代码
goctl api go -api super.api -dir . -style gozero
```

#### macOS/Linux

```bash
# 生成API代码
goctl api go -api super.api -dir .

# 生成带注释的代码
goctl api go -api super.api -dir . -style gozero
```

### Windows 环境下的注意事项

1. **环境变量配置**：
   - 确保 `C:\Users\YourUsername\go\bin` 目录已添加到系统的 PATH 环境变量中
   - 这样可以在任何目录中直接运行 `goctl` 命令
   - 配置完成后需要重启终端使环境变量生效

2. **Shell 脚本执行**：
   - 在 Windows 环境下，`.sh` 脚本无法直接运行
   - 可以使用 Git Bash 或 WSL (Windows Subsystem for Linux) 运行 shell 脚本
   - 或者直接执行脚本中的 `goctl` 命令来生成代码，因为 goctl 已经配置好了环境变量
   - 例如：直接运行 `goctl api go -api super.api -dir ./` 来替代运行 `bash generate_api.sh`

3. **API 定义语法**：
   - goctl 不支持内嵌的匿名结构体语法
   - 需要为复杂的响应结构创建单独的命名类型
   - 例如：使用 `VoiceCallData` 而不是内嵌的 `struct`

4. **路径分隔符**：
   - Windows 使用 `\` 作为路径分隔符，而 Go 代码中使用 `/`
   - 在配置文件和代码中使用 `/` 作为路径分隔符

5. **常见问题**：
   - **goctl 命令无法识别**：检查环境变量配置，确保 `C:\Users\YourUsername\go\bin` 在 PATH 中
   - **API 语法错误**：避免使用内嵌的匿名结构体，创建单独的命名类型
   - **权限问题**：确保以管理员身份运行终端（如果需要）

### 生成的文件结构

```
api/
├── etc/
│   └── super.yaml     # 配置文件
├── internal/
│   ├── config/
│   │   └── config.go   # 配置结构
│   ├── handler/
│   │   ├── loginhandler.go     # 登录处理器
│   │   ├── registerhandler.go  # 注册处理器
│   │   └── ...
│   ├── logic/
│   │   ├── loginlogic.go       # 登录逻辑
│   │   ├── registerlogic.go    # 注册逻辑
│   │   └── ...
│   ├── middleware/
│   │   └── authmiddleware.go   # 认证中间件
│   ├── svc/
│   │   └── servicecontext.go   # 服务上下文
│   └── types/
│       └── types.go           # 数据类型
├── super.api            # API定义文件
└── super.go             # 服务入口
```

## 实现业务逻辑

### Handler实现

```go
// internal/handler/registerhandler.go
package handler

import (
    "net/http"

    "github.com/zeromicro/go-zero/rest/httpx"
    "backend/api/internal/logic"
    "backend/api/internal/svc"
    "backend/api/internal/types"
)

func RegisterHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        var req types.RegisterRequest
        if err := httpx.Parse(r, &req); err != nil {
            httpx.Error(w, err)
            return
        }

        l := logic.NewRegisterLogic(r.Context(), svcCtx)
        resp, err := l.Register(&req)
        if err != nil {
            httpx.Error(w, err)
        } else {
            httpx.Ok(w, resp)
        }
    }
}
```

### Logic实现

```go
// internal/logic/registerlogic.go
package logic

import (
    "context"
    "errors"
    "github.com/google/uuid"

    "backend/api/internal/svc"
    "backend/api/internal/types"
    "backend/model"
    "backend/utils"
)

type RegisterLogic struct {
    ctx    context.Context
    svcCtx *svc.ServiceContext
}

func NewRegisterLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RegisterLogic {
    return &RegisterLogic{
        ctx:    ctx,
        svcCtx: svcCtx,
    }
}

func (l *RegisterLogic) Register(req *types.RegisterRequest) (*types.RegisterResponse, error) {
    // 检查用户名是否已存在
    existingUser, err := l.svcCtx.UserModel.FindByUsername(req.Username)
    if err == nil && existingUser != nil {
        return nil, errors.New("用户名已存在")
    }

    // 检查邮箱是否已存在
    existingEmail, err := l.svcCtx.UserModel.FindByEmail(req.Email)
    if err == nil && existingEmail != nil {
        return nil, errors.New("邮箱已被注册")
    }

    // 密码加密
    hashedPassword, err := utils.HashPassword(req.Password)
    if err != nil {
        return nil, errors.New("密码加密失败")
    }

    // 创建用户
    user := &model.User{
        Id:       uuid.New().String(),
        Username: req.Username,
        Password: hashedPassword,
        Email:    req.Email,
        Avatar:   "https://via.placeholder.com/150",
        IsVip:    false,
    }

    err = l.svcCtx.UserModel.Create(user)
    if err != nil {
        return nil, errors.New("创建用户失败")
    }

    return &types.RegisterResponse{
        Id:       user.Id,
        Username: user.Username,
        Email:    user.Email,
    }, nil
}
```

### ServiceContext实现

```go
// internal/svc/servicecontext.go
package svc

import (
    "gorm.io/driver/mysql"
    "gorm.io/gorm"

    "backend/api/internal/config"
    "backend/model"
)

type ServiceContext struct {
    Config         config.Config
    UserModel      model.UserModel
    PostModel      model.PostModel
    CommentModel   model.CommentModel
    LikeModel      model.LikeModel
    FollowModel    model.FollowModel
    NotificationModel model.NotificationModel
}

func NewServiceContext(c config.Config) *ServiceContext {
    // 连接数据库
    dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
        c.Database.User,
        c.Database.Password,
        c.Database.Host,
        c.Database.Port,
        c.Database.Dbname,
    )

    db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }

    // 自动迁移数据库表
    db.AutoMigrate(
        &model.User{},
        &model.Post{},
        &model.Comment{},
        &model.Like{},
        &model.Follow{},
        &model.Notification{},
    )

    return &ServiceContext{
        Config:         c,
        UserModel:      model.NewUserModel(db),
        PostModel:      model.NewPostModel(db),
        CommentModel:   model.NewCommentModel(db),
        LikeModel:      model.NewLikeModel(db),
        FollowModel:    model.NewFollowModel(db),
        NotificationModel: model.NewNotificationModel(db),
    }
}
```

## 中间件

### 认证中间件

```go
// internal/middleware/authmiddleware.go
package middleware

import (
    "context"
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

### 日志中间件

```go
// internal/middleware/logmiddleware.go
package middleware

import (
    "net/http"
    "time"

    "github.com/zeromicro/go-zero/core/logx"
    "github.com/zeromicro/go-zero/rest/httpx"
)

func LogMiddleware() func(next http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            startTime := time.Now()
            
            // 包装ResponseWriter以获取状态码
            writer := httpx.NewResponseWriter(w)
            next.ServeHTTP(writer, r)
            
            // 记录请求信息
            logx.Infof("%s %s %d %s",
                r.Method,
                r.RequestURI,
                writer.Status(),
                time.Since(startTime),
            )
        })
    }
}
```

## API测试

### 使用curl测试

```bash
# 注册
curl -X POST http://localhost:8888/api/user/register \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "password123", "email": "test@example.com"}'

# 登录
curl -X POST http://localhost:8888/api/user/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "password123"}'

# 获取用户信息（需要token）
curl -X GET http://localhost:8888/api/user/1 \
  -H "Authorization: Bearer YOUR_TOKEN"

# 更新用户信息
curl -X PUT http://localhost:8888/api/user \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"username": "updateduser", "email": "updated@example.com"}'

# 删除用户
curl -X DELETE http://localhost:8888/api/user/1 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 使用Postman测试

1. **创建请求集合**：创建一个Moe Social API集合
2. **添加环境变量**：添加baseUrl和token变量
3. **创建请求**：
   - 注册请求（POST）
   - 登录请求（POST）
   - 获取用户信息（GET）
   - 更新用户信息（PUT）
   - 删除用户（DELETE）
4. **设置授权**：在需要认证的请求中添加Bearer token
5. **运行测试**：执行请求并验证响应

### 单元测试

```go
// internal/logic/loginlogic_test.go
package logic

import (
    "context"
    "errors"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "backend/api/internal/svc"
    "backend/api/internal/types"
    "backend/model"
    "backend/utils"
)

// 模拟UserModel
type MockUserModel struct {
    mock.Mock
}

func (m *MockUserModel) FindByUsername(username string) (*model.User, error) {
    args := m.Called(username)
    return args.Get(0).(*model.User), args.Error(1)
}

func (m *MockUserModel) Create(user *model.User) error {
    args := m.Called(user)
    return args.Error(0)
}

func TestLoginLogic_Login(t *testing.T) {
    // 模拟UserModel
    mockUserModel := &MockUserModel{}
    
    // 模拟密码验证
    utils.VerifyPassword = func(hashedPassword, password string) bool {
        return hashedPassword == "hashed_password" && password == "password123"
    }
    
    // 模拟Token生成
    utils.GenerateToken = func(userId, secret string, expire int64) (string, error) {
        return "test_token", nil
    }

    // 测试用例1：登录成功
    t.Run("LoginSuccess", func(t *testing.T) {
        // 设置模拟返回值
        mockUserModel.On("FindByUsername", "testuser").Return(&model.User{
            Id:       "1",
            Username: "testuser",
            Password: "hashed_password",
            Email:    "test@example.com",
        }, nil)

        // 创建ServiceContext
        svcCtx := &svc.ServiceContext{
            UserModel: mockUserModel,
            Config: config.Config{
                Auth: struct {
                    AccessSecret string
                    AccessExpire int64
                }{
                    AccessSecret: "test_secret",
                    AccessExpire: 86400,
                },
            },
        }

        // 创建LoginLogic
        logic := NewLoginLogic(context.Background(), svcCtx)

        // 执行登录
        req := &types.LoginRequest{
            Username: "testuser",
            Password: "password123",
        }
        resp, err := logic.Login(req)

        // 验证结果
        assert.NoError(t, err)
        assert.Equal(t, "test_token", resp.Token)
        assert.Equal(t, "1", resp.User.Id)
        assert.Equal(t, "testuser", resp.User.Username)
        assert.Equal(t, "test@example.com", resp.User.Email)

        // 验证模拟调用
        mockUserModel.AssertExpectations(t)
    })

    // 测试用例2：用户不存在
    t.Run("UserNotFound", func(t *testing.T) {
        // 设置模拟返回值
        mockUserModel.On("FindByUsername", "nonexistent").Return(nil, errors.New("user not found"))

        // 创建ServiceContext
        svcCtx := &svc.ServiceContext{
            UserModel: mockUserModel,
        }

        // 创建LoginLogic
        logic := NewLoginLogic(context.Background(), svcCtx)

        // 执行登录
        req := &types.LoginRequest{
            Username: "nonexistent",
            Password: "password123",
        }
        resp, err := logic.Login(req)

        // 验证结果
        assert.Error(t, err)
        assert.Nil(t, resp)
        assert.Equal(t, "用户不存在", err.Error())

        // 验证模拟调用
        mockUserModel.AssertExpectations(t)
    })

    // 测试用例3：密码错误
    t.Run("InvalidPassword", func(t *testing.T) {
        // 设置模拟返回值
        mockUserModel.On("FindByUsername", "testuser").Return(&model.User{
            Id:       "1",
            Username: "testuser",
            Password: "hashed_password",
            Email:    "test@example.com",
        }, nil)

        // 创建ServiceContext
        svcCtx := &svc.ServiceContext{
            UserModel: mockUserModel,
        }

        // 创建LoginLogic
        logic := NewLoginLogic(context.Background(), svcCtx)

        // 执行登录
        req := &types.LoginRequest{
            Username: "testuser",
            Password: "wrongpassword",
        }
        resp, err := logic.Login(req)

        // 验证结果
        assert.Error(t, err)
        assert.Nil(t, resp)
        assert.Equal(t, "密码错误", err.Error())

        // 验证模拟调用
        mockUserModel.AssertExpectations(t)
    })
}
```

## API版本控制

### URL路径版本控制

```go
// super.api
@server (
    prefix: /api/v1
    group: user
    middleware: Auth
)

route {
    post   /register      RegisterHandler
    post   /login         LoginHandler
    get    /:id           GetUserHandler
    put    /               UpdateUserHandler
    delete /:id           DeleteUserHandler
}

@server (
    prefix: /api/v2
    group: user
    middleware: Auth
)

route {
    post   /register      RegisterHandlerV2
    post   /login         LoginHandlerV2
    get    /:id           GetUserHandlerV2
    put    /               UpdateUserHandlerV2
    delete /:id           DeleteUserHandlerV2
}
```

### 头部版本控制

```go
// internal/middleware/versionmiddleware.go
package middleware

import (
    "net/http"
    "strings"

    "github.com/zeromicro/go-zero/rest/httpx"
)

func VersionMiddleware() func(next http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // 从Header获取版本
            version := r.Header.Get("X-API-Version")
            if version == "" {
                version = "v1" // 默认版本
            }

            // 将版本存储到上下文
            r = r.WithContext(context.WithValue(r.Context(), "version", version))
            next.ServeHTTP(w, r)
        })
    }
}

// 在handler中使用版本
func GetUserHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        version := r.Context().Value("version").(string)
        
        if version == "v2" {
            // 处理v2版本逻辑
        } else {
            // 处理v1版本逻辑
        }
    }
}
```

## 性能优化

1. **缓存**：使用Redis缓存热点数据
2. **分页**：实现API分页，避免返回大量数据
3. **批量操作**：支持批量创建、更新、删除
4. **限流**：实现API限流，防止过载
5. **压缩**：启用Gzip压缩，减少传输大小
6. **连接池**：使用数据库连接池
7. **并发处理**：使用goroutine处理并发任务

## 最佳实践

1. **API设计**：遵循RESTful设计规范
2. **错误处理**：统一错误响应格式
3. **参数验证**：使用validate标签验证参数
4. **安全**：实现认证和授权
5. **日志**：记录API请求和响应
6. **监控**：集成Prometheus监控
7. **文档**：使用Swagger生成API文档
8. **测试**：编写单元测试和集成测试
9. **版本控制**：支持API版本控制
10. **性能**：优化API性能

## 常见问题

1. **API参数验证失败**
   - 检查validate标签是否正确
   - 确保请求参数格式正确
   - 检查参数类型是否匹配

2. **认证失败**
   - 检查token是否正确
   - 确保token未过期
   - 验证AccessSecret是否一致

3. **数据库操作错误**
   - 检查数据库连接配置
   - 确保数据库表结构正确
   - 检查SQL语句

4. **API响应慢**
   - 优化数据库查询
   - 使用缓存
   - 考虑并发处理

5. **跨域问题**
   - 配置CORS中间件
   - 允许必要的HTTP方法和头部

## 总结

API开发是后端服务的核心部分，通过go-zero框架，我们可以快速构建高性能、可靠的RESTful API。在开发过程中，应遵循最佳实践，注重API设计、错误处理、安全和性能优化，确保API服务的质量和可靠性。