# internal/conf — Kratos 配置 SSOT（Phase 4）

| 文件 | 说明 |
|------|------|
| `moe/v1/pilot.proto` | `moe.conf.v1.Bootstrap`（试点进程 + moe 开关） |
| `moe/v1/pilot.pb.go` | protoc 生成 |

```bash
cd backend && make gen-moe-conf
```

加载：`internal/platform/moeconf.LoadBootstrap()`（映射 `config/config.yaml`）。

PK-13：`make moe-social` 默认 `-f config/config.yaml`；`runtime.*` 为 HTTP/gRPC 端口 SSOT；`api/etc/moe.yaml` 与 `rpc/etc/moe.yaml` 为结构片段。
