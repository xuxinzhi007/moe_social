# Moe Social Code Wiki

> 项目完整技术文档，包含架构设计、模块职责、核心组件说明、依赖关系及运行指南。
>
> 最后更新：2026-06-29

---

## 目录

- [项目概述](#项目概述)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [前端架构 (Flutter)](#前端架构-flutter)
  - [模块职责](#flutter-模块职责)
  - [核心服务](#核心服务)
  - [核心类说明](#flutter-核心类说明)
  - [路由系统](#路由系统)
- [后端架构 (Go/Kratos)](#后端架构-gokratos)
  - [目录结构](#后端目录结构)
  - [API 契约](#api-契约)
  - [业务逻辑层 (biz)](#业务逻辑层-biz)
  - [数据层 (data)](#数据层-data)
  - [服务层 (service)](#服务层-service)
  - [核心模型](#核心模型)
- [管理台 (moe-admin)](#管理台-moe-admin)
- [依赖关系](#依赖关系)
- [运行方式](#运行方式)

---

## 项目概述

**Moe Social (萌社交)** 是一款复合型社交产品，核心特性包括：

- **萌系社交主线**：动态流、帖子、评论、点赞、关注
- **AI 智能体**：AI 聊天机器人、酒馆化能力、角色卡广场
- **虚拟形象与 VIP 商业化**：Avatar 系统、抽卡、VIP 订阅
- **AutoGLM 自动化**：任务规划与设备操作自动化
- **实时通信**：私信、WebSocket、语音通话 (Agora)

支持平台：Android、iOS、Web、Windows、macOS、Linux

---

## 技术栈

| 层级 | 技术 |
|------|------|
| **客户端** | Flutter 3.x、Dart、Provider、Material Design |
| **后端** | Go 1.25+、Kratos v2.8.4、Protocol Buffers、GORM、MySQL |
| **实时通信** | WebSocket、Agora RTC |
| **认证** | JWT、飞书 OAuth、微信 OAuth |
| **数据库** | MySQL (生产)、SQLite (开发/测试) |
| **管理台** | React 19、TypeScript、Vite、React Router |

---

## 项目结构

```
moe_social/
├── lib/                    # Flutter 客户端源码
├── backend/                # Go/Kratos 后端服务
├── moe-admin/              # React 管理后台
├── docs/                   # 项目文档
├── assets/                  # 静态资源 (头像、礼品等)
├── android/                # Android 平台代码
├── ios/                    # iOS 平台代码
├── e2e/                    # 端到端测试
└── AGENTS.md               # 开发规范与命令
```

---

## 前端架构 (Flutter)

### Flutter 模块职责

```
lib/
├── main.dart                    # 应用入口、初始化流程
├── app/
│   ├── app_routes.dart          # 路由配置 (命名路由)
│   └── main_shell.dart          # 主页面框架
├── auth_service.dart            # 认证服务 (登录/注册/OAuth)
├── pages/                       # 页面按域划分
│   ├── auth/                    # 认证相关 (登录/注册/OAuth)
│   ├── feed/                    # 动态流 (首页/评论/发帖)
│   ├── chat/                    # 聊天 (私信/消息中心/语音通话)
│   ├── ai/                      # AI 功能 (AI 聊天/角色卡/记忆管理)
│   ├── commerce/                # 商业化 (VIP/钱包/抽卡/订单)
│   ├── profile/                 # 用户资料
│   ├── community/               # 社区 (兴趣小组)
│   ├── game/                    # 游戏 (扫雷/游戏房间)
│   ├── autoglm/                 # AutoGLM 自动化
│   ├── checkin/                 # 签到与等级
│   ├── notifications/           # 通知中心
│   └── settings/                # 设置
├── services/                    # 业务服务层
├── providers/                   # Provider 状态管理
├── widgets/                     # 可复用组件
├── models/                      # 数据模型
├── utils/                       # 工具函数
├── theme/                       # 主题配置
└── autoglm/                     # AutoGLM 客户端
```

### Flutter 模块职责

| 模块 | 路径 | 职责 |
|------|------|------|
| **认证** | `lib/auth_service.dart` | JWT 管理、登录/注册、OAuth (飞书/微信) |
| **API** | `lib/services/api_service.dart` | HTTP 请求封装、Token 管理、错误处理 |
| **动态** | `lib/services/post_service.dart` | 帖子 CRUD、点赞、评论 |
| **用户** | `lib/models/user.dart` | 用户数据模型 |
| **WebSocket** | `lib/services/ws_channel_connector.dart` | 实时消息推送 |
| **AI** | `lib/services/ai_*.dart` | AI 聊天、推理、记忆管理 |
| **VIP** | `lib/services/vip_*.dart` | VIP 订阅、订单、钱包 |

### 核心服务

#### AuthService (`lib/auth_service.dart`)

认证服务核心类，负责用户认证全流程：

```dart
class AuthService {
  static Future<void> init()                    // 初始化，从本地存储加载登录状态
  static Future<AuthResult> login()             // 邮箱/用户名登录
  static Future<AuthResult> loginWithWechat()   // 微信 OAuth 登录
  static Future<AuthResult> loginWithFeishu()   // 飞书 OAuth 登录
  static Future<AuthResult> register()          // 用户注册
  static void logout()                           // 登出
  static Future<User> getUserInfo()             // 获取用户资料
  static String? get currentUser                 // 当前用户 ID
  static String? get token                       // JWT Token
  static bool get isLoggedIn                    // 登录状态
}
```

#### ApiService (`lib/services/api_service.dart`)

HTTP API 客户端，处理所有后端通信：

```dart
class ApiService {
  static Future<void> initRemoteProductionBaseUrl()  // 初始化 API 地址
  static void setToken(String?)                        // 设置 JWT Token
  static Future<Map> get/post/put/delete()             // 基础请求方法

  // 用户相关
  static Future<User> getUserInfo()                   // 获取用户信息
  static Future<User> updateUserInfo()                // 更新用户资料
  static Future<Map> login/register()                 // 认证

  // 动态相关
  static Future<Map> getPosts()                       // 获取帖子列表
  static Future<Post> createPost()                    // 创建帖子
  static Future<Post> toggleLike()                    // 点赞/取消点赞

  // 社交相关
  static Future<void> followUser()                   // 关注用户
  static Future<List> getFriends()                    // 获取好友列表
  static Future<void> sendPrivateMessage()            // 发送私信

  // VIP/商业
  static Future<List<VipPlan>> getVipPlans()          // 获取 VIP 套餐
  static Future<VipOrder> createVipOrder()            // 创建 VIP 订单

  // 文件上传
  static Future<String> uploadImage()                 // 上传图片
}
```

### Flutter 核心类说明

| 类/文件 | 职责 | 关键方法 |
|---------|------|---------|
| `SplashScreen` | 启动闪屏，启动初始化 | `_initializeApp()` |
| `AuthService` | 认证状态管理 | `login()`, `logout()`, `getUserInfo()` |
| `ApiService` | API 请求封装 | `get()`, `post()`, `setToken()` |
| `User` (model) | 用户数据模型 | `fromJson()`, `toJson()` |
| `Post` (model) | 帖子数据模型 | `fromJson()`, `toJson()` |
| `ws_channel_connector` | WebSocket 客户端 | `connect()`, `disconnect()`, `sendMessage()` |
| `ai_chat_gateway_service` | AI 聊天网关 | 消息收发、上下文管理 |
| `memory_service` | 用户记忆管理 | `store()`, `retrieve()`, `search()` |

### 路由系统

路由配置在 `lib/app/app_routes.dart`，使用命名路由 + 延迟加载：

```dart
Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/login': (context) => const LoginPage(),
    '/register': (context) => const RegisterPage(),
    '/home': (context) => const MainPage(),
    '/profile': (context) => const ProfilePage(),
    '/vip-center': (context) => _deferred(() => VipCenterPage()),
    // ... 更多路由
  };
}
```

延迟加载用于大型页面（VIP、抽卡、扫码等），减少初始包体积。

---

## 后端架构 (Go/Kratos)

### 后端目录结构

```
backend/
├── api/                          # Proto 契约定义 (SSOT)
│   └── <domain>/v1/*.proto       # 按域拆分：moe, post, user, chat, gift...
├── cmd/                          # 入口命令
├── config/                       # 配置文件
├── internal/
│   ├── biz/                      # 业务逻辑层
│   │   ├── user/                 # 用户业务
│   │   ├── post/                 # 帖子业务
│   │   ├── chat/                 # 聊天业务
│   │   ├── ai/                   # AI 业务
│   │   ├── moe/                  # Moe Agent 业务
│   │   ├── vip/                  # VIP 业务
│   │   ├── gift/                 # 礼物业务
│   │   └── ...
│   ├── data/                     # 数据访问层
│   ├── service/                  # 服务层 (HTTP Handler)
│   ├── server/                   # HTTP Server 装配
│   └── model/                    # 数据库模型 (GORM)
├── pkg/                          # 内部工具包
│   ├── moe/                      # Moe 核心运行时
│   ├── memory/                   # 记忆系统
│   └── llminference/             # LLM 推理客户端
├── utils/                        # 工具函数
└── Makefile                      # 构建命令
```

### API 契约

API 定义使用 **Protocol Buffers**，是唯一的契约 SSOT：

| Proto 文件 | 域 | 主要服务 |
|-----------|-----|---------|
| `api/moe/v1/moe.proto` | Moe Agent | `MoeAdmin` - Agent 运行时、脑状态、Flow |
| `api/post/v1/post.proto` | 帖子 | 动态 CRUD、点赞、评论 |
| `api/user/v1/user.proto` | 用户 | 认证、资料、关注 |
| `api/chat/v1/chat.proto` | 聊天 | 私信、WebSocket |
| `api/gift/v1/gift.proto` | 礼物 | 礼物商城、赠送 |
| `api/vip/v1/vip.proto` | VIP | 套餐、订单 |
| `api/notify/v1/notify.proto` | 通知 | 推送、站内通知 |
| `api/media/v1/media.proto` | 媒体 | 图片上传 |

### 业务逻辑层 (biz)

`internal/biz/` 是核心业务逻辑所在，按域划分：

| 域 | 路径 | 职责 |
|----|------|------|
| **user** | `biz/user/` | 用户注册/登录、OAuth、资料管理、关注/粉丝 |
| **post** | `biz/post/` | 动态发布、删除、点赞、评论 |
| **chat** | `biz/chat/` | 私信、WebSocket Hub、在线状态 |
| **ai** | `biz/ai/` | AI 聊天会话、推理配置 |
| **moe** | `biz/moe/` | Agent 运行时、脑状态 (Brain)、RPG、Flow 执行 |
| **llm** | `biz/llm/` | LLM 调用、记忆读写、Prompt 构建 |
| **vip** | `biz/vip/` | VIP 套餐、订单、续费 |
| **gift** | `biz/gift/` | 礼物购买、赠送、背包 |
| **checkin** | `biz/checkin/` | 签到、经验值、等级 |
| **achievement** | `biz/achievement/` | 成就解锁、徽章 |

### 数据层 (data)

`internal/data/` 实现数据持久化：

```go
// 典型 data 层结构
type UserRepo interface {
    FindByID(ctx context.Context, id string) (*model.User, error)
    FindByEmail(ctx context.Context, email string) (*model.User, error)
    Create(ctx context.Context, user *model.User) error
    Update(ctx context.Context, user *model.User) error
}
```

使用 GORM 作为 ORM，支持 MySQL 和 SQLite。

### 服务层 (service)

`internal/service/` 接收 HTTP 请求，调用 biz 层：

```
service/<domain>/
├── user.go           # AppService 结构体 + New()
├── user_auth.go      # 登录/注册
├── user_profile.go   # 资料管理
└── user_follow.go    # 关注关系
```

### 核心模型

数据库模型定义在 `backend/internal/model/`：

| 模型 | 文件 | 描述 |
|------|------|------|
| User | `user.go` | 用户账号、资料、设置 |
| Post | `post.go` | 动态内容 |
| Comment | `comment.go` | 评论 |
| Like | `like.go` | 点赞记录 |
| Follow | `follow.go` | 关注关系 |
| PrivateMessage | `private_message.go` | 私信 |
| Gift | `gift.go` | 礼物定义 |
| VipOrder | `vip_order.go` | VIP 订单 |
| Achievement | `achievement.go` | 成就定义 |
| UserMemory | `user_memory.go` | 用户记忆 |
| MoeAgentRuntime | `moe_agent_runtime.go` | AI Agent 运行时配置 |
| AiChatSession | `ai_chat_session.go` | AI 聊天会话 |

### Moe Agent 系统 (Brain)

Moe Agent 是核心 AI 能力，定义在 `pkg/moe/` 和 `biz/moe/`：

```go
// pkg/moe/runtime/agent.go
type AgentRuntime struct {
    AgentKey      string
    DisplayName   string
    BotUserID     string
    ModelName     string
    ToolsEnabled  bool
    Enabled       bool
}

// biz/moe/brain.go - 脑状态管理
type BrainGraph struct {
    Nodes []BrainGraphNode
    Edges []BrainGraphEdge
}

type BrainRPG struct {
    Level       int
    XP          int
    Skills      []BrainRpgSkill
    Fragments   []BrainRpgFragment
}
```

关键能力：
- **Brain Graph**：记忆知识图谱
- **Brain RPG**：角色扮演成长系统
- **Dream**：自动整理记忆的做梦机制
- **Flow**：可视化流程编排

---

## 管理台 (moe-admin)

React 19 + TypeScript + Vite 构建的管理后台：

```
moe-admin/
├── src/
│   ├── api/                # API 客户端
│   ├── components/         # React 组件
│   ├── config/menu.ts      # 菜单配置
│   ├── layout/             # 布局组件
│   ├── lib/                # 工具函数
│   └── App.tsx             # 应用入口
├── package.json
└── DESGIN.md
```

技术栈：
- React 19.2
- TypeScript 6.0
- React Router 7
- @xyflow/react (流程图)
- Recharts (图表)

---

## 依赖关系

### Flutter 依赖 (pubspec.yaml)

```yaml
dependencies:
  flutter: sdk
  provider: ^6.1.2              # 状态管理
  dio: ^5.4.0                   # HTTP 客户端
  shared_preferences: ^2.0.15   # 本地存储
  cached_network_image: ^3.4.1  # 图片缓存
  webview_flutter: ^4.10.0      # WebView
  flutter_svg: ^2.0.9           # SVG 渲染
  agora_rtc_engine: ^6.5.3      # 语音通话
  speech_to_text: ^7.0.0        # 语音转文字
  flutter_tts: ^3.8.5           # 文字转语音
  rive: ^0.14.6                 # 虚拟形象动画
  fluwx: ^5.7.5                 # 微信 SDK
  qr_flutter: ^4.1.0            # 二维码生成
  mobile_scanner: ^3.2.0        # 二维码扫描
```

### Go 依赖 (go.mod)

```go
require (
    github.com/go-kratos/kratos/v2 v2.8.4    // Web 框架
    github.com/golang-jwt/jwt/v5 v5.3.0      // JWT
    github.com/google/uuid v1.6.0             // UUID
    github.com/gorilla/websocket v1.5.3       // WebSocket
    gorm.io/driver/mysql v1.6.0               // MySQL 驱动
    gorm.io/gorm v1.30.5                      // ORM
    google.golang.org/grpc v1.78.0            // gRPC
    google.golang.org/protobuf v1.36.11       // Protobuf
)
```

---

## 运行方式

### Flutter 前端

```bash
# 安装依赖
flutter pub get

# 开发运行
flutter run

# 分析代码
flutter analyze

# 测试
flutter test

# 构建发布
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
flutter build windows      # Windows
flutter build macos        # macOS
```

### 后端服务

```bash
cd backend

# 安装依赖
go mod download

# 生成 Proto 代码
make gen

# 本地运行
make moe-social            # 单进程 HTTP :8888
make moe-social-dev        # + deploy-agent :19010

# 测试
go test ./...

# Docker 部署
docker compose -f docker-compose.binary.yml up -d
```

### 管理台

```bash
cd moe-admin

# 安装依赖
npm install

# 开发运行
npm run dev

# 构建
npm run build
```

### 环境配置

**Flutter API 地址**：`lib/utils/config.dart`

```dart
class AppConfig {
  static const bool isProduction = false;
  static const String productionUrl = 'https://api.moesocial.com';
  static const String developmentUrl = 'http://localhost:8888';
}
```

**后端配置**：`backend/config/config.yaml`

```yaml
server:
  http:
    addr: :8888
    timeout: 60s

database:
  dsn: root:password@tcp(localhost:3306)/moe_social?charset=utf8mb4

jwt:
  secret: your-secret-key
```

---

## 文档索引

| 文档 | 路径 |
|------|------|
| 项目总览 | [README.md](README.md) |
| 开发规范 | [AGENTS.md](AGENTS.md) |
| Code Review | [code_review.md](code_review.md) |
| 后端文档 | [backend/README.md](backend/README.md) |
| 后端架构 | [backend/LAYOUT.md](backend/LAYOUT.md) |
| 文档索引 | [docs/README.md](docs/README.md) |
| 记忆系统 | [docs/dev/用户记忆系统-OpenClaw式演进设计.md](docs/dev/用户记忆系统-OpenClaw式演进设计.md) |
| Kratos 迁移 | [docs/dev/kratos-migration-status.md](docs/dev/kratos-migration-status.md) |

---

*此文档由代码自动生成，如有更新请同步修改。*
