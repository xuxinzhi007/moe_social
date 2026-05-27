# Codex Startup Guide（后端）

本项目后端位于 `backend/`，基于 **go-zero + goctl**。默认沿用现有目录分层与生成链路，不自行发明新结构。

## 项目结构（后端）

- `backend/api/super.api`：HTTP API 定义单一事实来源
- `backend/api/internal/handler`：HTTP handler（其中 `routes.go` 为生成文件）
- `backend/api/internal/logic`：API 业务逻辑
- `backend/api/internal/svc`：ServiceContext
- `backend/api/super.go`：API 服务入口（含手工注册补充路由）
- `backend/rpc/super.proto`：RPC 协议定义
- `backend/rpc/internal/logic`：RPC 业务逻辑
- `backend/rpc/internal/server`：RPC server（含生成文件）
- `backend/model`：GORM 数据模型
- `backend/utils`：基础工具与基础设施封装
- `backend/Makefile`：代码生成、构建、Swagger 生成入口

## 默认工作规则

1. 修改 HTTP 接口，先改 `backend/api/super.api`，再执行 `cd backend && make gen-api`。
2. 修改 RPC 接口，先改 `backend/rpc/super.proto`，再执行 `cd backend && make gen-rpc`。
3. 同时涉及 API/RPC 时，执行 `cd backend && make gen`（会跑 `gen-rpc + gen-api + gen-swagger`）。
4. Swagger 生成走 `make gen-swagger`，不要手写接口文档替代生成链路。
5. 除非明确需求，不重构无关模块，不跨层搬运逻辑。

## 技能使用顺序（后端规范化）

每次后端开发建议按以下顺序应用技能，保证实现一致性：

1. `implementation-guardrails`：先明确假设、边界、验收标准，避免过度设计。
2. `golang-style`：按 happy path、错误包装、注释与 Go 习惯落地。
3. `Effective Go`：再次校验命名、接口设计、并发与导出符号文档。
4. `golang-gin-database`（条件触发）：仅在 DB/GORM/sqlx/事务/迁移任务时启用。
5. `git-commit`（提交前触发）：按 Conventional Commits 生成提交信息。

补充：
- `gh-fix-ci`：用于修复 GitHub Actions 失败。
- `gh-address-comments`：用于处理 PR review 评论。
- `security-best-practices` / `security-threat-model`：仅在你明确要求安全评审时触发。

## 生成文件约定（不要手改）

- `backend/api/internal/handler/routes.go`
- `backend/api/internal/types/types.go`
- `backend/rpc/internal/server/superserver.go`
- `backend/rpc/superclient/super.go`
- `backend/rpc/pb/super/*.pb.go`

说明：本项目存在手工扩展路由文件 `backend/api/internal/handler/routes_llm_raw.go`，用于补充生成路由之外的能力；新增此类能力请放在独立手工文件，并在 `backend/api/super.go` 中显式注册。

## Go 开发约定（结合项目现状）

- 当前 Go 版本以 `backend/go.mod` 为准（`go 1.25.5`）。
- 保持 go-zero 分层职责：`handler` 做请求/响应适配，核心业务放 `logic` 或下游 RPC。
- 跨边界调用显式透传 `context.Context`，保持 `ctx` 为首参。
- 错误处理优先返回可读业务错误，避免把底层细节直接透出到接口层。
- 复用现有命名风格与目录组织，不引入 `common/helper/util` 式兜底目录。

## 新机器 / 换库后必做

管理台试跑若报 `Table 'xxx.moe_agent_run_logs' doesn't exist`，说明库表未迁移：

```bash
cd backend
make migrate-moe    # 仅 Moe / AI 聊天相关表
# 或全量：make db-migrate
```

迁移完成后重启 `make rpc` / `make dev`，再在管理台「试跑并刷新」。

## 修改前优先检查

- `backend/Makefile`
- 目标模块的 `backend/api/super.api` 或 `backend/rpc/super.proto`
- 相关 `backend/api/internal/handler/*`、`backend/api/internal/logic/*`
- 若涉及 LLM/raw 路由，检查 `backend/api/internal/handler/routes_llm_raw.go`
- 若改动 `moe-admin/`（React 管理台），另读 `docs/guidelines/Codex启动指南-前端.md`（路径为 `moe-admin/src/`，非 `lib/`）

## `make gen` 后必查（避免重复 logic 与编译失败）

`goctl` 会为**每个**带 `@handler` 的接口生成独立 `*_logic.go`。本仓库部分 Moe 管理接口已**手工合并**到：

- API：`backend/api/internal/logic/admin/` 下已有完整实现的文件
- RPC：`backend/rpc/internal/logic/moe_admin_logic.go`

若在 `super.api` / `super.proto` 上补 `@handler` 后执行 `make gen`，可能新增**同名** `AdminXxxLogic` 空壳文件（含 `return` 无值、`// todo`），导致：

- `redeclared in this block`（同 package 两个 Logic 结构体）
- `not enough return values`（空壳函数）

**处理原则：**

1. 生成后执行 `go build ./api ./rpc`，立刻发现冲突。
2. 保留已有完整实现；**删除** goctl 新生成的空壳或重复文件（勿留 `admindeletemoebotepisodelogic.go` 这类拼写错误副本）。
3. RPC 侧 Moe Brain 系列优先只维护 `moe_admin_logic.go`，删除重复的 `admin*moebrain*logic.go` 单文件。
4. `super.api` 中每个路由必须带 `@handler`，且与现有 handler 命名一致，避免半生成状态。
5. **推荐**：改 Moe/Admin 相关接口后执行 `cd backend && make gen-moe-admin`（`scripts/gen-moe-admin.sh` 会跑 gen 并自动删已知空壳再编译）。
6. **Kratos / Moe 迁移（Moe 域 100%）**：总览 `docs/dev/kratos-migration.md`。**推荐启动**：`make moe-social`（单进程 RPC+API）；经典：`make dev`。新 Moe 写在 `internal/biz|service|data`；Admin HTTP 走 `moeadmingw.MoeGW`。
7. **生成**：`make gen` = `gen-moe-proto` + `gen-rpc` + `gen-api`。**验收**：`make verify-moe-complete`（或分步 `verify-moe-migration` / `verify-moe-grpc` / `verify-moe-gateway`）。
8. **配置**（`config.yaml` → `moe`）：`api_in_process`、`register_moe_grpc`、`use_moe_grpc`、`single_process`。
9. **推理模型**：发帖从 `/v1/models` 自动匹配；管理台显示 `effective_model` / `auto_discovered`。

**是否拆分 `super.api` / `super.proto`？**

- 当前仍是**单服务、单进程**：App API + Admin API 共用一个 `super.api`；业务 RPC 共用一个 `Super` service（`super.proto` 约 3k 行，含 ~76 个 `Admin*` RPC）。
- **短期不建议**拆成多个 go-zero 微服务或多套 `goctl` 工程：要拆 routes 合并、多份 `ServiceContext`、部署与鉴权都要改，收益主要是「文件变短」，不解决 goctl 空壳问题。
- **中期可选**：在**同一 repo** 用 `import` 把 `super.api` 拆成 `api/defs/app.api` + `api/defs/admin.api` + `api/defs/moe.api` 再 `goctl` 生成到同一 `internal/`（仍是一个 API 二进制）。RPC 同理可用多 proto + 同一 `Super` service，但 goctl 合并成本较高。
- 空壳冲突的根因是「合并 logic」与 goctl「一接口一文件」冲突，用 `make gen-moe-admin` 清理即可，不必为此拆服务。

## 交付前检查（最少）

```bash
cd backend && make gen
gofmt -w $(git diff --name-only -- '*.go')
cd backend && go build ./api ./rpc
```

如本次改动较集中，可补充针对性 `go test`（仅跑受影响包）。

## 重要提醒

- 这是 go-zero 项目，优先复用现有写法和生成流程。
- 生成文件应与源定义同步提交。
- 先对齐现有模块写法，再扩展新能力。
