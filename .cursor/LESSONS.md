# Agent 累计教训（LESSONS）

> **用途**：只放「在本仓库里重复踩过 ≥2 次」或「一次就代价极高」的规则。  
> **维护**：由人类或 Session 复盘确认后写入；单条 ≤3 行。目标全文 **<80 行**。  
> **详述**：流程见 [docs/guidelines/agent-long-term-memory.md](../docs/guidelines/agent-long-term-memory.md)

## 契约与生成

- 改 `backend/api/super.api` 或 `backend/rpc/super.proto` 后必须 `cd backend && make gen`，再 `go build ./api ./rpc`；禁止手改 `types.go`、`routes.go`、`*.pb.go`。
- `make gen` 后检查是否生成空壳 logic（如与 `moe_admin_logic.go` 重复）；有则删空壳、保留业务实现文件。
- 管理台类型与 API 对齐时，优先跑 `backend/scripts/gen-moe-admin.sh`（若本次改了 admin 相关 API），再改 `moe-admin/src/api/`。

## 三栈边界

- **Flutter** 只改 `lib/**`；**后端** 只改 `backend/**`；**管理台** 只改 `moe-admin/**`。契约联动时先冻结 API/RPC，再开并行 UI。
- 前端规范（`.cursorrules`）不用于 `moe-admin/`；管理台读 `moe-admin-ai-spec.mdc` 与 `moe-admin/docs/admin-design-system.md`。

## 专题 SSOT（细节不写进本文件）

| 主题 | 文档 |
|------|------|
| 推理 + 记忆产品/配置 | `docs/dev/llm-inference-and-memory-vision.md` |
| 用户记忆架构/API | `docs/dev/用户记忆系统-OpenClaw式演进设计.md` |
| 记忆近期变更 | `docs/dev/记忆系统-2026-05-20-变更整理.md` |
| 产品优先级 | `docs/product/项目开发总览与当前优先级-2026-05-18.md` |
| Code Review | `code_review.md` |

## 交付

- 「完成」= 代码改动 + 对应检查已跑 + 结果已写在回复里；禁止只改代码不报 `flutter analyze` / `go test` / `go build` 结果。
- 单次 PR/会话尽量 **<500 行** 有效 diff；超大改动按「契约 → 逻辑 → UI」拆 PR。
- 无用户明确要求时 **不要** `git commit` / `git push`。

## 文档

- 长说明进 `docs/dev/` 或 `docs/product/`，不要膨胀 `AGENTS.md` 或 `.cursor/rules/*.mdc`。
- 过时内容迁入 `docs/archive/`，原路径留短 stub。
