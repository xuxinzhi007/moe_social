# 记忆子系统模块地图

通用「记忆文本库」架构的目录约定与迁移计划。产品级 SSOT 见 [用户记忆系统-OpenClaw式演进设计.md](../用户记忆系统-OpenClaw式演进设计.md)；本次迭代变更清单见 [记忆系统-2026-05-20-变更整理.md](../记忆系统-2026-05-20-变更整理.md)。

**文档导航**：[docs/index.html](../../index.html) · **监控台**：[memory-system-dashboard.html](../memory-system-dashboard.html)

## 为什么要单独目录？

- **规则只写一遍**：过滤、检索、混合打分、画像聚合在 `backend/pkg/memory`，避免 API/RPC/未来 Worker 各抄一份。
- **跨端一致**：Flutter `lib/memory` 与后端 API 契约对齐，其他客户端可复用同一 SDK 形状。
- **可拆服务**：日后可把 `pkg/memory` + Store 实现抽成独立 `memory-service`，主 API 只保留 HTTP 网关。

## 目录结构

```
backend/pkg/memory/          # L1 域逻辑（Go，无 HTTP）
  search.go hybrid.go        # 关键词 + 混合检索
  embed/                     # Ollama / OpenAI 兼容 embedding 链
  bootstrap.go daily.go      # OpenClaw 双层读、日记、flush 辅助
backend/api/.../user/        # L2 HTTP：search / reindex / display
backend/rpc/.../             # L2 RPC + GORM + 向量表
lib/memory/                  # L2 Flutter SDK 骨架
lib/services/ai_memory_*.dart # 编排、工具、写入（存量主路径）
docs/dev/memory/             # 本说明
```

## 分层职责

| 层 | 包/目录 | 职责 |
|----|---------|------|
| L1 | `pkg/memory` | `Record`、`SearchFacing`、`HybridSearch`、`BuildProfiles`、`Store` |
| L1 | `pkg/memory/embed` | 多提供方 embedding 链（Ollama → 中转） |
| L2 | `api/internal/logic/user` | JWT、`HybridSearchUserFacingMemories`、`reindex` |
| L2 | `rpc/internal/logic` | DB、画像缓存、向量 upsert/rebuild |
| L2 | `lib/memory` | `MemoryHttpClient`、`MemoryOrchestrator` 抽象 |
| L3 | AI 聊天 / 设置页 | 消费 L2，不直接拼 SQL |

## API 速查（L1 对外）

| 方法 | 路径 |
|------|------|
| GET | `/api/user/:id/memories/search?q=&limit=` |
| POST | `/api/user/:id/memories/reindex` |
| GET | `/api/user/:id/memories/display` |
| POST/DELETE | `/api/user/:id/memories` |
| POST/GET | `/api/user/:id/devices/sync`、`/devices` |

## 其他服务接入 checklist

1. 引用 `backend/pkg/memory`（同 module `backend`）。
2. 实现 `memory.Store`（或走现有 RPC）。
3. 读：`FacingRecords` → `HybridSearch` / `SearchFacing`；写：业务规则后 `Upsert`。
4. 设备信息走 `/devices`，**禁止**写入 `user_memories`。
5. 向量：RPC `RebuildUserMemoryEmbeddings` 或依赖 upsert 后异步索引。

## 开源对标

OpenClaw / SillyTavern 调研与演进优先级：  
[../记忆系统-开源对标调研.md](../记忆系统-开源对标调研.md)

## 迁移进度

| 项 | 状态 |
|----|------|
| `pkg/memory` 检索 / 过滤 / 画像 | ✅ |
| `pkg/memory` 混合检索 + embed 链 | ✅ |
| 图谱 `user_memory_relations` + graph expand | ✅ |
| MMR rerank | ✅ |
| API search → `HybridSearchUserFacingMemories` | ✅ |
| `user_memory_embeddings` + RPC 向量 CRUD | ✅ |
| 设备表 `user_devices` 与记忆分离 | ✅ |
| OpenClaw 双层读 + `pre_compact_flush` | ✅ |
| RPC 画像重建委托 `pkg/memory` | ✅ |
| `memory_display` 迁入 pkg | ⬜ |
| Flutter 文件迁入 `lib/memory` | 🔄 骨架 |
| 独立 memory-service | ⬜ 可选 |
| Chat RAG（会话消息向量） | ⬜ Phase 3 |
