# 纯 Kratos 目录布局（渐进对齐 core-platform）

> **状态**：PK-9 起生产默认 `moe.kratos_pure_enabled: true`  
> **原则**：业务仍在 `internal/biz`；传输与注册逐步迁入 Kratos 结构，**不**一次性删 `api/internal/handler`。

---

## 目标结构（与 co 对照）

```text
backend/
  api/<domain>/v1/*.proto          # 契约 SSOT（长期）
  internal/
    biz/<domain>/                  # 业务（不变）
    service/<domain>/              # 适配（不变）
    server/
      moekratoshttp/               # /health · /migration
  api/moekratospilot/              # ✅ Kratos HTTP 生产注册（RegisterProductionHTTP）
    server/
      moegrpc/                     # Kratos gRPC MoeAdmin
    platform/
      moesocial/                   # moe-social 编排（纯/混合）
  api/internal/handler/            # goctl 生成（Hybrid 回滚用，逐步只读）
```

---

## 当前生产路径（`kratos_pure_enabled: true`）

```text
make moe-social
  → kratos.App
      transport/http  :8888   moekratospilot.RegisterProductionHTTP
      transport/grpc  :8080   wrapZRPC（Super + MoeAdmin）
  → 无 go-zero rest 对外监听
```

---

## 渐进调整计划

| 阶段 | 动作 | 状态 |
|------|------|------|
| 1 | `moekratospilot.RegisterProductionHTTP` 统一注册 | ✅ |
| 2 | 267 路由经 `moekratospilot` 桥接 handler | ✅ |
| 3 | 域 handler 逐步迁 `internal/service` + proto HTTP | 按需 |
| 4 | 退役 `api/internal/handler` 生成 | PK-10+ |
| 5 | `pb/super` 包名 FS-9b | **phase 1 ✅**（`pb/moe` + `pb/super/shim_gen.go`） |

---

## 配置

```yaml
moe:
  kratos_pure_enabled: true    # rollout_percent=100；percent=完整纯 Kratos 实现度
  kratos_pure_enabled: false   # 回滚 Hybrid go-zero HTTP
```

---

## 相关命令

```bash
make gen-api
make gen-moekratospilot-get
make verify-kratos-rollout-100
make verify-kratos-rollout-regression
```
