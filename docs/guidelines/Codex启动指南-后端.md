# Codex Startup Guide（后端）

> **更新：2026-05-29** · 单进程 Kratos HTTP（`make moe-social`）

**SSOT**：[kratos-migration.md](../dev/kratos-migration.md) · [LAYOUT.md](../../backend/LAYOUT.md) · [new-api-kratos.md](../dev/new-api-kratos.md)

## 项目结构

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | 生产入口 |
| `config/config.yaml` | 配置 SSOT |
| `api/<domain>/v1/*.proto` | 契约（含 `google.api.http`） |
| `internal/server/protohttp/` | proto HTTP 适配层 |
| `internal/service/`、`internal/biz/`、`internal/data/` | 分层业务 |
| `internal/platform/{svc,wiring,bootstrap,moesocial}/` | 启动装配 |
| `openapi.yaml` | Apifox / OpenAPI |

## 工作规则

1. 新接口：改 `api/<domain>/v1/*.proto` → `make gen` → `protohttp/` + `service/`。
2. 禁止手改 `*_pb.go`、`*_http.pb.go`。
3. 验收：`make check`；`go build ./cmd/moe-social`。

## 生成

```bash
cd backend && make gen
go build ./cmd/moe-social
```
