# API 契约分片（FS-8 SSOT）

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

映射 SSOT：`backend/scripts/fs8-domain-groups.json`

入口：`api/moe.api`（仅 `info` + `import "defs/..."`）

## 工作流

```bash
cd backend

# 1. 改对应域 defs/*.api（新路由写在域文件，类型优先写 common.api）
# 2. 校验 + 生成
goctl api validate -api api/moe.api
make gen-api          # 含 prune 孤儿壳

# 3. 合并实现写在 internal/biz + *gw；勿留 goctl 空壳（见 goctl-orphan-stubs.txt）
make verify-sprint-fs8
```

## 禁止混用

- 新接口只加到**一个**域 `.api`；`group:` 必须与上表一致（决定 `api/internal/logic/<group>/`）。
- 不要在多个域文件重复定义同名 `type`。
- **不要**再运行 `make fs8-split-api` 除非从 git 恢复单体 `super.api` 后重新切分（会覆盖 defs 手工修改）。

## RPC（FS-8b，待做）

RPC 见 `rpc/defs/`（`moe.proto` 入口）。运行时见 [moe-social-runtime.md](../../docs/dev/moe-social-runtime.md)。
