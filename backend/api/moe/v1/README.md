# Moe API 契约（v1）

本目录为 **Moe 域** gRPC 的协议 SSOT（Kratos 风格路径 `api/<domain>/v1/`）。

| 项 | 说明 |
|----|------|
| 源文件 | `moe.proto` |
| 生成 | `cd backend && make gen-moe-proto`（需 `protoc`） |
| 产物 | 同目录 `moe.pb.go`、`moe_grpc.pb.go`（Go 包名 `moev1`） |
| 与 legacy 关系 | **不替代** `rpc/super.proto`；HTTP 仍由 `api/super.api` 定义 |

实现：`internal/server/moegrpc` → `internal/service/moe` → `internal/biz/moe`。

总览：`docs/dev/kratos-migration.md` §7（端口与 Flutter）。
