# Codex Startup Guide（后端）

> **更新：2026-05-28**  
> 生产运行时：**纯 Kratos 单进程**（`make moe-social`）。go-zero/goctl 仅用于**存量契约维护**与 `-tags hybrid` 紧急回滚。

**必读 SSOT**：[kratos-migration.md](../dev/kratos-migration.md) · [kratos-migration-status.md](../dev/kratos-migration-status.md) · [new-api-kratos.md](../dev/new-api-kratos.md)

## 项目结构（后端 · 当前有效）

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | **生产入口** |
| `config/config.yaml` | 运行时配置 SSOT |
| `api/<domain>/v1/*.proto` | **新** HTTP/gRPC 契约（含 `google.api.http`） |
| `api/<domain>/v1/*_http.pb.go` | `make gen` 生成 |
| `internal/biz/<domain>/` | 业务逻辑 |
| `internal/service/<domain>/` | 应用服务 |
| `internal/server/http.go` | `NewHTTPServer` + `RegisterProtoHTTP` |
| `internal/server/httplegacy/` | 存量 compat（逐域删除） |
| `internal/server/grpc/` | Kratos gRPC |
| `internal/platform/{svc,wiring,moesocial}/` | 装配与启动 |
| `internal/apilegacy/` | 原 `api/internal`（gw/common，过渡） |
| `internal/legacy/types/` | 原 goctl JSON types |
| `api/defs/*.api` | **存量** goctl（慎改；`make gen-api`） |
| `api/internal/handler/` | goctl 生成；**仅 hybrid 构建** |
| `third_party/google/api/` | protoc HTTP 注解依赖 |
| `backend/Makefile` | `gen` / `moe-social` / `check` |

## 默认工作规则

1. **新接口**：改 `api/<domain>/v1/*.proto`（加 `google.api.http`）→ `internal/service` → `cd backend && make gen` → 确认 `http_proto.go` 已注册（见 [new-api-kratos.md](../dev/new-api-kratos.md)）。
2. **存量 HTTP**：改 `api/defs/*.api` → `make gen-api`（handler 仅 hybrid；生产走 compat/httplegacy）。
3. **存量 RPC message**：改 `rpc/` 域 proto → `make gen-rpc`。
4. 日常契约同步：**`make gen`**（域 pb + grpc + **http** + 路由表）。
5. 新机器：`make gen` 缺插件时会自动 `go install`；也可先跑 `make init-proto-tools`。
6. 除非明确需求，不重构无关模块。
7. 生产验收：`make check` + `go build ./cmd/moe-social`。

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

- `backend/internal/legacy/types/types.go`
- `backend/api/<domain>/v1/*.{pb,grpc.pb,http.pb}.go`
- `backend/rpc/pb/**/*.pb.go`
- `backend/internal/server/httplegacy/routes_*_gen.go`

存量 hybrid：`api/internal/handler/`（默认构建不编译）。

新能力：域 proto + `google.api.http` → `make gen` → `http_proto.go` 注册；**勿**扩 `httplegacy` 新路由。

## Go 开发约定（结合项目现状）

- 当前 Go 版本以 `backend/go.mod` 为准（`go 1.25.5`）。
- 生产分层：`httplegacy`（过渡）→ `internal/service` → `internal/biz` → `internal/data`。
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

迁移完成后重启 `make moe-social`（或 `make moe-social-dev`），再在管理台「试跑并刷新」。

## 修改前优先检查

- `backend/Makefile`
- 目标域 `api/<domain>/v1/*.proto` 或存量 `api/defs/*.api`
- 相关 `internal/server/httplegacy/*_compat.go`、`internal/service/<domain>/`、`internal/server/http_proto.go`
- 若涉及 LLM/raw 路由，检查 `backend/api/internal/handler/routes_llm_raw.go`
- 若改动 `moe-admin/`（React 管理台），另读 `docs/guidelines/Codex启动指南-前端.md`（路径为 `moe-admin/src/`，非 `lib/`）

## `make gen` 后必查（避免重复 logic 与编译失败）

> 根因与 FS-8 关系见 [goctl-generation-hygiene.md](../dev/goctl-generation-hygiene.md)。`make gen-api` / `make gen-rpc` 已自动执行 `prune-*-logic-shells.sh`；验收：`make check`。

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
6. **Kratos（2026-05-28）**：P0–P5 完成；状态板 [kratos-migration-status.md](../dev/kratos-migration-status.md)。**开发**：`make moe-social`。**P5-D**：`go list -deps ./cmd/moe-social` 无 go-zero。
7. **生成**：`make gen` = 域 proto pb + HTTP 路由同步；改 `api/defs` 用 `make gen-api`；新接口用域 proto + `internal/service`。
8. **配置**（`moe`）：`kratos_pure_enabled`、`super_grpc_retired`、`single_process` 等见 `config/config.yaml`。对外 **:8888** HTTP、**:8080** gRPC。
9. **部署**：生产默认单进程 `moe-social`；分体见 [kratos-p5-split-deploy.md](../dev/kratos-p5-split-deploy.md)。hybrid 回滚：`go build -tags hybrid`。
10. **推理模型**：发帖从 `/v1/models` 自动匹配；管理台显示 `effective_model` / `auto_discovered`。

**是否拆分 `super.api` / `super.proto`？**

- 当前仍是**单服务、单进程**：App API + Admin API 共用一个 `super.api`；业务 RPC 共用一个 `Super` service（`super.proto` 约 3k 行，含 ~76 个 `Admin*` RPC）。
- **短期不建议**拆成多个 go-zero 微服务或多套 `goctl` 工程：要拆 routes 合并、多份 `ServiceContext`、部署与鉴权都要改，收益主要是「文件变短」，不解决 goctl 空壳问题。
- **中期可选**：在**同一 repo** 用 `import` 把 `super.api` 拆成 `api/defs/app.api` + `api/defs/admin.api` + `api/defs/moe.api` 再 `goctl` 生成到同一 `internal/`（仍是一个 API 二进制）。RPC 同理可用多 proto + 同一 `Super` service，但 goctl 合并成本较高。
- 空壳冲突的根因是「合并 logic」与 goctl「一接口一文件」冲突，用 `make gen-moe-admin` 清理即可，不必为此拆服务。

## 交付前检查（最少）

```bash
cd backend && make gen    # 若改了 proto/defs
gofmt -w $(git diff --name-only -- '*.go')
cd backend && go build ./api ./rpc ./cmd/moe-social
go list -deps ./cmd/moe-social | grep go-zero   # 应无输出（改生产路径时）
make check
```

如本次改动较集中，可补充针对性 `go test`（仅跑受影响包）。

## 重要提醒

- **生产路径**按 Kratos 分层；goctl 仅维护存量与 hybrid。
- 生成文件应与源定义同步提交。
- 先对齐现有模块写法，再扩展新能力。
