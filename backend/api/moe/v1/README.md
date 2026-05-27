# Moe API 契约（v1）

本目录为 **Moe 域** 的协议单一事实来源（SSOT），用于 Kratos 混合迁移。

- **当前阶段**：Phase 1 核心完成 — 已定义 `GetBrainPipeline` / `RunAgentOnce` / `GetBrainSnapshot`；运行时仍走 legacy `super.proto`。
- 混合期：HTTP 仍走 `super.api`，gRPC 仍走 `super.proto`；实现位于 `internal/biz|service|data`。
- 生成：`cd backend && make api-moe-proto`（需本机 `protoc`）
- 方案：`docs/dev/kratos-hybrid-migration-plan.md` · 进度：`docs/dev/kratos-migration-status.md`
