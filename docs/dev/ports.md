# Moe Social 本地开发端口表

本仓库 **19010–19019** 预留给开发/运维工具，避免与 Flutter DevTools (`9100`)、cpolar (`6060`)、常见 HTTP 端口冲突。

| 端口 | 服务 | 启动方式 | 说明 |
|------|------|----------|------|
| **8080** | RPC 业务 | `go run ./rpc/super.go` / `make rpc` | gRPC |
| **8888** | API 业务 | `make api` | HTTP REST |
| **19010** | 开发者工具台 | `make deploy-agent` | devtools + 部署 API + RPC 监控代理 |
| **19011** | RPC debug API | `make rpc-debug` | pprof / `/debug/live`（进程内） |
| **19012** | 文档静态站（可选） | `make dev-docs` | 无 Agent 时的纯静态预览 |

Go 代码默认值：`backend/devports/ports.go`  
Deploy Agent 配置：`backend/deploy/config.yaml` → `listen` / `rpc_debug_upstream`

**推荐日常流程**

1. `make deploy-agent` → 打开 http://127.0.0.1:19010/（即 **Moe Ops**，无外层标签页）
2. 侧栏进入 **RPC 监控**；需另开 `make rpc-debug`
3. 飞书 / 记忆等扩展工具：侧栏底部链接或 `/devtools.html`
