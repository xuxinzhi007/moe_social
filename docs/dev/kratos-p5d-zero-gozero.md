# P5-D — 代码库零 go-zero（生产路径）

> **最后更新：2026-05-28**  
> **前置**：[kratos-p5-super-retirement.md](./kratos-p5-super-retirement.md)（P5-A/B/C ✅）

---

## 目标

| 层级 | DoD |
|------|-----|
| **生产二进制** `cmd/moe-social` | `go list -deps` **不含** `github.com/zeromicro/go-zero/*` |
| **日常 HTTP** | `api/moehttp/*` 用 Kratos `ctx.Bind`，无 `httpx` |
| **分体 gRPC 客户端** | `internal/platform/grpcclient` 替代 `zrpc` |
| **配置加载** | `internal/platform/yamlconf` 替代 `conf.MustLoad` |
| **遗留 handler** | `//go:build hybrid`（仅 `-tags hybrid` 编译） |
| **紧急回滚** | `go build -tags hybrid` 恢复 go-zero rest / zrpc 入口 |

---

## 已实现（2026-05-28）

| 组件 | 行为 |
|------|------|
| `api/runserver` | 默认 `!hybrid`：仅 wire-only；`server_hybrid.go` 保留 rest |
| `api/moehttp` | `bindRequest` → Kratos `Bind`；批量去掉 `httpx` |
| `api/internal/svc` | 分体 `grpcclient.Dial` → MoeAdmin |
| `api/internal/config` | 自有 `Host/Port/Timeout`，无 `RestConf` |
| `rpc/runserver/kratos.go` | `yamlconf` + 自有 `config.Config` |
| `internal/platform/moesocial` | 默认仅 `runWithKratosGRPC`；zrpc/front 在 `*_hybrid.go` |
| `internal/platform/moelog` | 替代 `logx`（生产路径） |
| `api/internal/handler/**` | 全部 `//go:build hybrid`（除 `doc/`、`routes_stub`） |
| `api/internal/websocket/**` | `//go:build hybrid` |
| `api/super.go` / `rpc/super.go` | hybrid 专用；默认 stub 提示用 `moe-social` |

---

## 验收

```bash
cd backend

# 生产路径（必须通过）
go build ./api ./rpc ./cmd/moe-social
go list -deps ./cmd/moe-social | findstr go-zero    # Windows：应无输出
go list -deps ./cmd/moe-social | grep go-zero       # Linux/macOS：应无输出

go test ./internal/platform/kratosprogress/... -count=1

# 紧急回滚构建（可选）
go build -tags hybrid -o bin/moe-social-hybrid ./cmd/moe-social
```

---

## 与 `/migration` 的关系

- `percent` / `rollout_percent` 仍反映 P3 传输 + logic 清库（可达 100）。
- **P5-D 完成度**以 **`go list -deps ./cmd/moe-social` 无 go-zero** 为准（生产零依赖）。
- 仓库内仍可有 hybrid 源文件；`go.mod` 保留 `go-zero` 供 `-tags hybrid` 构建。

---

## 脚本

| 脚本 | 用途 |
|------|------|
| `backend/scripts/p5d-strip-httpx-moehttp.py` | moehttp `httpx` → `bindRequest` |
| `backend/scripts/p5d-tag-hybrid-handlers.py` | legacy handler 打 hybrid tag |
| `backend/scripts/p5d-tag-hybrid-websocket.py` | websocket 打 hybrid tag |

---

## 相关

- [kratos-migration-status.md](./kratos-migration-status.md)
- [kratos-p4-post-migration.md](./kratos-p4-post-migration.md) § P4-H
