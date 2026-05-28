# Kratos 架构完整化 — 定义与验收

> **SSOT**：何时算「完整 Kratos」、与 `/migration` 指标的关系、剩余工作清单。  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md) · **P4**：[kratos-p4-post-migration.md](./kratos-p4-post-migration.md)

---

## 1. 两层指标（勿混淆）

| 指标 | 含义 | 当前 |
|------|------|------|
| `rollout_percent` | **传输铺轨** | **100** |
| `percent` / `p_percent` | **P3 架构完整度**（传输 + logic 退役） | **100** |

P4 起 `percent` 仍反映 P3 公式；**理想目录洁癖**见 §2「应完成」与 [kratos-p4-post-migration.md](./kratos-p4-post-migration.md)。

---

## 2. 「完整 Kratos 架构」定义（DoD）

### 必须（生产路径）— P3 ✅

- [x] 单进程 `make moe-social`，`kratos_pure_enabled: true`
- [x] HTTP：Kratos → `api/moehttp/*_compat` → `internal/service` → `internal/biz`
- [x] compat **263/263** tier-A，零 logic import
- [x] gRPC：Kratos transport + 域 App 薄层
- [x] **`percent == 100`**（logic 清库）

### 应完成（P4 架构洁癖）

- [x] `api/internal/logic/*` **0 业务文件**（`.gitkeep` + gen 后 prune）
- [x] `api/internal/handler/*` 直调 App/GW/biz，无 logic
- [x] 新接口仅 `api/<domain>/v1/*.proto`（纪律；存量 defs 仍维护）— 见 [new-api-kratos.md](./new-api-kratos.md)
- [ ] RPC：wire 从 `service Super` 切独立域 service（**landing.v1.Landing 试点 ✅**；Super 仍兼容）
- [ ] `internal/data` 全覆盖（**D1 landing ✅ · D2 checkin/achievement ✅ · D3 user profile 起步**）
- [x] Hybrid handler：`//go:build hybrid` + 默认 stub（P4-H）

### 永久 bridge（可保留）

- [x] `/swagger`、`/swagger/doc.json`（2 条）

---

## 3. P3-W4 批次 — ✅ 全部完成

| 批次 | 域 | 状态 |
|------|-----|------|
| W4a–W4b-4 | 全域 handler→GW/biz | ✅ |

验收：`make check` · `make audit-logic-orphans` → none

---

## 4. 相关文档

| 文档 | 用途 |
|------|------|
| [kratos-p4-post-migration.md](./kratos-p4-post-migration.md) | P4 轨道 SSOT |
| [kratos-migration.md](./kratos-migration.md) | 目录与命令 |
| [new-api-kratos.md](./new-api-kratos.md) | 新接口纪律 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | gen-api 后 P3 纪律 |

历史冲刺：[../archive/dev/kratos/](../archive/dev/kratos/)
