# API 契约

## 新接口（必读）

**新 HTTP 能力**：只加 `api/<domain>/v1/*.proto`（含 `google.api.http`），**禁止**扩大 `api/defs/*.api`。

→ [docs/dev/new-api-kratos.md](../../docs/dev/new-api-kratos.md) · [kratos-directory-ssot.md](../../docs/dev/kratos-directory-ssot.md)

```bash
make gen                              # pb + grpc + http
# 实现 internal/service + internal/biz
# 在 internal/server/http_proto.go 注册 Register*HTTPServer
make check && make moe-social
```

## 存量 goctl（维护老接口）

| 步骤 | 命令 |
|------|------|
| 改 `api/defs/*.api` | `make gen-api`（慎用；types 可能重生到 `api/internal/types`） |
| compat 维护 | `internal/server/httplegacy/*_compat.go` |

## 域 proto 索引（已迁入 proto HTTP）

| 域 | Proto | HTTP 注册 |
|----|-------|-----------|
| Post / Gift / Notify / User … | `api/*/v1/*.proto` | `internal/server/http_proto.go` |
| Moe Admin | [moe/v1/moe.proto](./moe/v1/moe.proto) | `RegisterMoeAdminHTTPServer` |
| VIP 只读 | [vip/v1/vip_read.proto](./vip/v1/vip_read.proto) | `RegisterVipReadAdminHTTPServer` |

余量 admin CRUD、platform 等仍见 `internal/server/httplegacy/`。

## 相关

- [LAYOUT.md](../LAYOUT.md)
- [scripts/README.md](../scripts/README.md)
