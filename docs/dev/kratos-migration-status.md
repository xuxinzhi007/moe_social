# Kratos 迁移 — 进度清单

> **更新：2026-05-27**  
> **当前阶段：FS-3b**（User 扩展）  
> **全站迁移 F：~60%** · **工程就绪度 G：~55%**  
> 口径：[kratos-full-site-migration-plan.md §1](./kratos-full-site-migration-plan.md#1-进度口径必读避免歧义) · 架构 SSOT：[kratos-migration.md](./kratos-migration.md)

---

## 总览

| 曲线 | 进度 | 验收 |
|------|------|------|
| A · Hybrid Moe | **100%** | `make verify-moe-complete` |
| B · 纯 Kratos 试点方案 | **100%** | `make verify-kratos-100` |
| **F · 全站迁移** | **~60%** | `make verify-full-site-50` |
| G · 工程现代化就绪 | **~55%** | 可上线 Hybrid；≠ 全站迁完 |

---

## 当前生产架构（摘要）

| 组件 | 路由 | 说明 |
|------|------|------|
| `moeadmingw` | `in_process` | Moe Admin → `biz/moe` |
| `vipadmingw` | `in_process` | VIP 套餐 → `biz/vip` |
| `usergw` | `in_process` | User 核心 → `biz/user` |
| 其余 HTTP | `logic` → `:8080` | legacy `super.Super` |
| 对外端口 | **:8888** | Flutter / moe-admin 不变 |

配置：`config.yaml` → `moe.api_in_process` / `vip_api_in_process` / `user_api_in_process`（默认 `true`）。

---

## 已完成 ✅

### Hybrid Moe（A）

- [x] `make verify-moe-complete` / `make moe-social`
- [x] `internal/biz|service|data/moe`
- [x] `moeadmingw` + `moe.proto` + `moegrpc`

### 纯 Kratos 试点（B）

- [x] Phase 0～6（`moe-kratos`、Wire、VIP 只读 @ :19032）
- [x] `make build-moe-social` → `bin/moe-social`

### 全站迁移 Phase FS

- [x] **FS-0** 进度 SSOT、域清单、方案文档
- [x] **FS-2** VIP 套餐域 — `make verify-domain-vip`
- [x] **FS-3a** User 核心 — `make verify-domain-user`
- [x] **FS-3c** 小域快迁 — `make verify-domain-misc`（landing / behavior / appcfg）
- [x] **FS-1** 部分 — `make verify-platform`（单二进制）

---

## 进行中 🔄

- [ ] **FS-3b** User 扩展余量（VIP 订单/记忆/OAuth）→ User 域 100%
- [x] **FS-3b** User 关注 → `biz/user/follow` + `usergw`
- [x] **FS-3b** User 好友 7 接口 → `biz/user/friend` + `usergw`
- [ ] **FS-1** 余量（conf 扩展、compose 默认单容器）

---

## 待办 ⬜

- [ ] FS-4 Admin 非 Moe
- [ ] FS-5 社交与内容
- [ ] FS-6 AI / LLM
- [ ] FS-7 Chat / Voice
- [ ] FS-8 退役 `super.api` / `super.proto`

---

## 各域域内进度

| 域 | 域内 % | 网关 / biz | 阶段 |
|----|--------|------------|------|
| Moe | 100% | `moeadmingw` | ✅ |
| VIP 套餐 | 100% | `vipadmingw` | ✅ FS-2 |
| User | ~95% | `usergw`（核心+关注+好友） | FS-3a ✅ / FS-3b 大部分 ✅ |
| Admin（非 Moe） | 0% | — | FS-4 |
| 其它（小域） | 100% | `biz/landing` 等 | ✅ FS-3c |
| 社交 / AI / 实时 | 0% | — | FS-5～7 |

---

## 日常命令

```bash
cd backend
make moe-social               # 开发 / 生产 HTTP :8888
make verify-full-site-50      # F≈60% 组合验收
make verify-moe-complete      # A
make verify-domain-vip        # FS-2
make verify-domain-user       # FS-3a
make verify-domain-misc       # FS-3c
make verify-platform
make verify-kratos-100        # B
make build-moe-social
```
