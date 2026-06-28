# Moe Social (萌社交) Code Wiki

> **项目版本**: 1.0.0+1  
> **最后更新**: 2026-06-28  
> **技术栈**: Flutter + Go/Kratos + React

---

## 目录

1. [项目概述](#1-项目概述)
2. [整体架构](#2-整体架构)
3. [前端架构（Flutter）](#3-前端架构flutter)
4. [后端架构（Go/Kratos）](#4-后端架构gokratos)
5. [管理台架构（React）](#5-管理台架构react)
6. [核心功能模块](#6-核心功能模块)
7. [数据库模型](#7-数据库模型)
8. [API 接口](#8-api-接口)
9. [依赖关系](#9-依赖关系)
10. [项目运行方式](#10-项目运行方式)
11. [开发规范与约定](#11-开发规范与约定)
12. [部署与运维](#12-部署与运维)

---

## 1. 项目概述

### 1.1 项目简介

Moe Social（萌社交）是一个**复合型社交产品**，采用萌系设计风格，融合了传统社交功能与AI智能体能力。项目使用 **Flutter** 构建跨平台客户端，**Go / Kratos** 构建后端服务，**React** 构建管理后台。

### 1.2 核心特性

| 类别 | 特性 |
|------|------|
| **社交主线** | 动态流、发帖、评论、点赞、话题、关注/粉丝、好友、私信 |
| **AI 能力** | AI 智能体、多模型聊天、用户记忆系统、Lorebook/世界书、角色卡广场 |
| **商业化** | VIP 会员、充值钱包、抽卡系统、虚拟形象、礼物系统 |
| **成长体系** | 签到、用户等级、成就徽章、经验值 |
| **实时通信** | WebSocket 实时消息、在线状态、语音通话（Agora RTC） |
| **多平台支持** | Android、iOS、Web、Windows、macOS、Linux |

### 1.3 技术栈总览

| 层级 | 技术选型 |
|------|----------|
| **客户端** | Flutter 3.x、Dart、Provider 状态管理、Material Design |
| **后端** | Go 1.25+、Kratos 框架、Protocol Buffers、GORM、MySQL |
| **管理台** | React 19、TypeScript、Vite、React Router、Recharts |
| **实时/媒体** | WebSocket、Agora RTC |
| **第三方集成** | 飞书 OAuth、微信 OAuth、fluwx |
| **CI/CD** | GitHub Actions、Docker |

---

## 2. 整体架构

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│                     客户端层 (Flutter)                    │
│  Android / iOS / Web / Windows / macOS / Linux           │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP / WebSocket
┌────────────────────────▼────────────────────────────────┐
│                   网关层 (Kratos HTTP)                    │
│              统一入口 :8888 (单进程)                       │
└────────────────────────┬────────────────────────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
┌───▼───┐          ┌────▼─────┐        ┌────▼─────┐
│ 业务  │          │  AI/Moe  │        │  管理台   │
│ 服务  │          │  服务     │        │  API     │
└───┬───┘          └────┬─────┘        └────┬─────┘
    │                    │                    │
┌───▼────────────────────▼────────────────────▼──────┐
│                   数据层 (GORM)                      │
│              MySQL / SQLite / Redis                  │
└──────────────────────────────────────────────────────┘
```

### 2.2 仓库目录结构

```
moe_social/
├── lib/                          # Flutter 客户端源码
│   ├── app/                      # 路由、主 Shell
│   ├── pages/                    # 按域划分的页面
│   ├── services/                 # 业务服务层
│   ├── providers/                # 状态管理
│   ├── widgets/                  # 通用组件
│   ├── models/                   # 数据模型
│   ├── utils/                    # 工具函数
│   ├── theme/                    # 主题系统
│   └── main.dart                 # 应用入口
├── backend/                      # Go 后端服务
│   ├── api/                      # Protocol Buffers 契约
│   ├── cmd/                      # 命令行入口
│   ├── internal/                 # 内部实现
│   │   ├── biz/                  # 业务逻辑层
│   │   ├── data/                 # 数据访问层
│   │   ├── service/              # 服务层
│   │   └── server/               # HTTP 服务器
│   ├── model/                    # 数据库模型
│   ├── pkg/                      # 公共包
│   ├── utils/                    # 工具函数
│   ├── config/                   # 配置文件
│   └── Makefile                  # 构建脚本
├── moe-admin/                    # React 管理后台
│   ├── src/
│   │   ├── pages/                # 页面组件
│   │   ├── components/           # 通用组件
│   │   ├── lib/                  # 工具库
│   │   ├── api/                  # API 客户端
│   │   └── main.tsx              # 入口
│   └── package.json
├── docs/                         # 项目文档
├── e2e/                          # E2E 测试
├── test/                         # Flutter 单元测试
├── website/official/             # 静态产品官网
└── AGENTS.md                     # 仓库贡献指南
```

---

## 3. 前端架构（Flutter）

### 3.1 架构概述

前端采用 **Provider** 状态管理，按**领域驱动设计**组织代码，整体遵循 MVC 模式变体。

### 3.2 目录结构详解

| 目录 | 职责 | 关键文件 |
|------|------|----------|
| `lib/app/` | 应用路由与主框架 | [app_routes.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/app/app_routes.dart), [main_shell.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/app/main_shell.dart) |
| `lib/pages/` | 页面层（按领域划分） | 见 3.3 节 |
| `lib/services/` | 业务服务层（API 调用、业务逻辑） | 见 3.4 节 |
| `lib/providers/` | 状态管理（ChangeNotifier） | [theme_provider.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/providers/theme_provider.dart), [game_provider.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/providers/game_provider.dart) |
| `lib/widgets/` | 通用 UI 组件 | 见 3.5 节 |
| `lib/models/` | 数据模型（DTO） | 见 3.6 节 |
| `lib/utils/` | 工具函数 | [config.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/utils/config.dart), [api_datetime.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/utils/api_datetime.dart) |
| `lib/theme/` | 主题系统 | [moe_theme_extension.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/theme/moe_theme_extension.dart), [moe_tokens.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/theme/moe_tokens.dart) |

### 3.3 页面模块（pages/）

按领域划分的页面目录：

| 领域 | 目录 | 主要功能 |
|------|------|----------|
| **认证** | `pages/auth/` | 登录、注册、忘记密码、飞书/微信 OAuth |
| **动态流** | `pages/feed/` | 首页动态、发帖、评论、话题 |
| **AI 聊天** | `pages/ai/` | AI 智能体列表、聊天、Lorebook、记忆管理 |
| **私信** | `pages/chat/` | 会话列表、私信、语音通话 |
| **商业化** | `pages/commerce/` | VIP 中心、钱包、充值、抽卡、背包 |
| **社区** | `pages/community/` | 兴趣小组、社区讨论 |
| **个人资料** | `pages/profile/` | 个人主页、编辑资料、关注/粉丝、好友 |
| **成长** | `pages/checkin/` | 签到、用户等级 |
| **成就** | `pages/achievements/` | 成就徽章系统 |
| **发现** | `pages/discover/` | 发现页、匹配、游戏 |
| **游戏** | `pages/game/` | 游戏大厅、扫雷、游戏房间 |
| **设置** | `pages/settings/` | 账号安全、外观、AI 设置、隐私 |
| **通知** | `pages/notifications/` | 通知中心 |
| **云相册** | `pages/gallery/` | 云相册 |
| **扫码** | `pages/scan/` | 二维码扫描 |
| **AutoGLM** | `pages/autoglm/` | 自动化实验系统 |

### 3.4 服务层（services/）

服务层封装业务逻辑和 API 调用，主要服务包括：

| 服务 | 文件 | 职责 |
|------|------|------|
| API 服务 | [api_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/api_service.dart) | 基础 HTTP 请求封装 |
| 认证服务 | `auth_service.dart` | 用户认证、JWT 管理 |
| 帖子服务 | [post_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/post_service.dart) | 动态、帖子、评论相关 |
| AI 聊天网关 | `ai_chat_gateway_service.dart` | AI 聊天请求调度 |
| AI 推理服务 | `ai_inference_service.dart` | LLM 推理调用 |
| AI 记忆服务 | [memory_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/memory_service.dart) | 用户记忆管理 |
| AI 工具运行时 | [ai_tool_runtime.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/ai_tool_runtime.dart) | AI 工具调用执行 |
| 头像服务 | [avatar_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/avatar_service.dart) | 虚拟形象管理 |
| 通知服务 | `notification_service.dart` | 本地与推送通知 |
| 在线状态 | [presence_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/presence_service.dart) | 用户在线状态 |
| 推送服务 | `push_notification_service.dart` | 推送通知 |
| 聊天推送 | `chat_push_service.dart` | 私信实时推送 |
| 行为分析 | `behavior_analytics_service.dart` | 用户行为埋点 |
| 成就钩子 | `achievement_hooks.dart` | 成就触发检测 |
| 微信 SDK | `wechat_sdk_service.dart` | 微信 SDK 集成 |
| 更新服务 | [update_service.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/update_service.dart) | 应用内更新检测 |
| Rive 引导 | [rive_bootstrap.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/services/rive_bootstrap.dart) | Rive 动画初始化 |

### 3.5 通用组件（widgets/）

| 组件 | 说明 |
|------|------|
| `moe_page_scaffold.dart` | 页面脚手架（统一 AppBar、背景） |
| `moe_bottom_bar.dart` | 底部导航栏 |
| `post_card.dart` | 帖子卡片 |
| `avatar_image.dart` | 头像组件 |
| `dynamic_avatar.dart` | 动态虚拟形象 |
| `like_button.dart` | 点赞按钮 |
| `moe_toast.dart` | Toast 提示 |
| `moe_loading.dart` | 加载状态 |
| `moe_empty_state.dart` | 空状态 |
| `moe_error_state.dart` | 错误状态 |
| `gift_animation.dart` | 礼物动画 |
| `home_banner.dart` | 首页 Banner |
| `trending_topics.dart` | 热门话题 |
| `splash_screen.dart` | 启动闪屏 |
| `ai/message_bubble.dart` | AI 聊天气泡 |

### 3.6 数据模型（models/）

主要数据模型：

| 模型 | 文件 | 说明 |
|------|------|------|
| 用户 | `user.dart` | 用户基本信息 |
| 帖子 | `post.dart` | 动态/帖子 |
| 评论 | `comment.dart` | 评论 |
| 通知 | `notification.dart` | 通知消息 |
| AI 智能体 | `ai_agent.dart` | AI 代理配置 |
| AI 聊天消息 | `ai_chat_message.dart` | AI 聊天记录 |
| AI 记忆 | `ai_memory.dart` | 记忆条目 |
| VIP 套餐 | `vip_plan.dart` | VIP 会员计划 |
| VIP 订单 | `vip_order.dart` | VIP 购买订单 |
| 礼物 | `gift.dart` | 虚拟礼物 |
| 用户等级 | `user_level.dart` | 等级与经验 |
| 成就徽章 | `achievement_badge.dart` | 成就系统 |

### 3.7 应用启动流程

应用入口为 [main.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/main.dart)，启动流程如下：

```
main()
  ↓
runZonedGuarded()   // 全局错误捕获
  ↓
SplashScreenWrapper  // 闪屏 + 初始化
  ├─ API Config 初始化
  ├─ Auth Service 初始化（恢复登录态）
  ├─ WeChat SDK 注册
  ├─ Theme Provider 初始化
  ├─ Local Notifications 初始化
  ├─ Remote Control 初始化
  └─ Push Notifications 初始化
  ↓
MyApp (MultiProvider)
  ├─ ThemeProvider
  ├─ NotificationProvider
  ├─ DeviceInfoProvider
  ├─ LoadingProvider
  ├─ VirtualAvatarProvider
  ├─ CheckInProvider
  ├─ UserLevelProvider
  ├─ GameProvider
  └─ MainNavController
  ↓
MaterialApp (routes: buildAppRoutes)
  ↓
initialRoute: 已登录 → /home，未登录 → /login
```

### 3.8 状态管理

使用 **Provider** 包进行状态管理，主要 Provider：

| Provider | 职责 |
|----------|------|
| `ThemeProvider` | 主题切换、深色模式 |
| `NotificationProvider` | 通知状态管理 |
| `DeviceInfoProvider` | 设备信息 |
| `LoadingProvider` | 全局加载状态 |
| `VirtualAvatarProvider` | 虚拟形象状态 |
| `CheckInProvider` | 签到状态 |
| `UserLevelProvider` | 用户等级 |
| `GameProvider` | 游戏状态 |
| `MainNavController` | 主导航控制 |

### 3.9 主要依赖

| 依赖包 | 版本 | 用途 |
|--------|------|------|
| `flutter` | SDK | 框架核心 |
| `provider` | ^6.1.2 | 状态管理 |
| `http` / `dio` | ^1.1.0 / ^5.4.0 | HTTP 网络请求 |
| `shared_preferences` | 2.0.15 | 本地存储 |
| `cached_network_image` | ^3.4.1 | 图片缓存 |
| `web_socket_channel` | ^2.4.0 | WebSocket 通信 |
| `agora_rtc_engine` | ^6.5.3 | 语音通话 |
| `flutter_svg` | ^2.0.9 | SVG 渲染 |
| `rive` | ^0.14.6 | Rive 动画（虚拟形象） |
| `fluwx` | ^5.7.5 | 微信 SDK |
| `sqflite` | ^2.3.0 | 本地数据库 |
| `flutter_secure_storage` | ^9.2.2 | 安全存储 |
| `qr_flutter` | ^4.1.0 | 二维码生成 |
| `mobile_scanner` | ^3.2.0 | 二维码扫描 |
| `intl` | ^0.19.0 | 国际化 |
| `lottie` | ^3.1.0 | Lottie 动画 |

---

## 4. 后端架构（Go/Kratos）

### 4.1 架构概述

后端采用 **Kratos** 微服务框架，**单进程 HTTP** 部署（`:8888`），遵循 **service → biz → data** 分层架构，API 契约通过 **Protocol Buffers** 定义。

### 4.2 分层架构

```
┌──────────────────────────────────────┐
│         Client (Flutter App)          │
└──────────────────┬───────────────────┘
                   │ HTTP / WebSocket
┌──────────────────▼───────────────────┐
│       internal/server/                │
│  ├─ protohttp/  (Proto HTTP Handlers) │
│  └─ transport/  (非 JSON handlers)    │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│       internal/service/               │
│  (Service Layer - 用例编排)            │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│       internal/biz/                   │
│  (Business Logic - 核心业务逻辑)       │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│       internal/data/                  │
│  (Data Access - 数据访问/GORM)         │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│         MySQL / SQLite                │
└──────────────────────────────────────┘
```

### 4.3 目录结构详解

| 目录 | 职责 |
|------|------|
| `api/<domain>/v1/` | Protocol Buffers 契约定义（SSOT） |
| `cmd/moe-social/` | 主程序入口 |
| `cmd/deploy-agent/` | 部署运维 Agent 入口 |
| `cmd/migrate/` | 数据库迁移入口 |
| `internal/server/` | HTTP 服务器配置与路由注册 |
| `internal/biz/` | 业务逻辑层（按领域划分） |
| `internal/data/` | 数据访问层（Repository 实现） |
| `internal/service/` | 服务层（API 实现） |
| `model/` | GORM 数据模型定义 |
| `pkg/` | 可复用公共包 |
| `utils/` | 工具函数 |
| `config/` | 配置文件 |
| `deploy/` | 部署运维相关 |
| `scripts/` | 生成/辅助脚本 |

### 4.4 API 模块（api/）

API 契约使用 Protocol Buffers 定义，每个领域一个模块：

| 模块 | proto 文件 | 主要功能 |
|------|------------|----------|
| **user** | `user/v1/user_messages.proto` | 用户认证、资料、关注、好友 |
| **post** | `post/v1/post.proto` | 动态、帖子、点赞、举报 |
| **comment** | `comment/v1/comment.proto` | 评论、回复 |
| **chat** | `chat/v1/private_message.proto` | 私信、WebSocket |
| **notify** | `notify/v1/notify.proto` | 通知中心 |
| **gift** | `gift/v1/gift.proto` | 礼物系统 |
| **vip** | `vip/v1/vip_messages.proto` | VIP 会员、订单 |
| **checkin** | `checkin/v1/checkin.proto` | 签到、等级、经验 |
| **achievement** | `achievement/v1/achievement.proto` | 成就系统 |
| **community** | `community/v1/community.proto` | 社区、兴趣小组 |
| **ai** | `ai/v1/ai_messages.proto` | AI 聊天、智能体 |
| **llm** | `llm/v1/llm_messages.proto` | LLM 推理、记忆系统 |
| **moe** | `moe/v1/moe.proto` | Moe AI 大脑、Bot 运行时 |
| **media** | `media/v1/media.proto` | 媒体上传、云存储 |
| **admin** | `admin/v1/admin_messages.proto` | 管理后台 API |
| **behavior** | `behavior/v1/behavior.proto` | 用户行为埋点 |
| **content** | `content/v1/content.proto` | AI 内容生成 |
| **landing** | `landing/v1/landing.proto` | 落地页、反馈 |
| **platform** | `platform/v1/platform_messages.proto` | 平台配置 |

### 4.5 业务逻辑层（internal/biz/）

按领域划分的业务逻辑包：

| 领域 | 目录 | 核心功能 |
|------|------|----------|
| **用户** | `biz/user/` | 认证(OAuth)、资料、关注、好友、钱包 |
| **帖子** | `biz/post/` | 创建/查询/删除、点赞、话题、举报 |
| **评论** | `biz/comment/` | 评论创建、列表、点赞 |
| **私信** | `biz/chat/` | 消息、WebSocket Hub、在线状态、匹配队列 |
| **礼物** | `biz/gift/` | 礼物查询、购买、赠送 |
| **VIP** | `biz/vip/` | 套餐管理、订单、状态 |
| **签到** | `biz/checkin/` | 签到、等级、经验值 |
| **成就** | `biz/achievement/` | 成就查询、解锁 |
| **AI** | `biz/ai/` | AI 聊天会话、用户配置 |
| **LLM** | `biz/llm/` | 推理、记忆、模型管理 |
| **Moe 大脑** | `biz/moe/` | AI Brain、Bot 运行时、工具执行、RPG |
| **通知** | `biz/notify/` | 通知收件箱、内容通知 |
| **社区** | `biz/community/` | 兴趣小组、社区讨论 |
| **媒体** | `biz/media/` | 图片上传、鉴权 |
| **管理台** | `biz/admin/` | 管理员账号、审核、数据看板 |
| **语音** | `biz/voice/` | Agora 语音通话 Token |
| **行为** | `biz/behavior/` | 用户行为追踪 |
| **落地页** | `biz/landing/` | 反馈收集 |

### 4.6 核心公共包（pkg/）

| 包 | 职责 |
|----|------|
| `pkg/moe/brain/` | Moe AI 大脑核心（心智、策略、RPG、质量） |
| `pkg/moe/core/` | 核心执行引擎、分层、Token 管理 |
| `pkg/moe/runtime/` | Agent 运行时、依赖注入、阶段管理 |
| `pkg/moe/tools/` | 工具注册表、执行器 |
| `pkg/moe/flowexec/` | 流程图执行引擎 |
| `pkg/memory/` | 记忆系统（嵌入、搜索、重排序、图结构） |
| `pkg/llminference/` | LLM 推理客户端 |
| `pkg/localmodels/` | 本地模型目录 |
| `pkg/achievement/` | 成就引擎 |
| `pkg/level/` | 等级经验系统 |
| `pkg/calendar/` | 日历（上海时区） |
| `pkg/handdraw/` | 手绘图光栅化 |

### 4.7 数据库模型（model/）

| 模型 | 文件 | 说明 |
|------|------|------|
| User | [user.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/user.go) | 用户表 |
| Post | [post.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/post.go) | 帖子表 |
| Comment | [comment.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/comment.go) | 评论表 |
| Like | [like.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/like.go) | 点赞表 |
| Follow | [follow.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/follow.go) | 关注关系 |
| FriendRequest | [friend_request.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/friend_request.go) | 好友请求 |
| PrivateMessage | [private_message.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/private_message.go) | 私信 |
| Notification | [notification.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/notification.go) | 通知 |
| Gift | [gift.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/gift.go) | 礼物 |
| UserGiftStock | [user_gift_stock.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/user_gift_stock.go) | 用户礼物库存 |
| VipPlan | [vip_plan.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/vip_plan.go) | VIP 套餐 |
| VipOrder | [vip_order.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/vip_order.go) | VIP 订单 |
| VipRecord | [vip_record.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/vip_record.go) | VIP 记录 |
| UserLevel | [user_level.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/user_level.go) | 用户等级 |
| Achievement | [achievement.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/achievement.go) | 成就 |
| AiChatSession | [ai_chat_session.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/ai_chat_session.go) | AI 聊天会话 |
| UserMemory | [user_memory.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/user_memory.go) | 用户记忆 |
| MoeAgentRuntime | [moe_agent_runtime.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/moe_agent_runtime.go) | Moe Agent 运行时 |
| MoeBotEpisode | [moe_bot_episode.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/moe_bot_episode.go) | Bot 剧集 |
| MoeToolCall | [moe_tool_call.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/moe_tool_call.go) | 工具调用记录 |
| Group | [group.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/group.go) | 社区组 |
| Avatar | [avatar.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/avatar.go) | 头像配置 |
| Transaction | [transaction.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/transaction.go) | 交易记录 |
| AdminAccount | [admin_account.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/admin_account.go) | 管理员账号 |
| AdminAuditLog | [admin_audit_log.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/admin_audit_log.go) | 审核日志 |
| PostReport | [post_report.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/post_report.go) | 帖子举报 |
| UserBehavior | [user_behavior.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/model/user_behavior.go) | 用户行为 |

### 4.8 HTTP 服务器装配

入口文件：[internal/server/http.go](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/server/http.go)

装配顺序：
```
NewHTTPServer()
  ├─ CORS 过滤器
  ├─ EnvelopeResponseEncoder（统一响应封装）
  ├─ RegisterOpsHTTP（运维接口）
  ├─ RegisterProtoHTTP（Proto HTTP 路由）
  ├─ RegisterDocsHTTP（Swagger 文档）
  └─ RegisterTransportHTTP（OAuth/WS/SSE）
```

### 4.9 主要依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| `go-kratos/kratos/v2` | v2.8.4 | 微服务框架 |
| `gorm.io/gorm` | v1.30.5 | ORM 框架 |
| `gorm.io/driver/mysql` | v1.6.0 | MySQL 驱动 |
| `golang-jwt/jwt/v5` | v5.3.0 | JWT 认证 |
| `gorilla/websocket` | v1.5.3 | WebSocket |
| `google.golang.org/protobuf` | v1.36.11 | Protocol Buffers |
| `google.golang.org/grpc` | v1.78.0 | gRPC |
| `spf13/viper` | v1.21.0 | 配置管理 |
| `robfig/cron/v3` | v3.0.1 | 定时任务 |
| `AgoraIO-Community/go-tokenbuilder` | v1.3.0 | Agora Token 生成 |

---

## 5. 管理台架构（React）

### 5.1 架构概述

管理后台使用 **React 19 + TypeScript + Vite** 构建，采用轻量级 Element 风格设计，通过 Deploy Agent 代理后端 API。

### 5.2 目录结构

```
moe-admin/
├── src/
│   ├── api/                  # API 客户端
│   │   ├── adminClient.ts    # 管理台 API
│   │   └── deployClient.ts   # 部署运维 API
│   ├── pages/                # 页面组件（按功能划分）
│   ├── components/           # 通用组件
│   ├── lib/                  # 工具库与业务逻辑
│   ├── context/              # React Context
│   ├── hooks/                # 自定义 Hooks
│   ├── layout/               # 布局组件
│   ├── config/               # 配置
│   ├── ui/                   # UI 基础组件
│   ├── styles/               # 样式文件
│   ├── types/                # TypeScript 类型
│   ├── App.tsx               # 根组件
│   └── main.tsx              # 入口
├── public/                   # 静态资源
├── index.html
└── package.json
```

### 5.3 主要页面（pages/）

| 页面 | 文件 | 功能 |
|------|------|------|
| **登录** | `LoginPage.tsx` | 管理员登录 |
| **仪表盘** | `DashboardPage.tsx` | 数据概览 |
| **用户管理** | `UsersPage.tsx` | App 用户管理 |
| **帖子管理** | `PostsPage.tsx` | 内容审核、帖子管理 |
| **评论管理** | `CommentsPage.tsx` | 评论审核 |
| **礼物管理** | `GiftsPage.tsx` | 礼物配置 |
| **VIP 管理** | `VipPlansPage.tsx` | VIP 套餐管理 |
| **订单管理** | `WalletOrdersPage.tsx` | 充值订单 |
| **成长管理** | `GrowthPage.tsx` | 等级、成就 |
| **公告管理** | `AnnouncementsPage.tsx` | 系统公告 |
| **通知管理** | `NotifyPage.tsx` | 推送通知 |
| **AI Agent** | `AiAgentsPage.tsx` | AI 智能体管理 |
| **AI 聊天日志** | `AiChatLogsPage.tsx` | 聊天记录查看 |
| **Moe Bot** | `MoeBotsPage.tsx` | Bot 配置 |
| **Moe Brain** | `MoeBrainPage.tsx` | AI 大脑监控 |
| **Bot 流程图** | `MoeBotFlowPage.tsx` | 可视化流程图编辑 |
| **记忆工作台** | `LearningWorkbenchPage.tsx` | 记忆学习管理 |
| **社区管理** | `CommunityGroupsPage.tsx` | 兴趣小组管理 |
| **标签中心** | `TagsCenterPage.tsx` | 话题标签管理 |
| **反馈管理** | `FeedbackPage.tsx` | 用户反馈 |
| **举报管理** | `ReportsPage.tsx` | 内容举报 |
| **媒体库** | `MediaGalleryPage.tsx` | 媒体资源管理 |
| **管理员账号** | `AdminAccountsPage.tsx` | 管理员管理 |
| **菜单管理** | `MenusPage.tsx` | 菜单配置 |
| **审核日志** | `AuditLogsPage.tsx` | 操作日志 |
| **数据分析** | `AnalyticsPage.tsx` | 数据统计图表 |
| **构建发布** | `BuildPage.tsx` | CI/CD 构建 |
| **Docker 管理** | `DockerPage.tsx` | 容器管理 |
| **发布管理** | `ReleasePage.tsx` | 版本发布 |
| **任务管理** | `JobsPage.tsx` | 运维任务 |
| **RPC 监控** | `RpcPage.tsx` | RPC 状态监控 |
| **平台配置** | `PlatformPage.tsx` | 平台配置 |
| **数据目录** | `DataCatalogPage.tsx` | 数据模型浏览 |

### 5.4 核心组件（components/）

| 组件 | 说明 |
|------|------|
| `AppShell.tsx` | 主布局框架 |
| `SidebarNav.tsx` | 侧边导航栏 |
| `AdminTable.tsx` | 通用数据表格 |
| `AdminPanel.tsx` | 面板容器 |
| `AdminToolbar.tsx` | 工具栏 |
| `AdminFormDrawer.tsx` | 表单抽屉 |
| `PageHead.tsx` | 页面头部 |
| `UserCell.tsx` | 用户单元格 |
| `PostContentPreview.tsx` | 帖子内容预览 |
| `BrainPipelinePanel.tsx` | Brain 管线面板 |
| `BrainRpgPanel.tsx` | RPG 面板 |
| `BotFlowCanvas.tsx` | Bot 流程图画布 |
| `MemoryInfluencePanel.tsx` | 记忆影响面板 |
| `MoeToolCallsPanel.tsx` | 工具调用面板 |
| `DayTrendChart.tsx` | 日趋势图表 |
| `ErrorBoundary.tsx` | 错误边界 |

### 5.5 工具库（lib/）

| 模块 | 说明 |
|------|------|
| `adminApi.ts` | 管理台 API 封装 |
| `adminSession.ts` | 管理员会话管理 |
| `apiResponse.ts` | API 响应处理 |
| `apiTarget.ts` | API 目标环境切换 |
| `brainData.ts` | Brain 数据处理 |
| `brainRpgData.ts` | RPG 数据 |
| `botFlowData.ts` | Bot 流程图数据 |
| `moePipelineWs.ts` | Pipeline WebSocket |
| `pipelineData.ts` | 管线数据 |
| `schemaActions.ts` | Schema 操作 |
| `storage.ts` | 本地存储 |
| `format.ts` | 格式化工具 |
| `mediaUrl.ts` | 媒体 URL 处理 |

### 5.6 主要依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| `react` | ^19.2.6 | UI 框架 |
| `react-dom` | ^19.2.6 | DOM 渲染 |
| `react-router-dom` | ^7.15.1 | 路由管理 |
| `@xyflow/react` | ^12.10.2 | 流程图（React Flow） |
| `recharts` | ^2.15.4 | 图表库 |
| `typescript` | ~6.0.2 | TypeScript |
| `vite` | ^8.0.12 | 构建工具 |

---

## 6. 核心功能模块

### 6.1 AI 智能体与记忆系统

#### 架构层次

```
┌─────────────────────────────────┐
│        Flutter 前端               │
│  ├─ AI 聊天页面                   │
│  ├─ 记忆管理器                    │
│  └─ Lorebook 编辑器               │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│       后端 biz/llm/              │
│  ├─ platform_chat.go             │
│  ├─ memory_read/write.go         │
│  ├─ memory_embeddings_api.go     │
│  └─ models.go                    │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│       pkg/memory/                │
│  ├─ 混合检索 (hybrid.go)         │
│  ├─ 嵌入搜索 (search.go)         │
│  ├─ 图结构记忆 (graph.go)        │
│  ├─ 重排序 (rerank.go)           │
│  └─ 启发式提取 (heuristic.go)    │
└─────────────────────────────────┘
```

#### 关键组件

| 组件 | 位置 | 功能 |
|------|------|------|
| **LLM 推理** | `biz/llm/inference.go` | 多模型推理调度 |
| **记忆写入** | `biz/llm/memory_write.go` | 对话后记忆提取与存储 |
| **记忆读取** | `biz/llm/memory_read.go` | 上下文记忆检索 |
| **混合检索** | `pkg/memory/hybrid.go` | 向量 + 关键词混合检索 |
| **记忆图** | `pkg/memory/graph.go` | 实体关系图结构 |
| **Moe Brain** | `pkg/moe/brain/` | AI 大脑核心心智 |
| **Agent 运行时** | `pkg/moe/runtime/` | Agent 执行引擎 |
| **工具系统** | `pkg/moe/tools/` | 工具注册表与执行器 |

### 6.2 实时通信系统

#### WebSocket 架构

```
┌─────────────────────────────────────────┐
│              Flutter 客户端               │
│  ws_channel_connector.dart               │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│         biz/chat/                        │
│  ├─ ws_hub.go          (Hub 中心)        │
│  ├─ ws_chat_serve.go   (聊天消息)        │
│  ├─ ws_presence_serve.go (在线状态)      │
│  ├─ ws_world_serve.go  (世界频道)        │
│  └─ ws_remote_serve.go (远程控制)        │
└──────────────────────────────────────────┘
```

#### 功能模块

| 功能 | 说明 |
|------|------|
| **实时私信** | WebSocket 点对点消息 |
| **在线状态** | 用户上下线、在线列表 |
| **世界频道** | 广播消息 |
| **匹配队列** | 随机匹配聊天 |

### 6.3 虚拟形象系统

| 组件 | 位置 | 功能 |
|------|------|------|
| **Rive 动画** | `lib/widgets/dynamic_avatar.dart` | 动态虚拟形象渲染 |
| **头像配置** | `backend/model/avatar.go` | 头像部件配置存储 |
| **头像服务** | `lib/services/avatar_service.dart` | 头像资源管理 |
| **头像生成** | `backend/utils/avatar_storage.go` | 头像存储与生成 |

### 6.4 成就系统

| 组件 | 位置 | 功能 |
|------|------|------|
| **成就引擎** | `backend/pkg/achievement/` | 成就检测、解锁引擎 |
| **成就钩子** | `lib/services/achievement_hooks.dart` | 前端成就触发监听 |
| **成就页面** | `lib/pages/achievements/` | 成就展示页面 |

---

## 7. 数据库模型

### 7.1 核心表关系

```
User (用户)
  ├── Follow (关注)
  ├── FriendRequest (好友请求)
  ├── Post (帖子)
  │    ├── Like (点赞)
  │    ├── Comment (评论)
  │    └── PostReport (举报)
  ├── PrivateMessage (私信)
  ├── Notification (通知)
  ├── UserLevel (等级)
  ├── VipRecord (VIP 记录)
  ├── VipOrder (VIP 订单)
  ├── Transaction (交易)
  ├── UserGiftStock (礼物库存)
  ├── AiChatSession (AI 聊天会话)
  ├── UserMemory (用户记忆)
  ├── UserBehavior (行为日志)
  └── UserDevice (设备信息)
```

### 7.2 主要数据表索引

| 表名 | 主要索引 |
|------|----------|
| `users` | `id` (PK), `email` (UNIQUE), `username` |
| `posts` | `id` (PK), `user_id`, `created_at` |
| `comments` | `id` (PK), `post_id`, `user_id` |
| `likes` | `post_id + user_id` (UNIQUE) |
| `follows` | `follower_id + following_id` (UNIQUE) |
| `private_messages` | `id` (PK), `sender_id`, `receiver_id`, `created_at` |
| `user_memories` | `id` (PK), `user_id`, `created_at` |

---

## 8. API 接口

### 8.1 接口风格

- **协议**: HTTP/1.1 + WebSocket
- **格式**: JSON (RESTful 风格)
- **认证**: JWT Bearer Token
- **契约**: Protocol Buffers (SSOT)
- **文档**: OpenAPI 3.0 ([openapi.yaml](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/openapi.yaml))

### 8.2 API 分组

| 分组 | 前缀 | 说明 |
|------|------|------|
| **认证** | `/api/user/v1/auth/*` | 注册、登录、OAuth |
| **用户** | `/api/user/v1/*` | 资料、关注、好友 |
| **帖子** | `/api/post/v1/*` | 动态、发帖、点赞 |
| **评论** | `/api/comment/v1/*` | 评论、回复 |
| **私信** | `/api/chat/v1/*` | 消息、会话 |
| **通知** | `/api/notify/v1/*` | 通知列表 |
| **礼物** | `/api/gift/v1/*` | 礼物、赠送 |
| **VIP** | `/api/vip/v1/*` | 套餐、订单 |
| **签到** | `/api/checkin/v1/*` | 签到、等级 |
| **AI** | `/api/ai/v1/*` | AI 聊天、智能体 |
| **LLM** | `/api/llm/v1/*` | 推理、记忆 |
| **Moe** | `/api/moe/v1/*` | Bot、Brain |
| **媒体** | `/api/media/v1/*` | 上传、下载 |
| **管理台** | `/api/admin/v1/*` | 后台管理 API |

### 8.3 认证流程

```
登录 (email/password 或 OAuth)
  ↓
返回 access_token + refresh_token
  ↓
后续请求携带: Authorization: Bearer <access_token>
  ↓
Token 过期 → 使用 refresh_token 刷新
```

---

## 9. 依赖关系

### 9.1 系统依赖图

```
Flutter 客户端
    │
    ├─ HTTP API → Kratos Backend :8888
    ├─ WebSocket → Kratos Backend :8888
    └─ Agora RTC → Agora 云服务
              │
              ▼
Kratos Backend (单进程)
    │
    ├─ MySQL (主数据库)
    ├─ SQLite (可选，本地开发)
    ├─ 飞书开放平台 (OAuth)
    ├─ 微信开放平台 (OAuth)
    └─ LLM Provider (OpenAI/本地模型等)
              │
              ▼
Moe Admin (React)
    │
    └─ Deploy Agent :19010 → Backend Admin API
              │
              ▼
GitHub Actions (CI/CD)
    ├─ APK 构建
    └─ Release 发布
```

### 9.2 前端依赖层级

```
UI 层 (widgets/)
    │
    ▼
页面层 (pages/)
    │
    ▼
状态管理 (providers/)
    │
    ▼
服务层 (services/)
    │
    ▼
模型层 (models/) + 工具层 (utils/)
    │
    ▼
第三方依赖 (http, dio, provider, ...)
```

### 9.3 后端依赖层级

```
Transport (protohttp, transport)
    │
    ▼
Service Layer (internal/service)
    │
    ▼
Business Logic (internal/biz)
    │
    ▼
Data Access (internal/data)
    │
    ▼
Model + GORM + MySQL
    │
    ▼
公共包 (pkg/) + 工具 (utils/)
```

---

## 10. 项目运行方式

### 10.1 环境要求

| 组件 | 版本要求 |
|------|----------|
| **Flutter SDK** | 3.0+ |
| **Go** | 1.25+ |
| **MySQL** | 8.0+ |
| **Node.js** | 18+ (管理台) |
| **Protocol Buffers** | 最新版 (后端开发) |

### 10.2 前端运行

```bash
# 克隆项目
git clone <repo-url>
cd moe_social

# 安装依赖
flutter pub get

# 运行开发版本
flutter run

# 生产构建
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
flutter build windows  # Windows
flutter build macos    # macOS
flutter build linux    # Linux
```

**API 配置**: 修改 [lib/utils/config.dart](file:///c:/Users/ZhuanZ1/Desktop/moe_social/lib/utils/config.dart) 中的 `isProduction`、`productionUrl`、`developmentUrl`。

### 10.3 后端运行

```bash
cd backend

# 安装依赖
go mod download

# 配置数据库
cp config/config.yaml.example config/config.yaml
# 编辑 config/config.yaml 中的数据库配置

# 生成 Proto 代码
make gen

# 数据库迁移
make db-migrate

# 启动开发服务 (含 deploy-agent)
make moe-social-dev

# 启动生产服务
make moe-social

# 运行测试
go test ./...

# 交叉编译 Linux
make build-linux
```

服务默认端口:
- **HTTP API**: `:8888`
- **Deploy Agent**: `:19010`

### 10.4 管理台运行

```bash
cd moe-admin

# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 生产构建
npm run build
```

访问地址: `http://127.0.0.1:5173/ops/`

### 10.5 Docker 部署

```bash
cd backend

# 使用 docker-compose
docker compose -f docker-compose.binary.yml up -d --build

# 查看日志
docker logs moe-social-api
```

### 10.6 常用命令速查

| 操作 | 命令 |
|------|------|
| 前端静态检查 | `flutter analyze` |
| 前端测试 | `flutter test` |
| 后端 Proto 生成 | `cd backend && make gen` |
| 后端编译检查 | `cd backend && make check` |
| 后端测试 | `cd backend && go test ./...` |
| 管理台构建 | `cd moe-admin && npm run build` |
| E2E 测试 | `cd e2e && make smoke` |

---

## 11. 开发规范与约定

### 11.1 代码规范

| 项目 | 规范 |
|------|------|
| **Flutter/Dart** | `flutter_lints` 规则集 |
| **Go** | Effective Go + 项目自定义规范 |
| **TypeScript** | ESLint + TypeScript 严格模式 |
| **API 设计** | Protocol Buffers 作为契约 SSOT |

### 11.2 目录约定

- **前端页面**: `lib/pages/<domain>/` 按领域划分
- **后端业务**: `backend/internal/biz/<domain>/` 按领域划分
- **API 契约**: `backend/api/<module>/v1/*.proto`

### 11.3 命名约定

| 类型 | 约定 |
|------|------|
| Proto 文件 | `{domain}.proto` 或 `{domain}_messages.proto` |
| Service 文件 | `{domain}.go` + `{domain}_{feature}.go` |
| 页面组件 | `{feature}_page.dart` |
| Provider | `{feature}_provider.dart` |
| Service | `{feature}_service.dart` |

### 11.4 Git 提交

- 使用 [git-commit skill](.cursor/skills/git-commit/SKILL.md) 规范
- Conventional Commits 格式

---

## 12. 部署与运维

### 12.1 Deploy Agent

一体化运维工具，运行在 `:19010` 端口：

```bash
cd backend
make deploy-agent
```

功能：
- 后端构建与发布
- Docker 容器管理
- GitHub APK 流水线触发
- RPC 监控
- 开发文档服务

### 12.2 CI/CD

- **平台**: GitHub Actions
- **触发**: 推送 `v*` 格式的 Tag
- **产物**: Release APK → GitHub Releases
- **更新检测**: 应用内自动检测新版本

```bash
# 发布版本
git tag v1.0.3
git push origin v1.0.3
```

### 12.3 环境配置

| 环境 | 说明 |
|------|------|
| **开发环境** | 本地运行，使用本地数据库 |
| **测试环境** | 测试服务器，用于 QA |
| **生产环境** | 正式服务器，用户使用 |

---

## 附录

### A. 相关文档索引

| 文档 | 位置 |
|------|------|
| 项目 README | [README.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/README.md) |
| 仓库规范 | [AGENTS.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/AGENTS.md) |
| 后端布局 | [backend/LAYOUT.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/LAYOUT.md) |
| 后端 README | [backend/README.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/README.md) |
| 管理台 README | [moe-admin/README.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/moe-admin/README.md) |
| 文档中心 | [docs/README.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/docs/README.md) |
| Code Review | [code_review.md](file:///c:/Users/ZhuanZ1/Desktop/moe_social/code_review.md) |
| OpenAPI 规范 | [backend/openapi.yaml](file:///c:/Users/ZhuanZ1/Desktop/moe_social/backend/openapi.yaml) |

### B. 端口分配

| 端口 | 服务 |
|------|------|
| `:8888` | 后端 HTTP API |
| `:19010` | Deploy Agent (运维台) |
| `:5173` | Moe Admin 开发服务器 |
| `:19012` | 开发文档静态站 |

---

**文档版本**: 1.0.0  
**最后更新**: 2026-06-28
