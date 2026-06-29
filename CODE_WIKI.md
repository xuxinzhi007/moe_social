# Moe Social (萌社交) Code Wiki

> **项目版本**: 1.0.0+1  
> **最后更新**: 2026-06-29  
> **技术栈**: Flutter + Go/Kratos + React

### 近期变更摘要（2026-06-29）

| 类别 | 说明 |
|------|------|
| **已移除** | 独立向量/图记忆系统（`pkg/memory/`、Flutter `memory_service`、管理台 LearningWorkbench / RpcPage、Chrome `integration_test` 栈） |
| **AI 推理** | 统一走 `biz/llm/platform_*` + `pkg/llminference`；`llm_inference.api_key` / `MOE_LLM_API_KEY` |
| **认证** | App JWT 中间件（`internal/server/auth.go`）+ Flutter 主动 refresh（`jwt_exp.dart`） |
| **设计资源** | `moe-social-app-design/`（HTML 原型）、`moe-social-ui-design/`（早期 mock） |
| **演示入口** | `lib/demo_main.dart` → 首页改版对比 `home_redesign_demo.dart` |

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

Moe Social（萌社交）是一款**复合型社交产品**，融合传统社交与 AI 智能体能力。客户端为 **Flutter**，后端为 **Go / Kratos 单进程 HTTP**（`:8888`），运营后台为 **React（moe-admin）**。

### 1.2 核心特性

| 类别 | 特性 |
|------|------|
| **社交主线** | 动态流、发帖、评论、点赞、话题、关注/粉丝、好友、私信 |
| **AI 能力** | 多 Provider 角色卡、酒馆广场、Lorebook/世界书、平台 LLM 代理聊天 |
| **商业化** | VIP 会员、充值钱包、抽卡、虚拟形象、礼物 |
| **成长体系** | 签到、用户等级、成就徽章、经验值 |
| **实时通信** | WebSocket 私信、在线状态、语音通话（Agora RTC） |
| **自动化** | AutoGLM 实验页、Moe Bot / Brain 运行时（管理台可编排） |
| **多平台** | Android、iOS、Web、Windows、macOS、Linux |

### 1.3 技术栈总览

| 层级 | 技术选型 |
|------|----------|
| **客户端** | Flutter 3.x、Dart、Provider、Material Design |
| **后端** | Go 1.25+、Kratos v2.8.4、Protocol Buffers、GORM、MySQL |
| **管理台** | React 19、TypeScript、Vite、React Router、Recharts、React Flow |
| **实时/媒体** | WebSocket、Agora RTC |
| **第三方** | 飞书 OAuth、微信 OAuth（fluwx）、DeepSeek 等 OpenAI 兼容 LLM |
| **CI/CD** | GitHub Actions、Docker、Deploy Agent |

---

## 2. 整体架构

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│              客户端层 (Flutter / moe-admin)               │
│   App · Web · Desktop          管理台 basename=/ops       │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP / WebSocket
┌────────────────────────▼────────────────────────────────┐
│            Kratos HTTP 单进程 (:8888)                      │
│   jwtAuthFilter · protohttp · transport (OAuth/WS)       │
└────────────────────────┬────────────────────────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
┌───▼───┐          ┌────▼─────┐        ┌────▼─────┐
│ user  │          │ llm/moe  │        │  admin   │
│ post  │          │ ai/chat  │        │  API     │
└───┬───┘          └────┬─────┘        └────┬─────┘
    │                    │                    │
┌───▼────────────────────▼────────────────────▼──────┐
│              GORM · MySQL / SQLite                    │
└──────────────────────────────────────────────────────┘
```

### 2.2 仓库目录结构

```
moe_social/
├── lib/                         # Flutter 客户端
├── backend/                     # Go/Kratos 后端
├── moe-admin/                   # React 管理台
├── docs/                        # 文档 SSOT
├── moe-social-app-design/       # UI 设计 HTML 原型（2026）
├── moe-social-ui-design/        # 早期 UI mock HTML
├── assets/                      # Flutter 静态资源
├── test/                        # Flutter 单元测试
├── e2e/                         # Playwright 视觉冒烟（非 Widget 交互）
├── website/                     # 产品官网静态页
├── scripts/                     # 仓库级脚本（admin 启动等）
└── AGENTS.md                    # 贡献指南与命令速查
```

**已退役 / 不存在**：`backend/rpc/`、`backend/api/defs/`、Chrome `integration_test/` 测试栈、`pkg/memory/`。

---

## 3. 前端架构（Flutter）

### 3.1 架构概述

**Provider** 状态管理 + 按领域划分的 `pages/` / `services/` / `models/`。

### 3.2 目录结构

| 目录 | 职责 |
|------|------|
| `lib/app/` | 路由 `app_routes.dart`、主 Shell、延迟路由 |
| `lib/pages/` | 按域页面（18 个域，见 3.3） |
| `lib/services/` | API 与业务服务（~64 文件） |
| `lib/providers/` | ChangeNotifier 状态 |
| `lib/widgets/` | 通用与领域组件 |
| `lib/models/` | DTO |
| `lib/utils/` | 工具（含 `config.dart`、`jwt_exp.dart`） |
| `lib/config/` | `app_config.dart`、`moe_api.json` |
| `lib/constants/` | `feature_flags.dart` 等 |
| `lib/theme/` | 设计 Token 与主题扩展 |
| `lib/main.dart` | 生产入口 |
| `lib/demo_main.dart` | 演示入口（首页改版对比） |

### 3.3 页面模块（pages/）

| 领域 | 目录 | 主要功能 |
|------|------|----------|
| **认证** | `auth/` | 登录、注册、忘记密码、飞书/微信 OAuth |
| **动态流** | `feed/` | 首页、发帖、评论；`home_redesign_demo.dart` 改版方案对比 |
| **AI** | `ai/` | 聊天、酒馆（`tavern/`）、Provider 配置、Lorebook |
| **私信** | `chat/` | 会话、语音通话 |
| **商业化** | `commerce/` | VIP、钱包、抽卡、背包 |
| **社区** | `community/` | 兴趣小组 |
| **个人** | `profile/` | 主页、资料、好友 |
| **成长** | `checkin/`、`achievements/` | 签到、成就 |
| **发现/游戏** | `discover/`、`game/` | 匹配、游戏大厅 |
| **设置** | `settings/` | 账号、外观、AI、隐私（模块化 `modules/`） |
| **其他** | `notifications/`、`gallery/`、`scan/`、`autoglm/`、`demo/` | 通知、相册、扫码、AutoGLM |

**AI 酒馆子模块**：`pages/ai/tavern/` — `agents_tab.part.dart`、`providers_tab.part.dart`（part 文件，挂载于 `agent_list_page.dart`）。

### 3.4 服务层（services/）要点

| 服务 | 文件 | 职责 |
|------|------|------|
| HTTP 基座 | `api_service.dart` | 请求封装、JWT 携带与 refresh |
| 认证 | `auth_service.dart` | 登录态、Secure Storage |
| AI 网关 | `ai_chat_gateway_service.dart` | 聊天请求调度 |
| Provider | `ai_provider_service.dart` | 多 API 来源配置与模型列表 |
| LLM 端点 | `llm_endpoint_config.dart` | Terminal/raw vs `/api/llm/*` 切换 |
| 推理 | `ai_inference_service.dart` | LLM 调用 |
| Lorebook | `ai_lorebook_service.dart` | 世界书 |
| 帖子/社交 | `post_service.dart` | 动态、评论 |
| 实时 | `ws_channel_connector*.dart`、`presence_service.dart` | WebSocket |
| 成就 | `achievement_hooks.dart` | 前端成就触发 |

**已移除**：`memory_service.dart`、`ai_memory_orchestrator.dart`、`llama_cpp_*` 等本地 llama 插件相关服务。

### 3.5 Provider 列表

`ThemeProvider` · `NotificationProvider` · `LoadingProvider` · `VirtualAvatarProvider` · `CheckInProvider` · `UserLevelProvider` · `GameProvider` · `MainNavController` · `DeviceInfoProvider`

### 3.6 认证与 JWT（客户端）

```
登录 / OAuth → access_token + refresh_token
  ↓
api_service 请求带 Authorization: Bearer <token>
  ↓
jwt_exp 检测临近过期 → POST /api/user/refresh-token
  ↓
失败 → 跳转登录
```

配置 API 基址：`lib/utils/config.dart`（`developmentUrl` / `productionUrl`）。

### 3.7 主要依赖（节选）

`provider` · `http`/`dio` · `shared_preferences` · `flutter_secure_storage` · `web_socket_channel` · `agora_rtc_engine` · `rive` · `fluwx` · `speech_to_text` · `mobile_scanner`

---

## 4. 后端架构（Go/Kratos）

### 4.1 分层

```
protohttp / transport  →  service  →  biz  →  data  →  model (GORM)
```

生产入口：`cmd/moe-social/main.go`（**gitignore**，本地 `make moe-social` 生成/编译）。

### 4.2 API 模块（api/）

| 模块 | proto | 功能 |
|------|-------|------|
| user | `user/v1/user_messages.proto` | 认证、资料、关注、JWT refresh |
| post / comment | `post/` · `comment/` | 动态、评论 |
| chat | `chat/v1/` | 私信、WebSocket |
| ai / llm | `ai/` · `llm/v1/llm_messages.proto` | AI 会话、平台 LLM 代理 |
| moe | `moe/v1/` | Bot、Brain、工具 |
| admin | `admin/v1/admin_messages.proto` | 管理台 |
| gift / vip / checkin / achievement | 各 v1 | 商业化与成长 |
| media / notify / community / behavior / landing / platform | 各 v1 | 媒体、通知、社区等 |

契约 SSOT：`backend/api/<domain>/v1/*.proto` → `make gen` → `openapi.yaml`。

### 4.3 业务层（internal/biz/）

| 域 | 目录 | 说明 |
|----|------|------|
| llm | `biz/llm/` | **`platform_common.go`**（配置快照、memory budget 默认值）、`platform_chat.go`、`platform_chat_execute.go` |
| moe | `biz/moe/` | Brain 图、Bot 调度 |
| ai | `biz/ai/` | 用户侧 AI 会话 |
| user / post / chat / … | 同名目录 | 社交主线 |
| admin | `biz/admin/` | 审核、看板、运营 |

**已移除**：`biz/llm/memory_*.go`、`biz/user/memory_*.go`、`pkg/memory/**`。

### 4.4 核心 pkg/

| 包 | 职责 |
|----|------|
| `pkg/llminference/` | OpenAI 兼容 HTTP 客户端（支持 `api_key` / Authorization） |
| `pkg/moe/brain/` | 心智、RPG、压缩、快照 |
| `pkg/moe/runtime/` | Agent 运行时 |
| `pkg/moe/tools/` | 工具注册与执行 |
| `pkg/achievement/` · `pkg/level/` | 成就与等级 |
| `pkg/handdraw/` | 手绘光栅 |

Brain 内仍有 `prompt_memory.go` 等**提示词级**记忆辅助，非独立向量库产品。

### 4.5 HTTP 与 JWT（服务端）

- 装配：`internal/server/http.go` — CORS、统一 Envelope、`RegisterProtoHTTP`
- 鉴权：`internal/server/auth.go` — `jwtAuthFilter`、公开路径白名单、写操作需登录
- Admin JWT 与 App JWT **分离**（`config.yaml` → `auth` / `admin`）

### 4.6 配置要点（config/config.yaml）

| 块 | 说明 |
|----|------|
| `auth` | `access_secret`、过期时间；环境变量 `MOE_AUTH_ACCESS_SECRET` |
| `llm_inference` | 默认 DeepSeek；**`api_key`** + `MOE_LLM_API_KEY`；`memory_model` |
| `moe` | `single_process: true`、`kratos_pure_enabled: true` |
| `runtime` | HTTP `:8888`，片段 `api/etc/moe.yaml` |
| `memory.search` | 配置残留（hybrid/vector 均 disabled），无独立 memory 服务 |

### 4.7 Makefile 常用目标

| 命令 | 作用 |
|------|------|
| `make gen` | proto + conf + 路由统计 |
| `make check` | 编译 + 核心测试 |
| `make moe-social` | 生产单进程 |
| `make moe-social-dev` | 后端 + deploy-agent :19010 |
| `make db-migrate` | 数据库迁移 |
| `make build-linux` | Linux 二进制 |

**已退役**（执行即报错）：`gen-rpc`、`moe-kratos`、`dev` 等 go-zero 时代目标。

---

## 5. 管理台架构（React）

### 5.1 概览

- **栈**：React 19 + TypeScript + Vite  
- **路由**：`BrowserRouter` **`basename="/ops"`**  
- **鉴权**：`AdminAuthContext` + `RequireAdmin`  
- **菜单 SSOT**：`src/config/menu.ts`（`ADMIN_MENU_TREE`）

### 5.2 主要路由

| 路径 | 页面 |
|------|------|
| `/login` | 登录 |
| `/` | 仪表盘 |
| `/users` | 用户 |
| `/content/*` | 帖子、评论、社区、举报 |
| `/app/ai`、`/app/moe-bots`、`/app/moe-brain`、`/app/moe-flow` | AI / Bot / Brain / 流程图 |
| `/app/analytics`、`/app/tags`、`/app/social` | 分析、标签、社交配置 |
| `/system/platform` | 平台配置（合并原 data / app-config Tab） |
| `/system/admins`、`/system/menus`、`/system/audit` | 管理员、菜单、审计 |
| `/deploy`、`/docker`、`/build`、`/release`、`/jobs` | 运维流水线 |

**已移除页面**：`LearningWorkbenchPage.tsx`（记忆工作台）、`RpcPage.tsx`（RPC 监控）。

**未挂载文件**：`DataCatalogPage.tsx`（逻辑已并入 PlatformPage Tab）。

### 5.3 依赖（节选）

`react-router-dom` · `@xyflow/react`（Bot 流程图）· `recharts`

---

## 6. 核心功能模块

### 6.1 AI 与 LLM

```
Flutter (chat_page / agent_list / provider profiles)
        │  /api/llm/*  /api/ai/*
        ▼
biz/llm/platform_chat_execute.go
        │  pkg/llminference (OpenAI-compatible + api_key)
        ▼
DeepSeek / 自建中转 / OpenAI 兼容端点
```

- **Provider 模型**：用户配置 baseUrl、apiKey、默认模型；酒馆 Tab 拉取 `/models` 或手动输入模型 ID  
- **无独立向量记忆产品**：上下文预算由 `platform_common` 控制；历史消息走会话存储  
- **Moe Brain**：管理台可观测管线；`pkg/moe/brain` 负责 Bot 心智与 RPG

### 6.2 实时通信

`biz/chat/` — WebSocket Hub、私信、在线状态、匹配队列；客户端 `ws_channel_connector.dart`。

### 6.3 虚拟形象与成就

Rive 动态形象（`dynamic_avatar.dart`）；成就引擎 `pkg/achievement/` + 前端 `achievement_hooks.dart`。

---

## 7. 数据库模型

### 7.1 核心关系（节选）

```
User
 ├── Post → Comment, Like, PostReport
 ├── PrivateMessage, Notification
 ├── AiChatSession
 ├── UserLevel, Achievement, VipOrder, Transaction
 └── UserBehavior, UserDevice
```

**已移除表/model**：`UserMemory`、`UserMemoryEmbedding` 等 memory 系列。

### 7.2 模型定义位置

`backend/model/*.go` — 与 `utils/migrate_registry.go` 注册迁移。

---

## 8. API 接口

### 8.1 风格

- JSON + Protobuf 契约 SSOT  
- OpenAPI：`backend/openapi.yaml`（`make gen` 生成）  
- 文档：`docs/dev/openapi-apifox.md`

### 8.2 分组（前缀示例）

| 分组 | 前缀 | 说明 |
|------|------|------|
| 用户/认证 | `/api/user/` | 含 refresh-token |
| 帖子/评论 | `/api/post/` · `/api/comment/` | 动态 |
| LLM | `/api/llm/` | 平台推理、配置 |
| AI | `/api/ai/` | 会话、智能体 |
| 管理台 | `/api/admin/` | 运营 API |

### 8.3 认证流程

见 [3.6 认证与 JWT](#36-认证与-jwt客户端)；管理台使用独立 Admin Token。

---

## 9. 依赖关系

```
Flutter App ──HTTP/WS──► Kratos :8888 ──► MySQL
                │              ├── LLM Provider (DeepSeek 等)
                │              └── OAuth (飞书/微信)
moe-admin ──► Deploy Agent :19010 ──► Admin API
e2e (Playwright) ──► Flutter Web 截图冒烟（非 Widget 测试）
```

---

## 10. 项目运行方式

### 10.1 环境

Flutter 3.x · Go 1.25+ · MySQL 8 · Node 18+（管理台）

### 10.2 常用命令

| 范围 | 命令 |
|------|------|
| Flutter | `flutter pub get` · `flutter analyze` · `flutter test` · `flutter run` |
| 后端 | `cd backend && make gen` · `make check` · `make moe-social` · `go test ./...` |
| 管理台 | `cd moe-admin && npm run dev` · `npm run build` |
| E2E 视觉 | `cd e2e && make smoke` |

### 10.3 端口

| 端口 | 服务 |
|------|------|
| 8888 | 后端 HTTP |
| 19010 | Deploy Agent |
| 5173 | moe-admin 开发（/ops） |
| 19012 | 开发文档静态站（`make dev-docs`） |

### 10.4 API 地址

修改 `lib/utils/config.dart` 中 `developmentUrl` / `productionUrl`。

---

## 11. 开发规范与约定

- **规范入口**：`.cursor/rules/moe-social-unified.mdc`、`AGENTS.md`  
- **踩坑**：`.cursor/LESSONS.md`  
- **Review**：`code_review.md`  
- **Kratos 迁移 SSOT**：`docs/dev/kratos-migration-status.md`  
- **Flutter 页面**：`lib/pages/<domain>/`  
- **后端 biz**：`internal/biz/<domain>/`  
- **Proto 改动**：`cd backend && make gen` 后 `go build` 验证  

---

## 12. 部署与运维

- **单进程生产**：`cd backend && make moe-social`  
- **Docker**：`backend/docker-compose.binary.yml`  
- **Deploy Agent**：构建、Docker、Release、GitHub APK 流水线  
- **版本发布**：`git tag vX.Y.Z && git push origin vX.Y.Z`  

---

## 附录

### A. 文档索引

| 文档 | 路径 |
|------|------|
| README | [README.md](README.md) |
| AGENTS | [AGENTS.md](AGENTS.md) |
| 后端布局 | [backend/LAYOUT.md](backend/LAYOUT.md) |
| OpenAPI | [backend/openapi.yaml](backend/openapi.yaml) |
| 文档中心 | [docs/README.md](docs/README.md) |
| Kratos 迁移 | [docs/dev/kratos-migration-status.md](docs/dev/kratos-migration-status.md) |

### B. 设计原型

| 目录 | 说明 |
|------|------|
| [moe-social-app-design/](moe-social-app-design/) | 2026 HTML 页面原型（login、home、tavern、settings 等） |
| [moe-social-ui-design/](moe-social-ui-design/) | 早期 UI mock |

---

**文档版本**: 1.1.0  
**最后更新**: 2026-06-29
