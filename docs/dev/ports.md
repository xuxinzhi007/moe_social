# Moe Social 本地开发端口表

本仓库 **19010–19019** 预留给开发/运维工具，避免与 Flutter DevTools (`9100`)、cpolar (`6060`)、常见 HTTP 端口冲突。

| 端口 | 服务 | 启动方式 | 说明 |
|------|------|----------|------|
| **8080** | RPC 业务 | `go run ./rpc/super.go` / `make rpc` | gRPC |
| **8888** | API 业务 | `make api` | HTTP REST |
| **19010** | 开发者工具台 | `make deploy-agent` | 默认 **React** `/ops/`（无 dist 时自动 build）；`/` 会跳转；HTML 备用见 `/tools/deploy-ops.html` |
| **5173** | React 运维台（开发） | `make ops-console-dev` | Vite 热更新，代理 `/api` → :19010 |
| **19011** | RPC debug API | `make rpc-debug` | pprof / `/debug/live`（进程内） |
| **19012** | 文档静态站（可选） | `make dev-docs` | 无 Agent 时的纯静态预览 |

Go 代码默认值：`backend/devports/ports.go`  
Deploy Agent 配置：`backend/deploy/config.yaml` → `listen` / `rpc_debug_upstream`

**推荐日常流程**

1. `make deploy-agent` → 自动打开 http://127.0.0.1:19010/ops/（React；首次会自动 `npm run build`）
2. React 日常开发：`make ops-console-dev` → http://127.0.0.1:5173/ops/
3. 侧栏进入 **RPC 监控**；需另开 `make rpc-debug`
4. 飞书 / 记忆等扩展工具：侧栏底部链接或 `/devtools.html`
