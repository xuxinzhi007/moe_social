# pkg/memory — 通用记忆域（L1 核心）

与 `api` / `rpc` / 具体 ORM **解耦**，供本仓库与未来独立服务复用。

## 目录职责

| 文件 | 职责 |
|------|------|
| `types.go` | `Record`、`DisplayItem`、`ProfileSummary` |
| `filter.go` | 技术项过滤、噪声 value |
| `search.go` | 关键词 + 新近度检索（**SSOT**） |
| `profile.go` | 按 `memory_type` 聚合画像 |
| `labels.go` | 展示分类 / 标题 |
| `contracts.go` | `Store` / `Searcher` / `ProfileCache` 接口 |
| `adapter.go` | RPC `super.UserMemory` ↔ `Record` |

## 分层

```
L1  pkg/memory          ← 本目录（纯逻辑 + 接口）
L2  api/internal/...   ← HTTP 适配、鉴权
L2  rpc/internal/...   ← GORM Store 实现（进行中）
L3  lib/memory/        ← Flutter 客户端 SDK 骨架
```

## 其他服务如何接入

1. 实现 `memory.Store`（PostgreSQL / 其他库）。
2. 列表 → `FacingRecords` → `SearchFacing` / `BuildProfiles`。
3. **不要**在业务里复制 `device_info` 过滤或 search 打分规则。

## 迁移状态

- [x] 检索、过滤、画像聚合迁入本包
- [x] `memory_search` API 经 adapter 调用本包
- [x] RPC 画像重建委托 `BuildProfiles`
- [ ] Phase 2：`HybridSearcher`（向量 + BM25，见对标调研）
- [ ] `memory_display` 展示逻辑迁入本包
- [ ] 独立 `memory-service` 二进制（可选）

设计总览：`docs/dev/用户记忆系统-OpenClaw式演进设计.md`  
模块地图：`docs/dev/memory/README.md`
