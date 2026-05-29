# P5-D — 代码库零 go-zero（生产路径 + 仓库清理）

> **最后更新：2026-05-29**  
> **前置**：[kratos-p5-super-retirement.md](./kratos-p5-super-retirement.md)（P5-A/B/C ✅）

---

## 目标

| 层级 | DoD |
|------|-----|
| **生产二进制** `cmd/moe-social` | `go list -deps` **不含** `github.com/zeromicro/go-zero/*` |
| **日常 HTTP** | `api/moehttp/*` 用 Kratos `ctx.Bind`，无 `httpx` |
| **分体 gRPC 客户端** | `internal/platform/grpcclient` 替代 `zrpc` |
| **配置加载** | `internal/platform/yamlconf` 替代 `conf.MustLoad` |
| **遗留 handler** | ~~`//go:build hybrid`~~ **已删除（P5-E 2026-05-29）** |
| **go.mod** | **无** `github.com/zeromicro/go-zero` 直接依赖 |

---

## 已实现

| 组件 | 行为 |
|------|------|
| `api/runserver` | 默认 wire-only Kratos HTTP |
| `api/moehttp` | `bindRequest` → Kratos `Bind` |
| `api/internal/svc` | 分体 `grpcclient.Dial` → MoeAdmin |
| `rpc/runserver/kratos.go` | `yamlconf` + 自有 `config.Config` |
| `internal/platform/moesocial` | 默认 `runWithKratosGRPC` |
| `internal/platform/moelog` | 替代 `logx`（生产路径） |
| **P5-E 清理** | 删除 314+ hybrid handler/websocket 源；`routes` 归档至 `scripts/gen/http-routes/fixtures/routes.go` |

---

## 验收

```bash
cd backend

go build ./...
go list -deps ./cmd/moe-social | grep go-zero    # 应无输出
grep go-zero go.mod                            # 应无输出

make check
make split-deploy-smoke                        # 构建 api/rpc + 可选 grpc 冒烟
GRPC_SMOKE=1 go test ./internal/platform/grpcsmoke/... -count=1   # 需 make moe-social
```

---

## 脚本

| 脚本 | 用途 |
|------|------|
| `scripts/p5e-remove-hybrid-gozero.py` | 删除 hybrid 源 + 归档 routes fixture |
| `scripts/grpc-smoke-notify-chat-vip.sh` | notify/chat/vip grpcurl 冒烟 |
| `scripts/split-deploy-smoke.sh` | 分体二进制构建 + 联调检查 |
| `make remove-hybrid-gozero` | 一次性清理（已执行可跳过） |

---

## 相关

- [kratos-migration-status.md](./kratos-migration-status.md)
- [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md)
- [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md)
