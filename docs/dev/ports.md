# Moe Social 本地开发端口表

本仓库 **19010–19019** 预留给开发/运维工具，避免与 Flutter DevTools (`9100`)、cpolar (`6060`)、常见 HTTP 端口冲突。

| 端口 | 服务 | 启动方式 | 说明 |
|------|------|----------|------|
| **8080** | RPC 业务 | `go run ./rpc/super.go` / `make rpc` | gRPC |
| **8888** | API 业务 | `make api` | HTTP REST |
| **19010** | Deploy Agent 网关 | `make deploy-agent` | Deploy API、`/api/deploy/admin` 代理、RPC debug、`/tools/deploy-ops.html`；**不**自动构建/打开 Moe Admin |
| **5173** | Moe Admin（开发） | `make moe-admin-dev` | Vite 热更新；业务 `/api/admin` → :8888，运维 `/api/deploy` → :19010 |
| **19011** | RPC debug API | `make rpc-debug` | pprof / `/debug/live`（进程内） |
| **19012** | 文档静态站（可选） | `make dev-docs` | 无 Agent 时的纯静态预览 |

Go 代码默认值：`backend/devports/ports.go`  
Deploy Agent 配置：`backend/deploy/config.yaml` → `listen` / `rpc_debug_upstream`

**推荐日常流程**

1. **管理台**：`cd moe-admin && npm run dev` → http://127.0.0.1:5173/ops/（需 RPC + API）
2. **运维能力**（构建/发布/RPC 监控）：另开 `make deploy-agent` → :19010
3. 侧栏 **RPC 监控**：`make moe-social` / `make dev` 默认开启 :19011；单独起 RPC 时用 `make rpc-debug`
4. 一键全栈：`make admin`（或 `scripts/start-admin.*`）
5. 生产构建（按需）：`cd moe-admin && npm run build`，由你自己的静态托管或 CI 发布
