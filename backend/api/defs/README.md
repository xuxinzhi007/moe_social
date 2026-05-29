# API 契约分片（FS-8 SSOT · **冻结维护**）

> **新接口禁止写入本目录。** 请改 `api/<domain>/v1/*.proto` + `google.api.http` → `make gen`。  
> 只读镜像：`scripts/archive/api-defs/`（灾难恢复用）。

HTTP goctl 契约已按域拆分（FS-9）。**禁止**在 `moe.api` 中直接添加 `type` 或 `@server`。

## 目录

| 文件 | 域 | goctl `group`（logic 目录） |
|------|-----|---------------------------|
| `common.api` | 共享类型 | —（仅类型，无路由） |
| `landing.api` | 官网 / 运维反馈 | `landing`, `ops` |
| `user.api` | 用户 / 头像 / 表情 / 私信 / 通知 | `user`, `avatar`, `emoji`, `privatemsg`, `notification` |
| `admin.api` | 管理台 | `admin`, `admin_public` |
| `vip.api` | VIP 套餐（App） | `vip` |
| `social.api` | 动态 / 评论 / 圈子 / 礼物 / 内容 | `post`, `comment`, `community`, `gift`, `content` |
| `ai_llm.api` | AI / LLM | `ai`, `llm` |
| `realtime.api` | WebSocket / 语音 | `chat`, `voice` |
| `platform.api` | 文档 / 图片 / 配置 / 签到 / 成就 / 埋点 | `doc`, `image`, `appcfg`, `checkin`, `achievement`, `behavior` |
| `moe.api` | Moe 工具（App） | `moe` |

映射 SSOT：`backend/scripts/gen/fs8-domain-groups.json`

入口：`api/moe.api`（仅 `info` + `import "defs/..."`）

## 工作流（标准 go-zero）

```bash
cd backend

# 1. 改对应域 defs/*.api
goctl api validate -api api/moe.api

# 2. 生成 handler / types / routes（已有 *logic.go 通常不会被覆盖）
make gen-api

# 3. 在 api/internal/logic/<group>/ 写或补全 *Logic 方法
# 4. 复杂业务可下沉 internal/biz + *gw
make check
```

日常只改域 proto 或同步路由：`make gen`（**不含** goctl api/rpc）。

## 禁止混用

- 新接口只加到**一个**域 `.api`；`group:` 必须与上表一致。
- 不要在多个域文件重复定义同名 `type`。
- **不要**再运行 `make fs8-split-api` 除非从 git 恢复单体 `super.api` 后重新切分。

## RPC

RPC 见 `rpc/defs/`。改 RPC 后 `make gen-rpc`；HTTP+RPC 都改则 `make gen-all`。
