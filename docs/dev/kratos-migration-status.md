# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-28**（P4 Sprint 100 · 收尾）  
> **读这个**：本文 = **当前状态 + 下一步** 快照

---

## 当前状态（Current）

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0–P3（生产）** | ✅ **100%** | compat 263 · logic 0 · `/migration percent=100` |
| **P4（理想目录）** | ✅ **~100%** | data 20/21 域 · 独立 gRPC **12/12** |

### P4 进度公式

`P4% ≈ 60% × (20/21) + 40% × (12/12)` → **~97%**（voice 无 DB，不计入待迁域）

详见 [kratos-p4-sprint-80.md](./kratos-p4-sprint-80.md)

### P4 轨道

| 轨道 | 状态 |
|------|------|
| **P4-D data** | 全域 ✅（含 insights_ops · ai/llm/moe 余量）· voice 可选 |
| **P4-C gRPC** | **12/12** 独立服务 + Super 兼容 |
| **P4-H Hybrid** | build tag ✅ |
| **P4-B swagger** | 2 条 ✅ |

### 独立 gRPC（12）

`Landing` · `Checkin` · `Achievement` · `PostService` · `GiftService` · `MoeAdmin` · `UserService` · `CommentService` · `Community` · **`PrivateMessageService`** · **`NotifyService`** · **`VipService`**

### 验收

```bash
cd backend && go build ./api ./rpc ./cmd/moe-social   # ✅
go test ./internal/biz/llm/... ./internal/biz/user/... ./internal/biz/admin/... ./internal/biz/moe/... -count=1  # ✅
```

---

## 下一步（Next）

1. **可选**：voice WS 边界文档化（无 DB，不阻塞 P4）
2. admin/service 余量 `s.db` → `s.store`（非 RPC 热路径）
3. grpcurl 冒烟：notify.v1 / chat.v1 / vip.v1

---

## 自检

```bash
cd backend && go build ./...
make audit-logic-orphans          # none
curl -s http://127.0.0.1:8888/migration | jq '.percent'  # 100（P3）
```
