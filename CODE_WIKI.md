# Moe Social (萌社交) Code Wiki

> **项目版本**: 1.0.0+1  
> **最后更新**: 2026-09-23（前后端业务事实源收口；§2 / §3 / §6 已补充）
> **技术栈**: Flutter + Go/Kratos + React

### 近期变更摘要（2026-09-11）

| 类别 | 说明 |
|------|------|
| **配置读取统一** | 唯一入口 `backend/pkg/conf`（49 个反向依赖）。此前散落 10 个文件的 `viper.New()` + 硬编码 searchDirs 已清零，`-f` 指定的配置文件现在对每一项都权威（实测：探针配置里的 `tick=7s/11s` 压过同目录 `./config` 的 60/300） |
| **过渡键删除** | `moeconf` 整包、`moe.kratos_pure_enabled` / `kratos_admin_base_url` / `super_grpc_retired` / `register_moe_grpc` / `use_moe_grpc`、`api.super_rpc_*`、`runtime.grpc_listen` 均已删除且零读者；18888 / 19032 两个无监听端口的硬编码兜底随之消失 |
| **LLM 环境变量** | `MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` / `MOE_LLM_API_KEY` **四个全部生效**且作用域统一。下方 2026-06-29 摘要只提 `MOE_LLM_API_KEY`，那是当时的实况（另三个到不了 Bot 调度），现已过期 |

### 近期变更摘要（2026-09-23）

| 类别 | 说明 |
|------|------|
| **业务事实源收口** | 项目转型方向不是换掉 Flutter，而是把权限、关系、等级阈值、Prompt、记忆、模型路由等业务规则统一收回 Go/Kratos 后端；Flutter 保留页面、输入、动画、草稿、乐观 UI、错误展示和重试 |
| **AI / Companion** | Companion 正式路径消费后端 SSE；Prompt、记忆、上下文、小主机 Ollama 调用和失败处理由后端 Companion/LLM 域维护 |
| **成长体系** | Flutter 新增 `GrowthService` 作为客户端适配层；签到、等级、经验日志仍走后端 checkin/level/achievement 规则，不在客户端推算等级阈值 |

### 近期变更摘要（2026-06-29）

| 类别 | 说明 |
|------|------|
| **已移除** | 独立向量/图记忆系统（`pkg/memory/`、Flutter `memory_service`、管理台 LearningWorkbench / RpcPage、Chrome `integration_test` 栈）；演示入口 `lib/demo_main.dart` 与 `home_redesign_demo.dart` |
| **AI 推理** | 统一走 `biz/llm/platform_*` + `pkg/llminference`；`llm_inference.api_key` / `MOE_LLM_API_KEY` |
| **认证** | App JWT 中间件（`internal/server/auth.go`）+ Flutter 主动 refresh（`jwt_exp.dart`） |

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
├── assets/                      # Flutter 静态资源
├── test/                        # Flutter 单元测试
├── website/                     # 产品官网静态页
├── scripts/                     # 仓库级脚本（admin 启动等）
└── AGENTS.md                    # 贡献指南与命令速查
```

**已退役 / 不存在**：`backend/rpc/`、`backend/api/defs/`、Chrome `integration_test/` 测试栈、`e2e/`（Playwright 视觉冒烟）、`pkg/memory/`。

### 2.3 业务事实源边界

正式产品路径遵循：

```
Flutter Page / Widget
  -> ViewModel / Provider
  -> Domain Service
  -> Backend API
  -> service
  -> biz
  -> data / pkg / external runtime
```

Flutter 不作为业务规则事实源。客户端可以决定展示、输入、草稿、滚动位置、乐观插入、失败回滚和重试；不能决定权限、内容可见性、等级阈值、奖励发放、Companion 记忆、Prompt 组装或模型路由。完整方案见 [docs/dev/backend-business-ssot-transition.md](docs/dev/backend-business-ssot-transition.md)。

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
| `lib/utils/` | 工具（含 `config.dart` → `ApiEnvConfig`：后端 API 基址与环境开关；`jwt_exp.dart`） |
| `lib/config/` | `app_config.dart` → `AppConfig`：第三方 LLM 密钥的安全存储（与 `ApiEnvConfig` 无关） |
| `lib/constants/` | `feature_flags.dart` 等 |
| `lib/theme/` | 设计 Token 与主题扩展 |
| `lib/main.dart` | 生产入口 |

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
| LLM 网关 | `ai_chat_gateway_service.dart` | App 统一走 `/api/llm/models` 与 `/api/llm/chat`，模型运行细节由后端处理 |
| 内容生成 | `content_generation_service.dart` | App 统一走 `/api/content/generate`，内容类型提示策略由后端维护 |
| 推理 | `ai_inference_service.dart` | LLM 调用 |
| LLM Chat Context | 后端 `internal/biz/llm/chat_context.go` | 角色提示词、用户 Persona、世界书上下文装配 |
| Companion Chat | `companion_service.dart` | 前端消费后端 SSE；Prompt、记忆、上下文与 Ollama 调用闭环由后端 Companion 域维护 |
| 帖子/社交 | `post_service.dart` | 动态、评论 |
| 私信 | `chat_service.dart` | 私信客户端适配；发送、历史、会话、错误裁决由后端 `biz/chat` + `protohttp/chat` 统一 |
| 成长 | `growth_service.dart` | 签到、等级、经验日志客户端适配；等级阈值与奖励裁决以后端 checkin 域为准 |
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

**读取入口只有一个**：`backend/pkg/conf`（`conf.Inference()` / `conf.DSN()` / `conf.HTTPPort()` / `conf.DomainInProcess("moe")` …）。
业务层不要自己 `viper.New()`，也不要到处拼 `"<段>.<子键>"`——第九批后全仓已无第二处读取点，`-f` 指定的文件对每一项都权威。

| 块 | 说明 |
|----|------|
| `auth` | `access_secret`、过期时间；环境变量 `MOE_AUTH_ACCESS_SECRET`（**env 优先于文件**） |
| `llm_inference` | 当前 `provider: ollama` + `base_url: http://192.168.124.77:11434` + `memory_model: qwen2.5:3b-instruct`（`config.yaml:89-94`）。四个环境变量 `MOE_LLM_BASE_URL` / `MOE_LLM_API_STYLE` / `MOE_LLM_MODEL` / `MOE_LLM_API_KEY` 全部生效且作用域统一（第九批前只有 `API_KEY` 能到达 Bot 调度） |
| `moe` | `single_process: true`，以及 19 个 `<domain>_api_in_process` 开关（未显式设置时继承 `single_process`，故用 `conf.IsSet` 判定）。`kratos_pure_enabled` / `kratos_admin_base_url` / `super_grpc_retired` 等过渡键已于 2026-09-08 删除 |
| `runtime` | HTTP `:8888`（`conf.HTTPPort()`），片段 `api/etc/moe.yaml` |
| `memory.search` | **死配置**（hybrid/vector/graph 全 disabled 且零读者，`pkg/conf/config.go:20` 已记名），记忆检索当前走关键词 |

### 4.7 Makefile 常用目标

| 命令 | 作用 |
|------|------|
| `make gen` | proto + conf + 路由统计 |
| `make check` | 编译 + 核心测试（**注意**：只 `go build ./cmd/moe-social` + 两个包的单测，**不跑 gofmt / go vet**，别当成全量门禁） |
| `make moe-social` | 生产单进程（`:8888`，不带 agent） |
| `make moe-social-dev` | 同一套启动，`moe-social-stack -agent=false`，**也不带** deploy-agent |
| `make deploy-agent` | 单独起 deploy-agent `:19010` |
| `make db-migrate` | 数据库迁移 |
| `make build-linux` | Linux 二进制 |

**已退役**（执行即报错）：`gen-rpc`、`moe-kratos`、`dev` 等 go-zero 时代目标。

---

## 5. 管理台架构（React）

### 5.1 概览

- **栈**：React 19 + TypeScript + Vite  
- **路由**：`BrowserRouter` **`basename="/ops"`**  
- **鉴权**：`AdminAuthContext` + `RequireAdmin`  
- **菜单 / 工作区 SSOT**：`src/config/workspaceNav.ts`（`WORKSPACES` = biz / ai / infra 三个工作区，`NAV_BY_WORKSPACE` = 各区导航树）

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
        │  /api/llm/*  /api/ai/*  /api/companion/*
        ▼
biz/llm/platform_chat_execute.go · biz/companion
        │  pkg/llminference (OpenAI-compatible + api_key)
        ▼
Ollama 小主机 / DeepSeek / 自建中转 / OpenAI 兼容端点
```

- **Provider 模型**：用户配置 baseUrl、apiKey、默认模型；酒馆 Tab 拉取 `/models` 或手动输入模型 ID  
- **无独立向量记忆产品**：上下文预算由 `platform_common` 控制；历史消息走会话存储  
- **Moe Brain**：管理台可观测管线；`pkg/moe/brain` 负责 Bot 心智与 RPG
- **Companion 正式路径**：Flutter 只消费后端 SSE 和展示错误；Prompt、记忆、上下文、模型选择、小主机 Ollama 超时与兜底由后端维护。

### 6.2 实时通信

`biz/chat/` — WebSocket Hub、私信、在线状态、匹配队列；私信输入、用户存在性、自己给自己发、图片参数等业务裁决在后端统一映射为稳定状态码与中文文案；客户端 `ws_channel_connector.dart`。

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

历史设计原型已清理，不再单独保留目录索引。

---

**文档版本**: 1.1.0  
**最后更新**: 2026-06-29
