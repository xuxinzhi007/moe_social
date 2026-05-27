# Kratos 混合架构说明（SSOT）

> **更新：2026-05-28**  
> **当前阶段：F109 完成** · **全站迁移 F：~98%** · **对外 HTTP：:8888**（`make moe-social`）  
> 全站方案：[kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) · **勾选**：[kratos-migration-status.md](./kratos-migration-status.md) · 路线图：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) · 试点：[kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md)

---

## 0. 当前阶段一览

| 项目 | 状态 |
|------|------|
| **生产入口** | `make moe-social` → **HTTP :8888** + 内网 **gRPC :8080**（`internal/platform/moesocial/run.go`） |
| **A · Moe Hybrid** | ✅ 100% — `moeadmingw` + `biz/moe` |
| **B · 纯 Kratos 试点** | ✅ 100% — `make moe-kratos`（:1903x，非对外） |
| **FS-2 VIP 套餐** | ✅ 100% — `vipadmingw` + `biz/vip` |
| **FS-3 User 域** | ✅ 100% — F109：`usergw` 含 OAuth/设备/钱包/CRUD 尾巴 |
| **FS-4 Admin 域** | ✅ 100% — F108：`admingw` 全 HTTP in_process |
| **FS-5 社交 / AI / Chat** | ✅ ~95% — post/comment/community/gift + `aigw`/`chatgw`/`llmgw` |
| **F · 全站 biz+GW** | **~98%** — `make verify-sprint-f109-user-tail` |
| **G · 工程就绪** | **~78%** — Hybrid 可上线；FS-9 契约未退役 |
| **下一里程碑** | **F110**：~8 个 logic 零 SuperRpc → FS-8 goctl 切域 |

**`make moe-social` 启动成功标志**（节选）：

```text
moe api_in_process: enabled
moe admin gateway route: in_process
vip api_in_process: enabled
vip gateway route: in_process
user api_in_process: enabled
user gateway route: in_process
moe-social: 单进程已就绪 — gRPC …:8080 + HTTP …:8888
```

---

## 1. 当前是什么架构？

| 名称 | 含义 |
|------|------|
| **Hybrid（混合）** | 业务按 Kratos 分层（`biz` / `service` / `data`），**运行时仍为 go-zero**（`rest` + `zrpc`）+ `super.api` / `super.proto` |
| **不是纯 Kratos** | 生产未使用 `kratos.App` 替代双传输；未退役 `super.*` |
| **Moe 域（A）** | `biz/moe` + `MoeGW` + `moe.proto` → **100%** |
| **VIP 套餐域** | `biz/vip` + `VipGW` → **100%**（用户 VIP **订单**仍属 User 域） |
| **User** | `biz/user` + `UserGW` → **100%**（F109） |
| **Admin（非 Moe）** | `biz/admin` + `AdminGW` → **100%**（F108） |
| **AI / LLM / Chat** | `aigw` / `llmgw` / `chatgw` → **~97%**（AI 用户配置 HTTP 仍 SuperRpc） |
| **纯 Kratos 试点（B）** | Phase 0～6 → **100%**；`:19031/:19032` **非对外** |
| **全站迁移（F）** | 各域下沉 `biz` + GW → **~98%**；退役 `super.*` 见 FS-9 |
| **工程就绪度（G）** | **~78%** — Hybrid 可上线；契约拆分未完成 |

进度口径：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义)。

### 1.1 生产架构图（2026-05-28）

```text
  Flutter / moe-admin / 第三方
           │  HTTP :8888  （super.api 路径不变）
           ▼
  ┌──────────────────────────────────────────────────────────┐
  │  API 进程（go-zero rest）— api/runserver                  │
  │                                                          │
  │  moeadmingw · vipadmingw · usergw · admingw              │
  │  aigw · llmgw · chatgw · postgw · commentgw · …          │
  │         in_process → internal/biz → service → MySQL      │
  │                                                          │
  │  少量残留（F110）：avatar / ai config / admin_public /   │
  │  moe execute → SuperRpcClient ──────────────────────────┼──┐
  └──────────────────────────────────────────────────────────┘  │
                                                                  │ gRPC :8080
                                                                  ▼
  ┌──────────────────────────────────────────────────────────┐
  │  RPC 进程（zrpc）— rpc/runserver                          │
  │  · super.Super（薄层转调 userapp/llmapp/adminapp 等）     │
  │  · moe.v1.MoeAdmin（moegrpc）                            │
  └──────────────────────────────────────────────────────────┘

  并行（开发/验证，不对公网）:
  · make moe-kratos  → :19031 gRPC + :19032 HTTP
  · make moe-platform → :19020/migration
```

**in_process 含义**：API 进程内直接调 `internal/biz`，不经 `127.0.0.1:8080` 回环；仍共用同一 MySQL。

**纯 Kratos 终态**（FS-8）：单入口、分域 `api/*/v1/*.proto`、退役 `super.*`。见 [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md)。

---

## 2. 使用方法

### 2.1 日常开发（推荐）

```bash
cd backend
make migrate-moe          # 缺表时（如 moe_agent_run_logs）
make moe-social           # 单进程：8888 HTTP + 8080 gRPC
```

另开终端：

```bash
# llama-server :6633
cd moe-admin && npm run dev   # 管理台，代理到 :8888
```

启动成功标志：

- `数据库连接成功` **只应出现 1 次**
- `moe admin gateway route: in_process`
- `moe-social: 单进程已就绪 — gRPC …:8080 + HTTP …:8888`

### 2.2 经典双进程（与线上一致）

```bash
make dev                  # 或 make rpc + make api
```

### 2.3 代码生成

```bash
make gen-moe-proto        # 仅 Moe：api/moe/v1/*.pb.go
make gen-rpc              # super.proto → rpc/pb/super
make gen-api              # super.api → handler/types
make gen                  # 以上全部（改契约后）
make gen-moe-admin        # gen 后清理 Moe 空壳 logic 并编译
```

### 2.4 验收

**日常（生产 Hybrid）**

```bash
make verify-moe-complete         # A：Moe 域 100%
make verify-sprint-f109-user-tail # F109：User + LLM 记忆读
make verify-sprint-f108-admin-tail
make verify-sprint-f100-final    # FS-8/9 结构
make verify-sprint-regression    # F70–F100d 回归
make verify-platform             # bin/moe-social
make build-moe-social
make moe-social                  # 对外 :8888
```

**纯 Kratos 试点（B，并行非生产）**

```bash
make verify-kratos-100      # 试点 100% + Hybrid 回归
make moe-kratos             # :19031 gRPC + :19032 HTTP
```

详见 [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md)。

### 2.5 纯 Kratos 试点（开发可选）

| 命令 | 端口 | 说明 |
|------|------|------|
| `make moe-kratos` | 19031 + 19032 | 与 :8888/:8080 **并行**，非生产默认 |
| `bash scripts/grpcurl-moe-kratos.sh` | 19031 | gRPC reflection 探针 |

灰度（Phase 3）：`config.yaml` 设 `kratos_admin_http_enabled: true` 且先起 `moe-kratos`，则 :8888 的 **ListRuntimes / GetBrainPipeline** 经 `MoeGW` 转发到 :19032；日志 `moe admin gateway route: kratos_http`。

### 2.6 构建与部署（注意）

| 场景 | 命令/产物 | 进程数 |
|------|-----------|--------|
| **开发** | `make moe-social` | 1 |
| **默认 build** | `make build` → `moe-social-api` + `moe-social-rpc` | 部署常为 **2 二进制 / 2 容器** |
| **单二进制（需自接）** | `go build -o moe-social ./cmd/moe-social` | 1（仍监听 8888+8080） |

Compose / `deploy-agent` 尚未默认改为单二进制；见 [DEPLOY.md](../../backend/DEPLOY.md)。

### 2.7 观测

```bash
make moe-platform
curl -s http://127.0.0.1:19020/migration    # Hybrid 总览
curl -s http://127.0.0.1:19032/migration    # 纯 Kratos 试点进度（需 make moe-kratos）
```

---

## 3. 代码生成方式（契约 SSOT）

### 3.1 三套契约并行

| 层 | 源文件 | 命令 | 输出目录 | 冲突？ |
|----|--------|------|----------|--------|
| HTTP 全站 | `api/super.api` | `make gen-api` | `api/internal/handler`、`types` | 与 Moe proto **不同目录** |
| gRPC 全站 | `rpc/super.proto` | `make gen-rpc` | `rpc/pb/super/`、`rpc/internal/server` | 同上 |
| gRPC Moe | `api/moe/v1/moe.proto` | `make gen-moe-proto` | **同目录** `moe.pb.go`、`moe_grpc.pb.go`（包 `moev1`） | 与 `super` **包名不同** |

**不要**对 `moe.proto` 手写错误 protoc 路径（曾生成 `api/moe/v1/api/moe/v1/` 嵌套）；必须用 `scripts/gen-moe-proto.sh`（`go_opt=module=backend`）。

### 3.2 新功能写在哪？

| 域 | 契约 | 实现 |
|----|------|------|
| **Moe** | `api/moe/v1/moe.proto`；HTTP 仍 `super.api` 路径 | `biz/moe` → `moeadmingw` |
| **VIP 套餐** | `api/vip/v1/` + `super.api` 路径 | `biz/vip` → `vipadmingw` |
| **User** | 暂 `super.api` | `biz/user` → `usergw`（F109：含 OAuth/设备/钱包/CRUD 尾巴） |
| **Admin / AI / LLM / Chat / 社交** | `super.api` 路径不变 | `admingw` / `aigw` / `llmgw` / `chatgw` / postgw 等 in_process |
| **残留（F110）** | `super.api` | avatar / ai config / admin_public / moe execute → 仍 SuperRpc |

### 3.3 `make gen` 后必查

- `go build ./api ./rpc`
- 删除 goctl 产生的 **重复 Moe 空壳** `*_logic.go`（用 `make gen-moe-admin`）

---

## 4. 配置（`backend/config/config.yaml` → `moe`）

| 键 | 默认 | 作用 |
|----|------|------|
| `api_in_process` | `true` | Admin Moe HTTP 直调进程内 `MoeAdmin`（不走 8080） |
| `register_moe_grpc` | `true` | RPC 端口注册 `moe.v1.MoeAdmin` |
| `use_moe_grpc` | `true` | 无 in_process 时 API 走 moe gRPC |
| `single_process` | `false` | 使用 `make moe-social` 时可设 `true`（标记） |
| `vip_api_in_process` | `true` | VIP 套餐 HTTP 走 `vipadmingw` → `biz/vip` |
| `user_api_in_process` | `true` | User 核心 HTTP 走 `usergw` → `biz/user` |
| `kratos_admin_http_enabled` | `false` | Admin 两接口 HTTP 灰度到 `moe-kratos` |
| `kratos_admin_base_url` | `http://127.0.0.1:19032` | 灰度目标（需 `make moe-kratos`） |

API→RPC 地址：`api/etc/super.yaml` 的 `SuperRpc.Endpoints`（本机 `127.0.0.1:8080`）；Docker 用 `MOE_SUPER_RPC_ENDPOINT=rpc:8080`。

---

## 5. 端口与客户端

| 端口 | 用途 | 谁访问 |
|------|------|--------|
| **8888** | HTTP REST | **Flutter**、`ApiService.baseUrl`、moe-admin、OAuth 回调 |
| **8080** | gRPC | **仅后端内部**（API→RPC）；不对公网；Flutter **不连** |

`make moe-social` = 1 进程、2 监听；**不改变** App 的 baseUrl。

### 并发说明（简要）

- 8080 在本机是 **gRPC 回环**，多请求由 gRPC/HTTP/2 多路复用，与跨容器调 `rpc:8080` **模型相同**。
- 更需关注：**MySQL 连接池**（单进程已合并为一次连库）、**试跑与 bot scheduler** 同时写库。
- 详见上文架构；无单独「进程内 8080 必然竞态」问题。

---

## 6. 当前 Hybrid 优缺点

### 优点

| 点 | 说明 |
|----|------|
| **可渐进迁移** | Moe 先落地，不阻断 Flutter / 全站发布 |
| **对外零改动** | 仍 `:8888` + `super.api` 路径与 JSON |
| **Moe 可测可维护** | 业务在 `biz/service`，不堆在巨型 logic |
| **双契约并存清晰** | Moe 新能力走 `moe.proto`；legacy 仍 `super.*` |
| **单进程开发体验** | `make moe-social` 省一个终端 |
| **可回退** | 关 `api_in_process` 即回到纯 RPC 转发 |

### 缺点

| 点 | 说明 |
|----|------|
| **两套生成链** | goctl（super）+ protoc（moe），`make gen` 步骤多 |
| **仍依赖 go-zero 运行时** | `rest` + `zrpc`，非纯 Kratos 传输 |
| **8888+8080** | 单进程仍两端口；本机回环多一跳 |
| **部署默认仍两二进制** | 与 `moe-social` 开发态不一致 |
| **两套 MoeAdmin 实例** | 单进程内 RPC 与 API 各一份对象（共用 DB） |
| **全仓未统一** | 非 Moe 模块仍 legacy，新人要记两套规则 |

---

## 7. 目录结构（精简）

```text
backend/
├── cmd/moe-social/              # 生产推荐：单进程 :8888 + :8080
├── cmd/moe-kratos/              # 纯 Kratos 试点 :19031/:19032
├── cmd/moe-platform/            # 观测 :19020/migration
├── config/config.yaml           # moe.* 开关（api/vip/user_in_process）
├── api/
│   ├── super.api                # HTTP 契约 SSOT（legacy，逐步按域拆）
│   ├── runserver/               # 装配 MoeGW / VipGW / UserGW
│   ├── moe/v1/moe.proto
│   ├── vip/v1/vip_read.proto
│   ├── moekratospilot/          # 试点 HTTP（:19032）
│   └── internal/
│       ├── moeadmingw/          # Moe Admin 网关
│       ├── vipadmingw/          # VIP 套餐网关
│       └── usergw/              # User 核心网关
├── rpc/
│   ├── super.proto              # gRPC SSOT（legacy）
│   └── runserver/
├── internal/
│   ├── biz/                     # admin/user/llm/ai/chat/post/… (~120+ .go)
│   ├── service/                 # 各域 app
│   ├── data/moedata/
│   ├── server/moegrpc/
│   └── platform/moewiring|moesocial|moekratos|moeconf/
└── scripts/
    ├── verify-moe-complete.sh
    ├── verify-domain-vip.sh
    ├── verify-domain-user.sh
    ├── verify-platform.sh
    └── verify-full-site-50.sh
```

---

## 8. 与「纯 Kratos」差异一览

| 维度 | 当前 Hybrid | 纯 Kratos（目标） |
|------|-------------|-------------------|
| 进程入口 | `moe-social` 或 api+rpc 两个 main | 单一 `kratos.App` |
| HTTP | go-zero `rest` + `super.api` | Kratos HTTP / grpc-gateway |
| gRPC | go-zero `zrpc` + `super.proto` | Kratos gRPC + 分域 `api/*/v1` |
| 配置 | yaml + viper | `conf.proto` + Wire（可选） |
| 生成 | goctl + protoc | 以 protoc 为主 |
| Moe / VIP / User / Admin / 社交 / AI | ✅ 多数 `biz/*` + 多网关 | ✅ 复用并扩展 |
| HTTP SuperRpc 残留 / FS-9 | ~8 文件；super 未删 | F110 + FS-8/9 |

---

## 9. 是否需要纯 Kratos 迁移？（决策）

### 9.1 建议结论（2026-05）

| 你的情况 | 建议 |
|----------|------|
| Moe/管理台/试跑已满足，要稳定上线 | **暂不全面纯 Kratos**；继续 Hybrid + `make moe-social` |
| 只想简化部署（一个二进制） | **先做部署改造**（`go build ./cmd/moe-social` + 单容器），**不必**先纯 Kratos |
| 团队要统一技术栈、长期只维护 proto | **可以规划纯 Kratos**，按域分期，**至少按月级** |
| 仅 Moe 想更「正宗」Kratos | **可做小试点**：Moe Admin HTTP 走 grpc-gateway，范围可控 |
| 资源紧、无专职后端架构时间 | **不要现在全仓迁** |

**一句话：Moe 域不必为了「纯」而立刻全仓迁；全仓纯 Kratos 是产品/工程决策，不是 Moe 迁移的必选项。**

### 9.2 什么时候「值得」做纯 Kratos？

- 确定 **2～3 个季度** 持续投入后端架构；
- 希望 **去掉 goctl 空壳 / super.api 4k 行** 的长期维护成本；
- 需要 **统一 conf、Wire、单端口网关** 等企业级规范；
- 新模块（新 App、新 BFF）愿 **只写 proto**，不再加 `super.api`。

### 9.3 什么时候「不值得 / 可延后」？

- 当前重点是 **功能、商业化、Flutter**；
- 线上 **双容器稳定**，无架构痛点；
- 团队对 go-zero 已熟悉，纯 Kratos 学习 + 迁移成本高；
- 仅因「想 100% Kratos」而无明确痛点（性能、部署、契约混乱未恶化）。

### 9.4 若做全站迁移，推荐路线

完整分阶段见 [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md)。

```text
FS-0～FS-3   平台 / VIP / User           ✅
FS-4         Admin 非 Moe                 ✅ F108
FS-5～FS-7   社交 / AI / LLM / Chat       ✅ ~95%+
F109         User 尾巴 + LLM 记忆读       ✅
F110         HTTP 零 SuperRpc             ← 当前
FS-8/9       域 proto + 退役 super        🔄 stub / deprecated
```

进度勾选：[kratos-migration-status.md](./kratos-migration-status.md) · 路线图：[kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md)。

每阶段独立验收；**任何阶段失败都可停在 Hybrid**。

### 9.5 决策对照表

| 目标 | 用 Hybrid 即可？ | 需要纯 Kratos？ |
|------|------------------|-----------------|
| Flutter 不调接口 | ✅ | ❌ |
| Moe 大脑/试跑/管理台 | ✅ | ❌ |
| 单进程本地开发 | ✅（moe-social） | ❌ |
| 单二进制线上 | ⚠️ 改部署即可 | 可选 |
| 只暴露 8888 | ❌ | ✅（gateway） |
| 去掉 goctl | ❌ | ✅ |
| 全域 biz 分层 | ❌ | ✅ |

---

## 10. 相关文档

| 文件 | 用途 |
|------|------|
| [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md) | 纪律与禁止项 |
| [kratos-migration-status.md](./kratos-migration-status.md) | **当前进度勾选（F109 · F ~98%）** |
| [kratos-migration-sprint-f100.md](./kratos-migration-sprint-f100.md) | F70→F109 路线图 |
| [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) | 全站 F 公式与域权重 |
| [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) | 纯 Kratos 试点（B 100%） |
| [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md) | 里程碑索引 |
| [docs/guidelines/Codex启动指南-后端.md](../guidelines/Codex启动指南-后端.md) | 日常命令 |
