# RPC 契约分片（FS-8b / FS-9 SSOT）

goctl 从 **`rpc/moe.proto`**（assemble 生成）生成 `rpc/internal/logic`（FS-10 薄层 → `internal/biz` / `internal/service`）。

## 目录

| 路径 | 作用 |
|------|------|
| `common.proto` | 全部 `message`（禁止在域碎片重复定义） |
| `services/<domain>.rpcfrag` | 域内 `rpc` 行（编入 `service Super`） |
| `../moe.proto` | **assemble 生成**的 goctl 入口（勿手改） |

域归类：`backend/scripts/fs8-rpc-domain-rules.json`

## 工作流

```bash
cd backend

# 1. 编辑 defs/services/<domain>.rpcfrag 或 defs/common.proto
# 2. 组装 + 生成（make gen-rpc 已含 assemble）
make gen-rpc

# 3. 回归（含 HTTP FS-8、FS-10、无 legacy super.proto）
make verify-sprint-fs9
```

## 禁止混用

- 新 `rpc` 只写入**一个**域 `.rpcfrag`；全局唯一 rpc 名。
- 不要在 `moe.proto` 手写 `message` 或 `rpc`。
- 不要恢复 `rpc/super.proto`（FS-9 已退役该文件名）。

## 保留的 `super` 符号

- `package super`、`go_package backend/rpc/pb/moe`、`service Super`：wire 仍为 super；Go import 用 `pb/moe`（FS-9b），`pb/super` 为垫片别名。

Kratos 域 stub：`api/<domain>/v1/*.proto`（文档/试点，非 goctl SSOT）。
