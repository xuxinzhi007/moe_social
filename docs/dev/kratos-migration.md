# Kratos 后端架构（SSOT）

> **更新：2026-05-29** · 迁移已完成：单进程 HTTP-only

| 文档 | 用途 |
|------|------|
| 本文 | 架构、目录、命令 |
| [new-api-kratos.md](./new-api-kratos.md) | **新接口开发** |
| [openapi-apifox.md](./openapi-apifox.md) | Apifox 导入 |
| [../../backend/LAYOUT.md](../../backend/LAYOUT.md) | 仓库目录 |

历史迁移专文见本目录：`kratos-legacy-api-migration.md`、`kratos-server-layout-migration.md`、`goctl-generation-hygiene.md`。

---

## 架构

```text
Client (:8888)
      │
      ▼
cmd/moe-social → internal/platform/moesocial
      │
      ▼
internal/server/http.go
  ├─ RegisterProtoHTTP  → internal/server/protohttp/<domain>/
  ├─ RegisterTransportHTTP → OAuth / WS / SSE
  └─ RegisterDocsHTTP → /swagger

protohttp/<domain> → internal/service → internal/biz → internal/data
```

---

## 目录

| 路径 | 角色 |
|------|------|
| `cmd/moe-social/` | 生产入口 |
| `config/config.yaml` | 配置 SSOT |
| `api/<domain>/v1/*.proto` | 契约 SSOT |
| `openapi.yaml` | `make gen` 产出 |
| `internal/server/protohttp/` | proto HTTP 适配层 |
| `internal/platform/{svc,wiring,bootstrap,moesocial}/` | 装配与启动 |

---

## 命令

```bash
cd backend
make gen          # proto + conf + 路由计数
make moe-social   # HTTP :8888
make check        # 编译 + 单测
```

新接口：改 proto → `make gen` → 在 `protohttp/` 实现 handler（见 [new-api-kratos.md](./new-api-kratos.md)）。
