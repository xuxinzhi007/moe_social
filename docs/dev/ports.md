# Moe Social 本地开发端口表

本仓库 **19010–19019** 预留给开发/运维工具，避免与 Flutter DevTools (`9100`)、cpolar (`6060`)、常见 HTTP 端口冲突。

> **现状（2026-09-11 核对）**：Kratos 迁移后后端已是**单进程 HTTP-only**，全仓库只有一个业务监听端口 `8888`，且只能经 `backend/pkg/conf` 读到（`conf.HTTPPort()`）。
> `backend/rpc/` 目录与 `api/super.go` 已删除，`make rpc` / `make api` / `make rpc-debug` / `make dev` / `make moe-admin-dev` / `make rpc-migrate` 这些目标**在 `backend/Makefile` 中已不存在**。

## 实际监听的端口

| 端口 | 服务 | 启动方式 | 说明 |
|------|------|----------|------|
| **8888** | Kratos HTTP（业务唯一入口） | `cd backend && make moe-social` | 单进程，含全部 REST/gRPC-gateway 路由；端口来自 `config.yaml` → `runtime.http_port` |
| **19010** | Deploy Agent 网关 | `cd backend && make deploy-agent` | Deploy API、`/api/deploy/admin` 代理、`/tools/deploy-ops.html`；需先 `make deploy-config-init` 生成 `deploy/config.yaml` |
| **5173** | Moe Admin（开发） | `cd moe-admin && npm run dev` | Vite 热更新 → http://127.0.0.1:5173/ops/ ；业务 `/api/admin` → :8888，运维 `/api/deploy` → :19010 |
| **19012** | 文档静态站（可选） | `cd backend && make dev-docs` | 无 Agent 时的纯静态预览 |

Go 代码默认值：`backend/devports/ports.go`
Deploy Agent 配置：`backend/deploy/config.yaml` → `listen` / `rpc_debug_upstream`

## 已无监听者的端口（仅存在于配置/代码残留）

| 端口 | 曾经的用途 | 现状 |
|------|-----------|------|
| **8080** | go-zero RPC 业务进程 | ✗ 无监听。`config.yaml:1-3` 的 `server: {port: 8080, host: 0.0.0.0}` 段**零读取方**，属死配置 |
| **19011** | RPC `-debug` pprof API | ✗ 无监听。`devports.RpcDebugPort` 仍被 Deploy Agent 当作 `/debug/*` 上游代理，但已无进程提供 |
| **18888** | Kratos 内部 HTTP | ✗ 无监听，**且残留已清除**。原 `moewiring/config.go:169` 的硬编码兜底随 15 个过渡开关（含 `KratosInternalHTTPPort()`）于 2026-09-08 整族删除，现全仓零命中 |
| **19032** | Kratos Admin 试点 HTTP | ✗ 无监听，**且残留已清除**。原 `moewiring/config.go:184,189` 硬编码兜底同批删除，现全仓零命中 |

## 外部依赖端口（非本仓库进程）

| 端口 | 服务 | 配置项 | 读取入口 |
|------|------|--------|----------|
| **11434** | Ollama（n100 小主机 `192.168.124.77`） | `config.yaml:91` `llm_inference.base_url` | `conf.Inference().BaseURL`；登记于 `devports.OllamaPort` |
| **6633** | llama-server（文字游戏推理，开发者本机启动） | `config.yaml:97` `llm_inference.game_base_url` | `conf.GameInference()`（`moewiring/api_game.go`）；登记于 `devports.GameInferencePort` |
| **3306** | MySQL（测试库 `47.106.175.49`） | `config.yaml:244-252` `database.*` | `conf.DSN()` |

> 6633/11434 均为「配置有读者、本仓库不提供监听」：后端只按配置的 base_url 发请求，
> 进程由开发者自行启动。`backend/devports/ports.go` 登记这两个常量仅为文档化，不构成任何 bind。

> 8888 同理走 `conf.HTTPPort()`。全仓已无第二处 `viper.New()` 读这些键（第九批后硬编码 searchDirs 的文件数 = 0），
> 因此 `-f` 指定的配置文件对以上每一项都权威。

> 端口/地址多副本与硬编码越界问题见 [配置治理审查 §4.2](./config-hygiene-review-2026-09-08.md)。

**推荐日常流程**

1. **后端**：`cd backend && make moe-social` → :8888（**不**自动启动 Deploy Agent）— 详见 [admin-rpc-runtime-guide.md](./admin-rpc-runtime-guide.md)
2. **管理台**：`cd moe-admin && npm run dev` → http://127.0.0.1:5173/ops/
3. **运维工具**（按需）：`cd backend && make deploy-agent` → :19010
4. 一键全栈：`cd backend && make admin`（或 `scripts/start-admin.*`）
5. 生产构建（按需）：`cd moe-admin && npm run build`，由你自己的静态托管或 CI 发布
