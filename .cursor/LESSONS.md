# Agent 累计教训（LESSONS）

> 只放重复踩过 ≥2 次或代价极高的规则。单条 ≤3 行，全文 <80 行。  
> Session 归档（可选）：`docs/guidelines/sessions/`

## 契约与生成

- 改 `backend/api/**` proto 后必须 `cd backend && make gen`，再 `make check`；禁止手改 `*.pb.go`、`*_http.pb.go`。
- `make gen` 后检查空壳 logic；有则删空壳、保留业务实现文件。
- 管理台类型对齐：改 admin 相关 API 后跑 `backend/scripts/gen-moe-admin.sh`（若存在），再改 `moe-admin/src/api/`。

## 三栈边界

- Flutter 只改 `lib/**`；后端只改 `backend/**`；管理台只改 `moe-admin/**`。
- Flutter 规范（`frontend-ai-spec.mdc`）不用于 `moe-admin/`。

## 专题 SSOT

| 主题 | 文档 |
|------|------|
| 推理 + 记忆 | `docs/dev/llm-inference-and-memory-vision.md` |
| 用户记忆 | `docs/dev/用户记忆系统-OpenClaw式演进设计.md` |
| 产品定位 | `docs/product/product-positioning.md` |
| AI 陪伴正式化决策 | `docs/dev/ai-companion-formal-decisions.md` |
| Code Review | `code_review.md` |

## 交付

- 「完成」= 改动 + 检查已跑 + 结果写在回复里。
- 无用户明确要求不要 `git commit` / `git push`。
