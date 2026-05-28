# 纯 Kratos 迁移方案（试点 B · 已完成）

> **当前进度：100%**（Phase 0～6 已完成）  
> **下一阶段的执行手册**（PK-0～PK-5）：**[kratos-pure-rollout.md](./kratos-pure-rollout.md)** ← 开工看这个  
> **对外 HTTP 端口：始终 :8888**（`make moe-social`）  
> **验收**：`make verify-kratos-100` · 基线 `make verify-kratos-rollout-pk0`

---

## 0. 端口说明（必读）

| 端口 | 用途 | 谁连接 |
|------|------|--------|
| **8888** | HTTP REST | **Flutter、moe-admin、第三方（生产对外）** |
| **8080** | gRPC | 仅后端内部（API→RPC） |
| 19031 / 19032 | 纯 Kratos **开发试点** | 本机验证，**非生产对外** |

`:19032` 上的 Admin 路径是为验证契约与 biz 分层；**客户端不要改连 19032**。

---

## 1. 进度总览

| 阶段 | 权重 | 状态 | 交付 |
|------|------|------|------|
| 0 试点进程 | 10% | ✅ | `cmd/moe-kratos` |
| 1 纯 Kratos gRPC | 15% | ✅ | reflection + grpcurl |
| 2 Admin HTTP 兼容 | 25% | ✅ | 试点同路径 Moe Admin |
| 3 切流灰度 | 10% | ✅ | `kratos_admin_http_enabled` |
| 4 conf + Wire | 20% | ✅ | `moe.conf.v1.Bootstrap` |
| 5 VIP 只读域 | 10% | ✅ | `biz/vip` + `/api/admin/vip/plans` @ 试点 |
| 6 生产单二进制 | 10% | ✅ | `make build-moe-social` → `bin/moe-social` |
| **合计** | **100%** | **100%** | |

**说明**：「100%」= 本方案里程碑完成；**全仓**仍有多数字段在 `super.api` / legacy logic（非 Moe/VIP 试点范围）。

---

## 2. 验收命令（SSOT）

```bash
cd backend

# 纯 Kratos 100% + Hybrid Moe 回归
make verify-kratos-100

# 仅 Hybrid（你已跑通）
make verify-moe-complete

# 生产推荐单二进制
make build-moe-social
./bin/moe-social -f-api api/etc/moe.yaml -f-rpc rpc/etc/moe.yaml
```

### 日常开发

```bash
make moe-social          # 对外 :8888（推荐）
make moe-kratos          # 试点 :19031/:19032（可选）
```

### 生成

```bash
make gen-moe-conf        # pilot.proto
make gen-moe-proto       # moe.proto + vip_read.proto
```

---

## 3. 生产架构（100%）

```text
  Flutter / moe-admin / 浏览器
           │
           │  HTTP :8888  （不变）
           ▼
  bin/moe-social  或  make moe-social
           ├─ go-zero rest :8888  (super.api 全站路由)
           ├─ zrpc :8080          (super + moe.v1)
           └─ MoeGW → in_process / kratos_http(灰度)

  开发试点（并行，不对公网）:
  make moe-kratos → :19032 HTTP / :19031 gRPC
```

---

## 4. 配置

```yaml
moe:
  production:
    unified_entry: moe-social
    external_http_port: "8888"
    internal_grpc_port: "8080"
  pilot:
    vip_admin_read_enabled: true
  kratos_admin_http_enabled: false   # 灰度时再 true
```

---

## 5. Phase 5～6 代码索引

| 项 | 路径 |
|----|------|
| VIP biz | `internal/biz/vip/plans.go` |
| VIP 试点 HTTP | `api/moekratospilot/vip_compat.go` |
| VIP proto | `api/vip/v1/vip_read.proto` |
| 生产二进制 | `make build-moe-social` → `bin/moe-social` |

---

## 6. 后续：全站迁移（Phase 4+）

本方案 **B=100%** 不等于全站迁完。下一执行文档：

**[kratos-migration-status.md](./kratos-migration-status.md)**（全站 **F ~98%**，**F109 完成**）

- FS-2：VIP 全量（建议首个业务域）
- FS-3～FS-8：User、Admin、社交、AI、实时、退役 `super.*`

---

## 7. 相关文档

| 文件 | 用途 |
|------|------|
| [kratos-migration.md](./kratos-migration.md) | Hybrid SSOT |
| [kratos-migration-status.md](./kratos-migration-status.md) | 勾选 |
