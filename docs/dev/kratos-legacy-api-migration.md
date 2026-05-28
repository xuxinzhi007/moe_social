# 存量 HTTP 接口迁移评估（2026-05-27）

> SSOT 架构：[kratos-migration.md](./kratos-migration.md) · 新接口：[new-api-kratos.md](./new-api-kratos.md)

## 结论：**可以开始按域迁移**

传输与业务下沉已完成；**HTTP 路由已全部挂 Kratos compat**（`native=0`）。后续是把 logic 薄转逐步改为 **`internal/service` 直挂**，并补全 `api/<domain>/v1/*.proto`。

---

## 1. 两套「进度」不要混

| 口径 | 当前值 | 含义 |
|------|--------|------|
| `GET /migration` → `percent` | **100** | PK 权重：Kratos 传输 + biz/GW + 路由挂 Kratos |
| `http_native_handler_pct` | **100** | 含 **247 条** `wrapNativeHTTP(goctl handler)`（仍算 native） |
| **实现层 Kratos** | **~6%** | 仅 **16** 条 `*_compat.go` 直挂 `internal/service` |

生产已稳定，迁移是 **契约与 HTTP 适配层** 整理，不是再改运行时。

---

## 2. 路由构成（268 条 goctl）

| 类型 | 数量 | 实现路径 |
|------|------|----------|
| `routes_native_gen` | **0** | 已全部迁出；仅 **bridge=2**（swagger）仍走 `routes_bridge_gen` |
| `*_compat`（跳过 gen） | **266 条路由 / 216 路径** | Kratos → **internal/service** 或 **logic 薄转** → **biz** |
| `routes_bridge_gen` | **2** | swagger 文档 |

### 波次 1 已落地（2026-05-27）

| 域 | 路由数 | 文件 |
|----|--------|------|
| checkin | 7 | `api/moehttp/checkin_compat.go` · `api/checkin/v1/checkin.proto` |
| achievement | 4 | `api/moehttp/achievement_compat.go` |
| behavior | 1 | `api/moehttp/behavior_compat.go` |
| gift | 6 | `api/moehttp/gift_compat.go` |
| comment | 2 | `api/moehttp/comment_compat.go` |

### 波次 2 已落地（2026-05-27）

| 域 | 路由数 | 文件 |
|----|--------|------|
| user | 57 | `api/moehttp/user_logic_compat.go` |
| post / community / ai / chat / notification / … | 70 | `api/moehttp/wave2_logic_compat.go` |

### 波次 3 已落地（2026-05-27）

| 域 | 路由数 | 文件 |
|----|--------|------|
| admin（logic 薄转） | 83 | `api/moehttp/admin_logic_compat.go` |
| llm 写 / voice / moe / appcfg / content | 17 | `api/moehttp/platform_logic_compat.go` |

`routes_native_gen`：**100 → 0**（`make gen-http-routes` → `native=0 bridge=2`）。

**post / community / chat / user** 已在波次 2（`wave2_logic_compat.go`、`user_logic_compat.go`）完成。

已 compat 的 pilot（在 `skipExactPaths`）：

- Moe Admin 读 ×2、Admin dashboard/growth/schema ×3、Insights ×5、VIP plans ×1、LLM 读 ×2、Landing ×3、波次1 域 ×20、波次2 域 ×127

---

## 3. 业务层（F 曲线）— 已完成

- `internal/biz/*`：**17** 个域包，逻辑 SSOT 在此
- `api/internal/*gw`：均为 **`in_process`**（进程内调 biz，无 :8080 回环）
- `api/internal/logic`：**零** `SuperRpcClient`
- `internal/service`：**14** 个域已有 AppService（缺 `appcfg`、`notify` 独立 service）

---

## 4. logic 存量（按 goctl group）

| group | logic 文件数 | internal/service | 域 proto | 建议波次 |
|-------|-------------|------------------|----------|----------|
| admin | 86 | ✅ admin | admin_insights 部分 | 5（已部分 compat） |
| user | 51 | ✅ user | — | 4 |
| ai | 19 | ✅ ai | ai_resources | 3 |
| community | 11 | ✅ community | — | 2 |
| post | 9 | ✅ post | — | 2 |
| llm | 9 | ✅ llm | llm_chat 部分 | 3（2 条已 compat） |
| notification | 7 | — | — | 2（可新建 service/notify） |
| gift | 6 | ✅ gift | — | 1 |
| chat | 6 | ✅ chat | private_message 部分 | 2 |
| voice | 5 | — | — | 4 |
| emoji | 5 | — | — | 4 |
| checkin | 5 | ✅ checkin | — | **1 首选** |
| avatar | 5 | — | 合入 user | 4 |
| image | 4 | — | — | 4 |
| achievement | 4 | ✅ achievement | — | **1 首选** |
| vip | 3 | ✅ vip | vip_read 部分 | 1（admin 读已 compat） |
| privatemsg | 3 | — | chat proto | 2 |
| 其它 ≤2 | 各 1～2 | 部分 | — | 1 |

---

## 5. 单域迁移步骤（模板）

以 **checkin** 为例：

1. 新增/补全 `api/checkin/v1/checkin.proto`（HTTP 路径注释与 `api/defs` 一致）
2. `make gen` → `*.pb.go`
3. 在 `internal/service/checkin/app.go` 暴露 RPC/HTTP 用方法（调 `internal/biz/checkin`）
4. 新建 `api/moehttp/checkin_compat.go`，`RegisterCheckinCompat`
5. 在 `register_all.go` 调用；路由 path 加入 `skipExactPaths`
6. `make gen-http-routes`（该域从 247 中减少）
7. `make check` + 手测对应 App/Admin 页面
8. 确认无引用后，logic 文件可删（**不要**先删 defs，最后再收口契约）

---

## 6. 风险与纪律

- **每域一个 PR**，避免与 `make gen-api` 大范围冲突
- 路径、JSON 字段与现网 **完全一致**（Flutter / moe-admin 无感）
- 新能力仍走 [new-api-kratos.md](./new-api-kratos.md)，**勿**在迁移同时扩 `api/defs`
- `routes_native_gen` 在全部迁完前仍会保留大部分路由

---

## 7. 完成定义（域级 Done）

- [ ] 该域 HTTP 均在 `*_compat.go` 或官方 Kratos service 注册
- [ ] `skipExactPaths` 含该域所有 path
- [ ] `api/<domain>/v1/*.proto` 为契约 SSOT
- [ ] 对应 `api/internal/logic/<group>` 无活跃引用（或仅留废弃注释）
- [ ] `make check` 通过

全站实现层 100%：247→0 条 logic 桥接；仅保留 swagger bridge（2）。
