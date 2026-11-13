# 架构稿 · Flutter 客户端 + Kratos 单进程

Moe Social 是一个 Flutter 客户端连一台 Kratos HTTP 进程。管理台前端在独立仓库，本仓只留 `backend/api/admin/` 契约。本文是分层和目录导览。加接口仍读 [new-api-kratos.md](../dev/new-api-kratos.md)，目录布局仍读 `backend/LAYOUT.md`。

`new-api-kratos.md` 写明最后核对是 2026-09-11。下面的目录是 **2026-11-13** 对仓库 `ls` 的结果。篇数和该文档里的「27 个域 / 28 处注册」可能已经漂，以本次目录为准。

## 请求怎么走

```text
Flutter 页面
  → 域服务（PostService / ChatService / …）
  → ApiClient
  → :8888  Kratos HTTP（无对外 gRPC）
  → protohttp/<domain>
  → service → biz → data
  → MySQL（GORM）/ 缓存 / 推理
```

生产入口：`backend/cmd/moe-social`。配置：`backend/config/config.yaml`，读取只走 `backend/pkg/conf`。契约：`backend/api/<domain>/v1/*.proto` 的 `google.api.http`。生成：`cd backend && make gen`。禁止手改 `*.pb.go`、`*_http.pb.go`、`openapi.yaml`。

## 后端分层（已证实，工程规则 + 目录）

| 层 | 目录 | 允许依赖 |
|----|------|----------|
| protohttp | `internal/server/protohttp/` | service |
| service | `internal/service/<domain>/` | biz、proto |
| biz | `internal/biz/<domain>/` | data、model、pkg |
| data | `internal/data/<domain>/` | model、pkg |
| model | `backend/model/` | 与表一一对应 |

protohttp 不直接调 biz/data。service 不直接调 data。data 不 import biz。

### 契约域 `backend/api/`

achievement、admin、ai、arena、battle、behavior、chat、checkin、comment、community、companion、content、game、gift、landing、life、llm、media、moe、notify、platform、post、replyassist、user、vip。另有 `etc/`（API 结构片段，不是业务域）。

biz 比 api 多出来的包：`appcfg`、`emoji`、`game_network`、`voice`。本次 `internal/data` 没有与契约同名的 `content`、`media`、`platform`、`replyassist`，多一个 `moedata`。缺 data 目录不等于没有业务，可能写在别的域或平台包里。标 **推断**，改那条链路前先打开对应 biz。

### 非 proto 通道（已证实）

`backend/internal/server/transport/websocket.go` 注册：

| 路径 | 用途 |
|------|------|
| `/ws/chat` | 私信 |
| `/ws/presence` | 在线 |
| `/ws/remote` | 远程 |
| `/ws/game-network` | 联机实验 |
| `/ws/admin/moe/brain/pipeline` | 管理侧脑流水线 |
| `/ws/life` | 数字生命世界 |
| `/ws/companion` | AI 伙伴 |
| `/ws/battle` | 对战 |

Life 运行时状态在内存，tick 推进，事件进 `life_event_log`，按世界用 WebSocket 推给订阅者。间隔不要在业务里写死。

## 前端分层（已证实，`moe-flutter` + `lib/`）

| 层 | 目录 | 职责 |
|----|------|------|
| pages | `lib/pages/<domain>/` | 业务页 |
| widgets | `lib/widgets/` | 可复用 UI |
| providers | `lib/providers/` | ChangeNotifier / ViewModel |
| services | `lib/services/` | 域服务；页面不直接 `ApiService` |
| models | `lib/models/` | 客户端模型 |
| 路由 | `lib/app/app_routes.dart` | 集中路由；重页 deferred |

页面域目录：achievements、ai、announcements、arena、auth、autoglm、battle、chat、checkin、commerce、community、companion、feed、gallery、game_network、memory、notifications、onboarding、profile、reply_assist、scan、settings，以及 `_archived`。

主壳只挂首页、好友、AI 伙伴、社区、我的。其余从这些页或设置进入，并用 `FeatureFlags` 挡住实验入口。

低层 HTTP 用 `ApiClient`。域服务包括 `UserService`、`PostService`、`ChatService`、`CommerceService`、`CommunityService`、`AuthFlowService`、`LifeService`、`CompanionService`。

## 三栈边界

| 栈 | 在本仓的位置 |
|----|----------------|
| Flutter | `lib/**` |
| 后端 | `backend/**` |
| 管理台前端 | 独立仓；本仓只有 `backend/api/admin/v1/` |

## 本地怎么验

| 栈 | 命令 |
|----|------|
| 后端 | `cd backend && make check`（内部 `make test`，`CGO_ENABLED=1`） |
| 前端 | `dart format`、`flutter analyze`、`flutter test` |
| 跑服务 | `cd backend && make moe-social`，HTTP `:8888` |
