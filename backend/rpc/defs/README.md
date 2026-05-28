# RPC 契约分片（P5 后）

**P5-B 完成**：`rpc/internal/logic` 已删除；`service Super` 已从 `rpc/moe.proto` 移除。

## 目录

| 路径 | 作用 |
|------|------|
| `common.proto` | 全部 `message`（HTTP/gateway 与 pb/moe 类型 SSOT） |
| `services/<domain>.rpcfrag` | **归档**：历史 Super RPC 行，不再 assemble |
| `../moe.proto` | **message-only**（`import defs/common.proto`，无 service） |

## 工作流

```bash
cd backend

# 日常：仅组装 message-only moe.proto（不跑 goctl zrpc）
make fs8-assemble-super-proto

# 新域 gRPC：编辑 api/<domain>/v1/*.proto + make gen
# 勿使用 make gen-rpc-legacy（会尝试恢复 Super + logic）
```

## 生产 RPC

- 域服务：`api/*/v1` + `internal/server/moegrpc/*`
- MoeAdmin：`moe.v1.MoeAdmin` + `internal/service/moe`
- 类型：`rpc/pb/moe`（`SuperClient` 垫片保留供 gateway 可选回退，单进程为 nil）

详见 [docs/dev/kratos-p5-super-retirement.md](../../docs/dev/kratos-p5-super-retirement.md)。
