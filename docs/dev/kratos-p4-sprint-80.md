# P4 Sprint → 80%（并行分工）

> **更新：2026-05-28** · Sprint 100 收尾  
> **公式**：`P4% = 60% × (data 域/21) + 40% × (独立 gRPC/12)`

## Sprint 100 结果

| Lane | 范围 | 状态 |
|------|------|------|
| **insights_ops** | 全量 → `AdminStore` | ✅ |
| **moe 余量** | pipeline/tools_exec → `MoeStore` | ✅ |
| **gRPC** | chat · notify · vip 独立服务 | ✅ |
| **RPC** | RecordAuditLog → AdminStore | ✅ |

## 当前进度

| 指标 | Sprint 80+ | Sprint 100 |
|------|------------|------------|
| **data 域** | 17/21 | **20/21** |
| **独立 gRPC** | 9/12 | **12/12** |
| **P4 综合** | ~79% | **~97%（≈100%）** |

## 剩余（可选）

| 项 | 说明 |
|----|------|
| voice | WS 边界，无 DB |
| admin app 余量 | 部分 gift/achievement 仍 `s.db`（非阻塞） |

## 工具

```bash
cd backend
go run ./scripts/tools/rpc-logic-store-fix   # logic 层 Store 批量适配
go build ./...
go test ./internal/biz/user/... ./internal/platform/kratosprogress/... -count=1
```

## 实现模式（SSOT）

见 [kratos-p4-post-migration.md](./kratos-p4-post-migration.md) · [internal/data/README.md](../../backend/internal/data/README.md)
