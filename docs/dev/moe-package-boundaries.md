# Moe 包边界（pkg/moe vs internal/biz/moe）

## 职责划分

| 层级 | 路径 | 职责 |
|------|------|------|
| **引擎 / 运行时** | `backend/pkg/moe/` | Brain、Pipeline、Runtime、Tools、FlowExec — 可复用、可单测、无 HTTP |
| **应用编排** | `backend/internal/biz/moe/` | 触发策略、与业务域（post/user）协作、RunOnce 调度 |
| **HTTP 适配** | `backend/internal/service/moe/` | Admin API、Attach*Deps 注入 runtime/brain |
| **Proto HTTP** | `backend/internal/server/protohttp/` | 请求/响应、鉴权 |

## 依赖方向（允许）

```
protohttp/moe → service/moe → biz/moe → pkg/moe/*
                ↓
              data/* (持久化)
```

## 禁止

- `pkg/moe` import `internal/*`（除测试）
- 页面/管理台直接调 pkg 内未暴露的函数
- 在 `service/moe/admin.go` 新增大段业务逻辑 — 应下沉到 `biz/moe` 或 `pkg/moe`

## 新功能放哪

| 场景 | 放置 |
|------|------|
| 新工具 handler、LLM 推理策略 | `pkg/moe/tools` / `pkg/moe/runtime` |
| 与帖子/用户联动的触发规则 | `internal/biz/moe` |
| Admin 开关、配置 CRUD | `internal/service/moe` + proto |
| 持久化 | `internal/data/moe` + `internal/biz/moe` Store interface |

## 测试

- `pkg/moe/**` — 单元测试优先（已有 brain/runtime 覆盖）
- `biz/moe` — 集成测试 mock Store
- `service/moe` — 后续补 HTTP 冒烟
