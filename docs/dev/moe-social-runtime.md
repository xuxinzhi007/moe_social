# moe-social 运行时

> **最后更新：2026-09-11**（第九批：配置读取统一到 `backend/pkg/conf`，`-f` 全局权威）
> 架构：[kratos-migration.md](./kratos-migration.md) · 状态：[kratos-migration-status.md](./kratos-migration-status.md)

## 是什么？

**一个 OS 进程**（`cmd/moe-social`），对外**纯 Kratos HTTP**：

| 维度 | 说明 |
|------|------|
| HTTP | Kratos `:8888` → `internal/server/http.go` `NewHTTPServer` → `RegisterProtoHTTP`（官方 proto 路由） |
| gRPC | ✗ **无对外 gRPC 监听**。`internal/platform/moesocial/` 下没有任何 `transport/grpc` 服务 |
| 配置 SSOT | 文件 `backend/config/config.yaml`（端口取 `runtime.http_port`）；**读取入口 `backend/pkg/conf`**（`conf.Load()` / `conf.Inference()` / `conf.DSN()` …），业务层不自己开 viper |
| API 结构片段 | `api/etc/moe.yaml`（`runtime.api_config_fragment` 指定；**结构模板**，端口以 config.yaml 为准） |
| go-zero | **已从 `go.mod` 完全移除**（0 处引用），无回滚路径 |
| 开发附加 | `make moe-social-dev` = `go run ./cmd/moe-social-stack -agent=false`，即**不带** deploy-agent 的同一套启动 |

## 启动

```bash
cd backend
make moe-social          # = go run ./cmd/moe-social，监听 :8888
make moe-social-stop     # 端口占用时释放
```

可用 flag（`cmd/moe-social/main.go`）：`-f config/config.yaml`（配置路径）、`-f-api`（覆盖 API 片段）、`-migrate`（启动前建表）。

> `-f` 现在是**进程级唯一权威**：第九批之前有一批文件各自 `viper.New()` 从 `./config` 重读
> （硬编码 searchDirs 共 10 个文件），对这些项 `-f` 无效；现已清零，`-f` 指到哪份就全程读哪份。
> 证据：用 `bot_scheduler_tick_seconds: 7` / `dream_scheduler_tick_seconds: 11` 的探针配置从
> `backend/` 启动（同目录 `./config/config.yaml` 写的是 60/300），日志打印 `tick=7s` / `tick=11s`。

成功日志：`moe-social ready: Kratos HTTP-only on port 8888`（`run_http_only.go:50`）。

> `make moe-social` **不会**自动拉起 deploy-agent（:19010）。需要运维工具时另开 `make deploy-agent`。

## 请求路径

```text
HTTP  Client → :8888
              → internal/server/http.go  NewHTTPServer(addr, deps)
              → RegisterProtoHTTP(srv, deps.Proto)   // internal/server/http_proto.go:113
              → internal/service/<domain> → biz → data
```

`run_http_only.go` 的启动顺序：`opts.NormalizeOptions()` → `conf.Load()`（:19，失败即返回，不再静默取零值）→ （可选）`utils.InitDBWithMigrate()`（:23）→ `wiring.StartWithResult({WireOnly:true})`（:29）→ `bootstrap.AfterWire()`（:33）→ `externalHTTPPort()`（:35）→ `newKratosPureHTTPServer()`（:36）→ `kratos.New(...).Run()`（:41-46）。

compat 余量清单：[kratos-legacy-api-migration.md §2.1](./kratos-legacy-api-migration.md#21-httplegacy-compat-清单)
（注：`httplegacy` / `RegisterCompatHTTP` 已在代码中删除，该清单仅作历史归档参考。）

## 生成（与运行时无关）

| 改什么 | 命令 |
|--------|------|
| 域 proto + conf + 路由计数（含 `openapi.yaml`） | `make gen` |
| 仅重生 `openapi.yaml` | `make gen-swagger` |
| 单模块 proto | `make api-one PROTO=api/<mod>/v1/<mod>.proto` |
| 管理台 gen + 编译 | `make gen-moe-admin` |

Kratos 用 `protoc` + `protoc-gen-go` / `-go-grpc` / `-go-http` / `-openapi`，**不再需要 goctl**。首次先 `make init-proto-tools`。

见 [backend/scripts/README.md](../../backend/scripts/README.md)、[new-api-kratos.md](./new-api-kratos.md)。

## 观测与冒烟

```bash
curl -s http://127.0.0.1:8888/health
curl -s http://127.0.0.1:8888/kratos/v1/moe/runtimes
```

`internal/server/http.go:35-37` 只直挂这两个路由，其余全部由 `RegisterProtoHTTP` 按域 proto 注册。

## 生产零 go-zero 自检

```bash
cd backend
make check                                       # go build ./cmd/moe-social + 核心包单测
go list -deps ./cmd/moe-social | grep go-zero    # 应无输出
grep -c go-zero go.mod                           # 应为 0
```

## 已废弃（Makefile 中已无对应 target）

| 旧命令 | 现状 | 替代 |
|--------|------|------|
| `make api` + `make rpc` 双进程 | ✗ target 已删，`backend/rpc/` 目录不存在 | `make moe-social` |
| `make dev` | ✗ target 已删，`cmd/dev/main.go` 不存在 | `make moe-social`（带 agent 用 `make moe-social-stack -agent=true`） |
| `make rpc-debug` | ✗ target 已删，:19011 无监听者 | 无（pprof 未挂载） |
| `make rpc-migrate` | ✗ target 已删 | `make db-migrate` |
| `make moe-kratos`（:1903x 试点） | ✗ target 已删，:19032 无监听者 | `make moe-social` |
| `go build -tags hybrid` | ✗ 全仓库无 `//go:build hybrid` 文件，该 tag 是空操作 | 直接 `make build` |
| `api/super.go`、`rpc/super.go` | ✗ 文件已删 | — |
| `make gen-api` / `make gen-rpc`（goctl） | ✗ target 已删 | `make gen` |
| `curl :8888/migration` | ✗ 路由不存在 | `curl :8888/health` |
