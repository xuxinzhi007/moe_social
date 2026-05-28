# Kratos 架构完整化 — 定义与验收

> **SSOT**：何时算「完整 Kratos」、与 `/migration` 指标的关系、剩余工作清单。  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 两层指标（勿混淆）

| 指标 | 含义 | 当前典型值 |
|------|------|------------|
| `rollout_percent` | **传输铺轨**：路由挂 Kratos、纯 HTTP/gRPC 监听 | **100** |
| `percent` / `p_percent` | **架构完整度**：传输栈 + **legacy logic 退役** | **~87**（随 P3 上升） |

`percent` 公式（纯 Kratos 生产）：

```text
transport_stack = 40% http_native + 30% grpc_service + 20% http_transport + 10% grpc_transport
percent = 85% × transport_stack + 15% × legacy_logic_retired_pct
legacy_logic_retired_pct = (273 - 当前 logic 文件数) / 273 × 100
```

**`percent == 100` 当且仅当**：传输栈满分 **且** `api/internal/logic` 文件清零（baseline 273）。

---

## 2. 「完整 Kratos 架构」定义（DoD）

### 必须（生产路径）

- [x] 单进程 `make moe-social`，`kratos_pure_enabled: true`
- [x] HTTP：Kratos → `api/moehttp/*_compat` → `internal/service` → `internal/biz`
- [x] compat **263/263** tier-A，零 logic import
- [x] gRPC：Kratos transport + 域 App 薄层
- [ ] **`percent == 100`**（logic 清库完成）

### 应完成（仓库洁癖）

- [ ] `api/internal/logic/*` **0 文件**（Hybrid 回滚弃用或 build tag 隔离）
- [ ] `api/internal/handler/*` 直调 App/GW/biz，无 logic
- [ ] 新接口仅 `api/<domain>/v1/*.proto`（不扩 `api/defs`）
- [ ] RPC：`super.*` stub 切域 proto（FS-8/9）
- [ ] 可选：`internal/data` repo 层（当前 GORM 在 biz 内，非阻塞）

### 永久 bridge（可保留）

- `/swagger`、`/swagger/doc.json`（2 条）

---

## 3. P3-W4 批次（handler → biz，删 logic）

| 批次 | 域 | logic 文件 | 状态 |
|------|-----|-----------|------|
| W4a | image、remote WS、审计工具 | -5 | ✅ |
| **W4b-1** | behavior、landing、ops、appcfg、comment | -6 | ✅ |
| **W4b-2** | achievement、checkin、gift、post、community | -37 | ✅ |
| W4b-3 | wave2 杂项（emoji、avatar、vip…） | ~30 | 待做 |
| W4b-4 | user、admin | ~141 | 待做 |

每批验收：

```bash
cd backend && make check && make audit-logic-orphans
```

---

## 4. 相关文档

| 文档 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | 目录与命令 |
| [new-api-kratos.md](./new-api-kratos.md) | 新接口纪律 |
| [kratos-legacy-api-migration.md](./kratos-legacy-api-migration.md) | 存量 compat 清单 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | gen-api 空壳清理 |

历史冲刺：[../archive/dev/kratos/](../archive/dev/kratos/)
