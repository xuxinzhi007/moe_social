# rpc/pb 退役说明（D4 Phase-4）

`rpc/pb/moe` 与 `rpc/pb/super` 已从生产构建中移除。

- **新契约**：`api/<domain>/v1/*.proto`（HTTP + gRPC）
- **历史 message**：`scripts/archive/rpc-defs/common.proto`
- **禁止**：恢复 `goctl zrpc` / `SuperClient` 垫片

验证：`go list -deps ./cmd/moe-social` 不应包含 `rpc/pb/moe`。
