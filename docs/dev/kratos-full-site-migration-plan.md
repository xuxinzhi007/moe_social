# 全站 Kratos 迁移方案（Phase 4+）

> **状态**：准备启动（2026-05-27）  
> **前置已完成**：Hybrid Moe **100%** · 纯 Kratos 试点方案 **100%** · 生产对外仍 **:8888**（`moe-social`）  
> **SSOT 总览**：[kratos-migration.md](./kratos-migration.md) · **勾选**：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 进度口径（必读，避免歧义）

全站相关进度有 **三条独立曲线**，不可混用：

| 指标 | 代号 | 当前 | 含义 |
|------|------|------|------|
| Moe 域 Hybrid | **A** | **100%** | `biz/service/data` + `MoeGW` + `moe.proto`；`make verify-moe-complete` |
| 纯 Kratos 试点方案 | **B** | **100%** | Phase 0～6（`moe-kratos`、Wire、VIP 只读试点）；`make verify-kratos-100` |
| **全站迁移总进度** | **F** | **~22%** | 各业务域下沉 `biz` + 契约拆分 + 最终退役 `super.*` |
| 工程现代化就绪度 | **G** | **~48%** | A+B + 单二进制可构建 + 观测；**不等于** F |

**「100%」仅指 A 或 B**；**不等于全站已是纯 Kratos**。

### 1.1 指标 F 计算公式（SSOT）

```text
F = Σ (域权重 × 域内进度)
```

域内进度定义：

| 档位 | 进度 | 条件 |
|------|------|------|
| 0 | 0% | 仅 legacy `api|rpc/internal/logic` |
| 1 | 20% | 试点：`biz` 只读或 Kratos :19032 路径验证 |
| 2 | 60% | 写路径进 `biz`；HTTP 仍 `super.api` 路径（经 GW 或薄 logic） |
| 3 | 100% | 域契约 `api/<domain>/v1/*.proto`；logic 仅适配；可关 `super` 中该域 RPC |

### 1.2 当前各域得分（2026-05-27 实测）

| 域 | 权重 | 域内进度 | 贡献 | 依据（代码） |
|----|------|----------|------|----------------|
| **Moe** | 12% | 100% | 12.0% | `internal/biz/moe`（7 文件）、`moeadmingw`、16 条 HTTP 走 GW |
| **VIP** | 8% | 20% | 1.6% | `biz/vip` 只读；`vip_read.proto`；写操作仍在 admin logic |
| **User** | 20% | 0% | 0% | `api/internal/logic/user` **62** 文件 |
| **Admin（非 Moe）** | 14% | 0% | 0% | `logic/admin` 约 **66** 文件（81−15 Moe 薄壳） |
| **社交** | 18% | 0% | 0% | post/community/chat/comment/privatemsg 等 |
| **AI / LLM** | 14% | 0% | 0% | `ai` 19 + `llm` 15 文件 |
| **实时 / 通知** | 8% | 0% | 0% | voice/chat/notification |
| **其它** | 6% | 0% | 0% | gift/checkin/achievement/ops/landing… |
| **平台基建** | 10% | 80% | 8.0% | `moe-social` 单进程、`build-moe-social`、`:19020` 观测；compose 默认仍双二进制 |
| **合计 F** | 100% | — | **~21.6% → 报告 ~22%** | |

### 1.3 代码规模快照（审计用）

| 项 | 数量 | 说明 |
|----|------|------|
| `super.api` 行数 | ~4513 | HTTP 契约 SSOT（legacy） |
| `super.proto` 行数 | ~3025 | gRPC 契约 SSOT（legacy） |
| HTTP `@handler` | **249** | 全站 REST 入口 |
| `super.proto` rpc 方法 | **~194** | 全站 gRPC |
| `api/internal/logic/*.go` | **272** | go-zero HTTP 实现 |
| `rpc/internal/logic/*.go` | **207** | go-zero gRPC 实现 |
| `internal/biz/*.go`（非 test） | **8** | 仅 moe(7) + vip(1) |
| `internal/service` | moe | 域服务层 |
| `internal/data` | moedata | 仓储层 |
| Moe 专用 HTTP | **16** | 14 admin + 2 `/api/moe/tools/*` |

**按 HTTP 路由粗算**：已分层路由 16/249 ≈ **6.4%**（与 F 的 22% 不矛盾——F 含 Moe 复杂度权重与平台分）。

### 1.4 指标 G（工程就绪度 ~48%）

```text
G = 30% (A: Moe Hybrid 100%)
    + 15% (B: 纯 Kratos 试点方案 100%)
    + 8%  (F 的 22% × 40% 权重折算)
    + 5%  (bin/moe-social 可构建，部署链未默认切换)
    ≈ 48%
```

用于回答「能不能继续上线 / 开发」：**可以**（G 高）。  
用于回答「全站迁完没有」：**没有**（F 低）。

---

## 2. 目标终态

```text
  Flutter / moe-admin / 第三方
           │  HTTP :8888（路径尽量不变）
           ▼
  cmd/moe-social（或未来 cmd/moe-platform）
           ├─ Kratos HTTP（grpc-gateway / 分域 proto）
           ├─ Kratos gRPC（api/*/v1）
           └─ 薄 transport → internal/service → biz → data
           
  退役：super.api、super.proto、api|rpc 双 main、goctl 全量 logic
```

**原则**：

1. **对外 :8888 与 JSON 路径**在每一阶段保持不变，除非发版说明。
2. **按域迁移**，域内 100% 再切下一域；禁止「半域双写」无验收。
3. **Hybrid 可回退**：每域保留 `super` 转发开关直至域达 100%。
4. **Moe 已迁路径禁止回退到巨型 logic**（纪律见 [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md)）。

---

## 3. 分阶段路线图（Phase FS-0 ～ FS-8）

### FS-0 准备（当前，~1 周）— 进行中

| 项 | 交付 | 验收 |
|----|------|------|
| 进度 SSOT | 本文 + 更新 `kratos-migration.md` | 团队对齐 F/G 口径 |
| 域清单 | §4 域表 + logic 文件数 | 与 `find api/internal/logic` 一致 |
| 部署基线 | 文档明确 `bin/moe-social` | `make build-moe-social` |
| 冻结扩张 | `super.api` 新功能走域 proto 或明确例外 | PR 检查 |

### FS-1 平台与契约基座（~2 周）

| 项 | 交付 |
|----|------|
| `internal/conf/moe/v1` → `bootstrap.proto` 扩展 Server/DB/Redis |
| 域目录模板 | `api/<domain>/v1/`、`internal/biz|service|data/<domain>` |
| `make verify-domain-<name>` 脚本骨架 | 每域可复制 |
| compose / deploy 可选单容器 `moe-social` | 与双二进制并存 |

**不迁业务**，只铺轨。

### FS-2 VIP 全量（~2～3 周）— 建议首个业务域

| 项 | 说明 |
|----|------|
| 范围 | Admin CRUD + 用户侧 `getVipPlans` 等 |
| 契约 | 扩展 `api/vip/v1/`（不止 `vip_read.proto`） |
| 实现 | `biz/vip` 补写路径；Admin HTTP 经 GW 或 Kratos :8888 子路由 |
| 验收 | `verify-domain-vip`；Flutter 下单/计划列表回归 |

**理由**：体量小于 User、与商业化相关、已有 20% 试点。

### FS-3 User 核心（~4～6 周）

| 项 | 说明 |
|----|------|
| 范围 | 登录注册、资料、关注、VIP 状态、记忆（可拆 FS-3b） |
| 风险 | 最高流量；需灰度 + 双读对比 |
| 契约 | `api/user/v1/user.proto` |

### FS-4 Admin 非 Moe（~3～4 周）

仪表盘、用户/内容审核、运营配置等（`logic/admin` 余量 ~66 文件）。

### FS-5 社交与内容（~4～6 周）

post、community、comment、gift、checkin、achievement。

### FS-6 AI / LLM（~4～8 周）

`ai` + `llm`；与 `pkg/llminference`、本地模型下载强耦合，单独排期。

### FS-7 实时通道（~3～4 周）

chat WS、voice、privatemsg；transport 层差异大，放后期。

### FS-8 退役 super（~2～4 周）

| 项 | 说明 |
|----|------|
| 删除 | `super.api` / `super.proto`、双 `runserver`、bulk logic |
| 入口 | 单一 `kratos.App` 或保留 `moe-social` 壳加载 Kratos |
| 验收 | `make verify-full-site`（待建） |

### 粗算工期

| 场景 | 人力 | 日历 |
|------|------|------|
| 保守 | 1 后端全职 | **9～12 个月** |
| 并行 | 2 后端 + 架构 review | **5～7 个月** |

---

## 4. 业务域清单（迁移 backlog）

| 优先级 | 域 | API logic 文件 | RPC 依赖 | 建议阶段 | 备注 |
|--------|-----|----------------|----------|----------|------|
| P0 | Moe | 2 + 15 admin 薄壳 | moe.v1 | ✅ 完成 | 勿再写 legacy |
| P1 | VIP | 3 + admin 子集 | super | FS-2 | 已有 biz 只读 |
| P1 | User | 62 | super | FS-3 | 核心路径 |
| P2 | Admin | ~66 | super | FS-4 | 依赖 User 部分接口 |
| P2 | Post / Community | 21 | super | FS-5 | |
| P2 | Gift / Checkin / Achievement | 16 | super | FS-5 | |
| P3 | AI / LLM | 34 | super | FS-6 | 复杂度高 |
| P3 | Chat / Voice / PM | 20 | super | FS-7 | WebSocket |
| P4 | 其它 | ~15 | super | FS-5/8 | doc/ops/landing… |

---

## 5. 单域迁移标准流程（复制粘贴）

每个域重复以下步骤：

```text
1. 契约  api/<domain>/v1/*.proto（HTTP 注解或独立 REST 映射表）
2. 生成  make gen-<domain>-proto
3. 业务  internal/biz/<domain> → service → data
4. 传输  server/<domain>grpc 或 moeadmingw 式 Gateway
5. 灰度  config：use_<domain>_biz、kratos_<domain>_enabled
6. 验收  make verify-domain-<domain>
7. 清理  删除该域 rpc/internal/logic 与 api logic 中的重复实现
8. 文档  更新 kratos-migration-status.md 域进度
```

**禁止**：在未验收前删除 `super.proto` 中该域 message（避免其他域编译断裂）。

---

## 6. 验收命令（规划）

| 阶段 | 命令 | 状态 |
|------|------|------|
| Hybrid Moe | `make verify-moe-complete` | ✅ |
| 纯 Kratos 试点 | `make verify-kratos-100` | ✅ |
| VIP 域 | `make verify-domain-vip` | ⬜ 待 FS-2 实现 |
| 全站 | `make verify-full-site` | ⬜ 待 FS-8 实现 |

日常不变：

```bash
cd backend
make moe-social              # 开发 / 生产 HTTP :8888
make build-moe-social        # bin/moe-social
make verify-kratos-100       # 试点 + Hybrid 回归
```

---

## 7. 风险与决策门

| 风险 | 缓解 |
|------|------|
| `super.api` 4.5k 行难拆 | 按域剪切类型定义到 `api/<domain>/v1/types.proto` |
| 双写/漂移 | 域内 SSOT 仅 proto；logic 只转发 |
| 部署双二进制 vs 单二进制 | FS-1 文档化；FS-8 前保持两种均可 |
| 工期失控 | 每 FS 独立发版；F 指标按域更新 |

**决策门（进入 FS-2 前）**：

- [ ] 产品确认 VIP 为下一域（非 User 抢跑）
- [ ] 分配至少 1 人 **≥60% 时间** 做迁移 2 个月
- [ ] `make build-moe-social` 纳入 CI 或发布流水线（可选）

---

## 8. 相关文档

| 文件 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | Hybrid SSOT、F/G 口径 |
| [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) | 试点方案（已 100%） |
| [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md) | Moe 纪律 |
| [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md) | 里程碑索引 |
| [kratos-migration-status.md](./kratos-migration-status.md) | 勾选清单 |
