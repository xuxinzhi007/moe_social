# goctl 生成与空壳冲突说明

> **更新：2026-05-28** · 关联迁移：[kratos-migration-backlog.md](./kratos-migration-backlog.md)

## 问题是什么？

`make gen`（`goctl api go` / `goctl rpc protoc`）会为**每个** `@handler` / RPC 方法生成独立 `*logic.go`。

本仓库在 Hybrid 迁移中已改为：

| 层 | 实际写法 | goctl 仍生成 |
|----|----------|--------------|
| HTTP | `FriendLogic` 合并好友 7 接口；`admin_insights_logic.go` 合并洞察 | 7 个 `*friend*logic.go` 空壳 |
| HTTP | `handler/llm/confighandler.go` 直调 `LLMApp` | `configlogic.go` 空壳 |
| RPC | `moe_admin_logic.go` 合并 Moe Admin | `moeexecutetoollogic.go` 等空壳 |

表现：`redeclared in this block`、`not enough return values`，或**死代码文件**堆积。

## 是目录结构问题吗？

**不完全是。** 目录仍是 go-zero 惯例：

```text
api/super.api          → api/internal/{handler,logic,types}
rpc/super.proto        → rpc/internal/logic
internal/biz/<domain>  → 新 SSOT（迁移目标）
internal/service/<domain>
api/internal/<domain>gw
```

`api/<domain>/v1/*.proto` 是 **Kratos/契约** 用 stub，**尚未**替代 `super.api` 的 goctl 生成（FS-8，最后做）。

**完整迁移（FS-9 删 super.*） alone 不会自动消除空壳**；只要仍用 goctl 按接口生成 logic，且实现合并到 `biz` + 薄 handler，就会继续冲突。

## 正确做法（当前仓库）

1. **改契约** → `make gen`（已挂 prune）：
   ```bash
   cd backend && make gen
   ```
   - `gen-api` 后：`scripts/prune-api-logic-shells.sh`
   - `gen-rpc` 后：`scripts/prune-rpc-logic-shells.sh`

2. **Moe Admin 专用**：
   ```bash
   make gen-moe-admin   # gen + 删已知 RPC/API 孤儿 + go build
   ```

3. **验收**：
   ```bash
   make verify-gen-hygiene
   ```

4. **孤儿清单**（可提交、可扩展）：
   - `backend/scripts/goctl-orphan-stubs.txt`
   - `backend/scripts/goctl-rpc-orphan-stubs.txt`

5. **新接口**：优先 `internal/biz` + `*gw` + **单文件合并 logic**；在 manifest 登记 goctl 会再生的空壳路径。

## 目录迁移路线（与 FS-8 对齐）

| 阶段 | 动作 | 空壳影响 |
|------|------|----------|
| **现在** | `super.api` + prune | 可控 |
| **FS-8** ✅ | `api/defs/*.api` import 进 super（同二进制） | 仍要 prune；SSOT 见 `api/defs/README.md` |
| **FS-8b** ✅ | `rpc/defs/common.proto` + `services/*.rpcfrag` → assemble `super.proto` | `make gen-rpc` 前自动 assemble |
| **FS-9** | 退役 `super.api`，新域只 goctl 新 proto | 新域用「handler → gw → biz」几乎不生成 fat logic |
| **FS-10** | RPC 薄层 → `biz` | 减少 RPC 侧重复 |

## 禁止

- 在未跑 `make gen` + prune 的情况下提交大量新 `*logic.go`。
- 手改 `routes.go` / `types.go` / `superserver.go`（生成文件）。
