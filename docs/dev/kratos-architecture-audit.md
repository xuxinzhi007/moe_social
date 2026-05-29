# Kratos 架构整理 — 结论与现存问题

> **日期：2026-05-29**  
> **范围**：`backend/` 从 go-zero 单栈迁移到 Kratos 官方布局的收尾审计  
> **关联**：[kratos-directory-ssot.md](./kratos-directory-ssot.md) · [kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 结论（一句话）

**生产运行时已是纯 Kratos 单进程，官方 HTTP 生成链（proto → `*_http.pb.go` → `Register*HTTPServer`）已打通并覆盖 17 个域；约 95% 的目录与路由迁移已完成，剩余 5% 集中在 admin 大批量 CRUD、user 社交余量、platform/llm/websocket 及 `rpc/pb/moe` 桥接退役。**

---

## 2. 目标架构 vs 当前状态

### 2.1 官方 Kratos HTTP 链（已对齐）

```text
api/<domain>/v1/*.proto
  + google.api.http 注解
    → make gen → *_http.pb.go
      → internal/server/http_proto.go
        → Register*HTTPServer（生成代码）
          → internal/server/grpc/<domain>/（薄适配）
            → internal/service → internal/biz → internal/data
```

### 2.2 过渡期旁路（仍在，但逐域缩短）

```text
internal/server/http_compat.go
  → internal/server/httplegacy/*_compat.go
    → internal/apilegacy/*gw（部分路径）
      → internal/legacy/types（BaseResp JSON）
        → internal/service → biz
```

### 2.3 完成度矩阵

| 维度 | 状态 | 说明 |
|------|------|------|
| 生产单进程 Kratos | ✅ 100% | `make moe-social`；无 go-zero 运行时 |
| 官方 proto HTTP 链 | ✅ 已打通 | `third_party` + `protoc-gen-go-http` + `http_proto.go` |
| Proto HTTP 域覆盖 | ✅ **17 域** | 含本轮新增的 `AdminInsights`（5 路由） |
| 目录 D1 迁移 | ✅ ~95% | `moehttp`→`httplegacy`，`api/internal` 仅 stub |
| Compat 路由退役 D2 | 🟡 ~25% | 用户域/社交域已迁；admin CRUD 仍走 compat |
| `api/defs` 归档 D3 | 🟡 镜像已建 | 活跃 defs 仍服务 `make gen-api` |
| `httplegacy` 删除 D4 | ❌ 未开始 | ~198 条活跃 compat 路由仍注册 |
| `rpc/pb/moe` 零引用 | ❌ 未达成 | biz/compat/apilegacy 仍有 ~150+ 文件引用 |

---

## 3. 本轮收尾（最后 5%）已完成项

| 项 | 动作 |
|----|------|
| AdminInsights proto HTTP | `admin_messages.proto` 加 5 条 `google.api.http`；`grpc/admininsights` 适配；`http_proto.go` 注册；compat no-op |
| `api/defs` 归档镜像 | `scripts/archive/api-defs/` + README；`api/defs/README.md` 标注冻结 |
| `make gen-api` 类型漂移防护 | `sync-api-types-to-legacy.sh`：goctl 产出自动同步到 `internal/legacy/types/` |
| 文档同步 | `架构说明.md`、`kratos-directory-ssot.md`、本审计文档 |
| 构建验收 | `go build ./...` + `make check` ✅ |

---

## 4. 当前存在的问题（按优先级）

### P0 — 双轨 HTTP 契约（客户端可见）

| 问题 | 影响 | 现状 |
|------|------|------|
| **响应 JSON 形状不一致** | 已迁 proto HTTP 的路由返回 proto JSON；compat 路由返回 `BaseResp` + `data` 包装 | 同一 App 内混用两种格式；Flutter/admin 需按路径区分解析 |
| **同路径潜在重复注册** | 若 compat 未 no-op 而 proto 已注册，可能双挂 | 已迁域已 no-op `Register*Compat`；admin 子集仍须逐条核对 |

**建议**：新接口只走 proto HTTP；存量 compat 迁移时保持路径不变，但需在客户端侧标记「legacy envelope」直至全量切换。

### P1 — Admin 域是最大的 compat 债务

| 模块 | 活跃 compat 路由（约） | 阻塞原因 |
|------|------------------------|----------|
| `admin_service_compat` | ~55 | `AdminApp` 大量 CRUD 无 proto HTTP 注解 |
| `admin_legacy_compat` | ~28 | 旧管理台路径、混合鉴权 |
| `admin_readonly_compat` | ~3 | 只读列表尚未全部 proto 化 |
| `AdminInsights` | ~~5~~ → **已迁** | 本轮完成 |

**建议下一批**：按 `admin_service_compat` 功能分组（announcements、gifts、users、moderation…）批量加 `google.api.http`，每批 10–15 路由 + compat no-op。

### P1 — User 社交 / VIP 余量

| 模块 | 活跃 compat 路由（约） | 说明 |
|------|------------------------|------|
| `user_compat` | ~41 | 登录/注册等 5 RPC 已 proto；好友/钱包/设备/OAuth 等仍 compat |
| `user_memory_compat` | ~8 | 记忆 CRUD/搜索 |
| `wave2_misc_compat` | ~23 | 杂项波次 2 路由 |

**问题**：`user_messages.proto` 已很大；继续扩 HTTP 注解 vs 拆子 proto（`user_social.proto`）需先定纪律。

### P2 — Platform / LLM / WebSocket

| 模块 | 路由（约） | 说明 |
|------|-----------|------|
| `platform_compat` | ~17 | 文档、图片、配置、埋点 |
| `llm_read_compat` | ~2 | LLM 模型列表/目录（chat turn 已 proto） |
| WebSocket | 未计入 HTTP 路由表 | `api/internal` 无 websocket 残留；可能在 `httplegacy` 或独立 hub |

**问题**：WebSocket 不走 `google.api.http`；需单独 Kratos transport 或保留 compat 入口直至专用方案。

### P2 — `internal/apilegacy` 与 `rpc/pb/moe` 桥

| 问题 | 说明 |
|------|------|
| **伪 gRPC 网关** | `*gw` 包仍被 compat 路径调用，内部经 `moe_bridge` 转 `rpc/pb/moe` |
| **类型双份** | `adminv1.*FromMoe` / `*ToMoe` 遍布 service/compat；proto 已是 SSOT，桥应删除 |
| **biz 层 moe 引用** | `internal/biz/admin`、`llm`、`user` 等仍 import `rpc/pb/moe` |

**根因**：P6 把 message 抽到域 proto，但 compat 仍按旧 moe 形状做 JSON 转换。

**建议**：compat 退役时同步删除 `FromMoe/ToMoe`；biz 只认 `api/<domain>/v1` 类型。

### P3 — `api/defs` + `make gen-api` 风险（已缓解未消除）

| 问题 | 缓解 | 残余风险 |
|------|------|----------|
| goctl 覆盖 handler | `api-guard.sh` 提示 | 改 defs 仍可能还原 `api/internal/handler` |
| types 路径漂移 | **本轮** `sync-api-types-to-legacy.sh` | handler/routes 仍生成到 `api/internal/` |

**纪律**：生产路由变更禁止走 `make gen-api`；仅存量字段同步。

### P3 — `api/internal` 未完全清空

当前仅 3 个文件：

- `handler/routes_stub.go` — hybrid 构建桩
- `handler/README.md`
- `logic/.gitkeep`

**问题**：hybrid 构建标签若仍引用 `api/internal/handler`，无法物理删除目录。

### P4 — 进度指标口径失真

`httplegacy/route_stats.go` 中 `PilotNativeCompatRoutes` 常量仍按「注册函数存在」计数，多数 `Register*Compat` 已 no-op 但常量未下调，导致 `HTTPRouteCoveragePercent` **偏高**。

**建议**：改为从 `routes_*_gen.go` 或运行时路由表统计，或按「活跃 `r.GET/POST`」重算。

---

## 5. 推荐后续路线（D2→D4）

```text
阶段 A（2–3 周）— Admin 分批 proto HTTP
  admin announcements / gifts / users / moderation
  → 每批：proto 注解 + grpc 适配 + compat no-op + moe-admin 回归

阶段 B（2 周）— User 社交余量
  拆 user_social.proto 或扩 user_messages.proto
  → 好友 / 钱包 / OAuth / 设备

阶段 C（1 周）— Platform + LLM 读
  platform.proto + llm read RPC HTTP 化

阶段 D（清理）
  删 httplegacy/ + http_compat.go
  删 internal/apilegacy/*gw
  rpc/pb/moe runtime 引用归零（保留 pb 仅归档或 code gen shim）
  删 api/defs（或仅留 archive）
```

---

## 6. 验收命令（当前可通过）

```bash
cd backend
make gen                    # proto pb/grpc/http
go build ./...
make check                  # moe-social build + 关键包测试
```

---

## 7. 相关文件索引

| 文件 | 角色 |
|------|------|
| `internal/server/http.go` | HTTP 入口：Ops → Proto → Compat |
| `internal/server/http_proto.go` | 17 域 `Register*HTTPServer` |
| `internal/server/http_compat.go` | compat 编排 |
| `internal/server/httplegacy/` | 存量路由实现 |
| `scripts/gen/moe-proto.sh` | proto 生成（含 go-http） |
| `scripts/archive/api-defs/` | defs 只读镜像 |

---

**维护者**：架构迁移完成后，以本文 + `kratos-directory-ssot.md` 为收口 SSOT；状态板细节见 `kratos-migration-status.md`。
