# Kratos 架构完整化 — 定义与验收

> **最后更新：2026-05-28**  
> **SSOT**：何时算「完整 Kratos」、与 `/migration` 指标的关系、剩余工作。  
> **状态板**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 进度总览（2026-05-28）

| 口径 | 完成度 | 验收 |
|------|--------|------|
| **生产 Kratos 运行时** | **100%** | `make moe-social` · Kratos HTTP :8888 + gRPC :8080 |
| **P0–P3**（传输 + logic 清库） | **100%** | `/migration` `percent` · `api/internal/logic` 0 |
| **P4**（data / 12 域 gRPC） | **~95–100%** | 20/21 data 域 · 12/12 gRPC |
| **P5**（Super 退役 + 零 go-zero 生产） | **100%** | 见 [kratos-p5-super-retirement.md](./kratos-p5-super-retirement.md) · [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) |
| **仓库源文件零 go-zero** | **100%** | P5-E 已删 hybrid 源；`go.mod` 无 go-zero |

---

## 2. 两层指标（勿混淆）

| 指标 | 含义 | 当前 |
|------|------|------|
| `rollout_percent` | **传输铺轨** | **100** |
| `percent` / `p_percent` | **P3 架构完整度**（传输 + api logic 退役） | **100** |
| **生产零 go-zero** | `go list -deps ./cmd/moe-social` 无 `zeromicro/go-zero` | **✅ 达标**（P5-D） |

`percent` **不**表示「仓库里每一个 .go 文件都无 go-zero」；该口径见 P5-D 专文。

---

## 3. 「完整 Kratos 架构」DoD

### 必须（生产路径）— P3 ✅

- [x] 单进程 `make moe-social`，`kratos_pure_enabled: true`
- [x] HTTP：Kratos → `api/moehttp/*_compat` → `internal/service` → `internal/biz`
- [x] compat **263** 路由，`routes_native_gen=0`
- [x] `api/internal/logic` **0** 业务文件
- [x] gRPC：Kratos transport + 域 App（12 服务 + MoeAdmin）
- [x] **`percent == 100`**

### P4 架构洁癖 — ✅ 基本完成

- [x] 独立域 gRPC **12/12**（notify / chat / vip 等）
- [x] `internal/data` **20/21** 域（voice 等可后续补）
- [x] Hybrid：`//go:build hybrid` + 默认 stub（P4-H）

### P5 Super 退役 + 零 go-zero 生产 — ✅

- [x] `rpc/internal/logic` **0**；`moe.proto` 无 `service Super`
- [x] 单进程不注册 Super；gateway 无 `SuperClient`
- [x] 生产 `moe-social` 依赖树 **无 go-zero**
- [x] `moehttp` 使用 Kratos `Bind`（非 `httpx`）

### 永久 bridge（可保留）

- [x] `/swagger`、`/swagger/doc.json`（2 条）

### 待验证（非代码缺口）

- [ ] grpc 冒烟：notify / chat / vip（[grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md)）
- [ ] 分体部署联调（[kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md)）

### 可选后续

- [ ] 从 `go.mod` 物理移除 go-zero（需废弃 `-tags hybrid` 或拆 module）
- [ ] 删除 `api/internal/handler/**` hybrid 目录

---

## 4. 相关文档

| 文档 | 用途 |
|------|------|
| [kratos-migration-status.md](./kratos-migration-status.md) | 状态板 |
| [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) | P5-D 验收命令 |
| [kratos-p4-post-migration.md](./kratos-p4-post-migration.md) | P4 轨道 |
| [kratos-migration.md](./kratos-migration.md) | 目录与命令 |
| [new-api-kratos.md](./new-api-kratos.md) | 新接口纪律 |
| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | gen-api 纪律 |

历史冲刺：[../archive/dev/kratos/](../archive/dev/kratos/)
