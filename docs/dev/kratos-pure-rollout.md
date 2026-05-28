# 纯 Kratos 落地（PK）— 当前说明

> **本文档已收缩为摘要。** 执行与开发请以 **[kratos-migration.md](./kratos-migration.md)** 为准。  
> 完整 PK-0～12 冲刺记录见 [../archive/dev/kratos/](../archive/dev/kratos/)。

## 当前结论（2026-05-28）

| 项 | 状态 |
|----|------|
| 生产 | `make moe-social` · Kratos HTTP `:8888` + gRPC `:8080` |
| P5 | Super 退役 · 生产依赖树零 go-zero（[kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md)） |
| 状态板 | [kratos-migration-status.md](./kratos-migration-status.md) |
| 配置 | `config/config.yaml` · `kratos_pure_enabled: true` |
| HTTP 注册 | `api/moehttp/*_compat.go` · `native_gen=0` · `bridge=2` |
| 存量迁移 | [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md)（已完成） |
| 新接口 | `api/<domain>/v1/*.proto` → [new-api-kratos.md](./new-api-kratos.md) |
| 生成 | `make gen`（安全）· 改 defs 用 `make gen-api` |
| 验收 | `make check` · `GET /migration` · `go list -deps ./cmd/moe-social` 无 go-zero |
| 试点进程 `moe-kratos` | **废弃** |
| `make verify-*` | **已删除** |

## PK 里程碑（已完成，仅留档）

PK-0 基线 → PK-9 纯 Kratos 生产 → PK-10b HTTP 全量桥接（`routes_*_gen`）→ PK-11 gRPC Kratos 传输。  
细节与旧命令列表在归档目录，**勿再执行**其中的 `verify-kratos-*` / `gen-moekratospilot-get`。

## 相关链接

- [kratos-migration-status.md](./kratos-migration-status.md)
- [moe-social-runtime.md](./moe-social-runtime.md)
- [backend/LAYOUT.md](../../backend/LAYOUT.md)
