# RPC 契约分片（已退役）

**D4 Phase-4**：`rpc/pb/moe` 生成链已删除；`common.proto` 已归档。

| 路径 | 状态 |
|------|------|
| `scripts/archive/rpc-defs/common.proto` | 历史 message 归档（勿再生成 pb） |
| `services/*.rpcfrag` | 历史 Super RPC 行（只读归档） |
| `../moe.proto` | 退役占位（无 import、无 service） |

## 当前工作流

```bash
cd backend
make gen          # 域 api/*/v1 proto + http 路由表（不跑 rpc/pb/moe）
make gen-api      # 仅改 api/defs 存量时
```

域 gRPC/HTTP：编辑 `api/<domain>/v1/*.proto` → `make gen` → `internal/server/http_proto.go` 注册。

详见 [kratos-migration-status.md](../../docs/dev/kratos-migration-status.md)。
