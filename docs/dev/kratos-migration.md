# Kratos 混合架构说明（SSOT）

> **Hybrid Moe：100%** · **纯 Kratos 试点方案：100%** · **全站迁移 F：~22%** · **对外 HTTP：:8888**  
> 本文档描述 **Hybrid 生产架构**。全站迁移执行方案：[kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md)。  
> 试点方案：[kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) · 勾选：[kratos-migration-status.md](./kratos-migration-status.md)

---

## 1. 当前是什么架构？

| 名称 | 含义 |
|------|------|
| **Hybrid（混合）** | 业务按 Kratos 分层（`biz` / `service` / `data`），**启动与契约仍大量依赖 go-zero**（`super.api`、`super.proto`、`rest` + `zrpc`） |
| **不是纯 Kratos** | 尚未用 `kratos.App` 统一替代 go-zero 的 HTTP/gRPC 传输；未全面 `conf.proto` + Wire；未退役 `super.*` |
| **Moe 域（A）** | 分层 + `moe.proto` + `moegrpc` + `MoeGW` + 单进程 `moe-social` → **100%** |
| **纯 Kratos 试点方案（B）** | Phase 0～6 → **100%**；`:19031/:19032` **非对外** |
| **全站迁移（F）** | 各域下沉 `biz` + 退役 `super.*` → **~22%**（2026-05-27） |
| **工程就绪度（G）** | A+B+单二进制可构建+观测 → **~48%**（可上线 Hybrid，≠迁完） |

进度口径与域权重见 [kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义)。

```text
  对外（Flutter / 管理台 / 第三方）
           │  HTTP :8888  （super.api，REST JSON）
           ▼
  ┌────────────────────────────────────────────┐
  │  API（go-zero rest）                        │
  │  · 非 Moe：logic → SuperRpcClient            │
  │  · Moe Admin：moeadmingw（默认 in_process；可灰度 kratos_http）│
  └──────────────────┬─────────────────────────┘
                     │  gRPC 127.0.0.1:8080（本机或容器内网）
                     ▼
  ┌────────────────────────────────────────────┐
  │  RPC（zrpc）                                │
  │  · super.Super（legacy 全站）               │
  │  · moe.v1.MoeAdmin（moegrpc，新契约）       │
  └──────────────────┬─────────────────────────┘
                     ▼
           internal/service → biz → data → MySQL
```

**纯 Kratos 终态**（未做）：单 `kratos.App`、契约以 `api/*/v1/*.proto` 为主、逐步去掉 goctl 双入口。见 [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md)。

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

**Hybrid（生产路径）**

```bash
make verify-moe-complete  # 推荐：一键
# 或分步：verify-moe-migration / verify-moe-grpc / verify-moe-gateway
```

**纯 Kratos 试点（并行，方案 100%）**

```bash
make verify-kratos-100    # 试点方案 100% + Hybrid 回归
make build-moe-social     # 生产单二进制 :8888+:8080
make verify-kratos-80     # Phase 0～4
make verify-kratos-60     # Phase 0～3
make verify-kratos-50     # Phase 0～2
make moe-kratos           # 试点进程 :19031 gRPC + :19032 HTTP
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
| **Moe** | 改 `api/moe/v1/moe.proto`（gRPC）；HTTP 管理台仍 `super.api` | `internal/biz/moe` → `service/moe`；Admin HTTP 经 `moeadmingw` |
| **User/VIP/…** | 仍 `super.api` / `super.proto` | 仍 `api|rpc/internal/logic`（legacy） |

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
| `kratos_admin_http_enabled` | `false` | Phase 3：Admin 两接口 HTTP 转发到 `moe-kratos` |
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
├── cmd/moe-social/           # 推荐：Hybrid 单进程
├── cmd/moe-kratos/           # 纯 Kratos 试点（Wire，:1903x）
├── internal/conf/moe/v1/     # pilot.proto Bootstrap SSOT
├── internal/platform/moeconf/
├── internal/platform/moekratos/  # wire_gen.go
├── cmd/moe-platform/         # 观测 :19020
├── api/
│   ├── super.api             # HTTP SSOT（全站）
│   ├── moekratospilot/       # 试点 Admin HTTP（:19032）
│   ├── runserver/            # API 启动
│   ├── moe/v1/moe.proto      # Moe gRPC SSOT
│   └── internal/moeadmingw/  # Admin 网关（in_process / kratos_http / …）
├── rpc/
│   ├── super.proto           # gRPC SSOT（全站）
│   └── runserver/            # RPC 启动
├── internal/
│   ├── biz/moe/              # 业务
│   ├── service/moe/
│   ├── server/moegrpc/       # moe.v1 服务实现
│   └── platform/moewiring|moesocial/
└── scripts/verify-moe-*.sh
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
| Moe 业务层 | ✅ 已有 | ✅ 复用 |
| 全站业务层 | ❌ 多在 logic | 需按域下沉 biz |

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

**已启动 FS-0（准备）**；完整分阶段见 [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md)。

```text
FS-0  准备（进度 SSOT、域清单）          ← 当前
FS-1  平台与契约基座
FS-2  VIP 全量（建议首个业务域）
FS-3  User 核心
FS-4  Admin 非 Moe
FS-5  社交与内容
FS-6  AI / LLM
FS-7  实时通道
FS-8  退役 super.api / super.proto
```

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
| [kratos-full-site-migration-plan.md](./kratos-full-site-migration-plan.md) | **全站迁移方案（F ~22%）** |
| [kratos-pure-migration-plan.md](./kratos-pure-migration-plan.md) | 纯 Kratos 试点（B 100%） |
| [kratos-phase3-roadmap.md](./kratos-phase3-roadmap.md) | 里程碑索引 |
| [kratos-migration-status.md](./kratos-migration-status.md) | 勾选 |
| [docs/guidelines/Codex启动指南-后端.md](../guidelines/Codex启动指南-后端.md) | 日常命令 |
