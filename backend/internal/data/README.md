# internal/data — 持久化层（P4）

> **状态**：P4 Sprint 100 · **20/21 域**（voice 无 DB 除外）  
> **SSOT**：[docs/dev/kratos-migration-status.md](../../docs/dev/kratos-migration-status.md) · P4 数据层见 [kratos-directory-ssot.md](../../docs/dev/kratos-directory-ssot.md)

## 已迁入

```text
landing/  checkin/  achievement/  user/
post/     comment/  community/    gift/
behavior/ notify/   vip/          chat/
admin/    moedata/（runlog）
ai/       llm/      moe/（含 pipeline/tools）
```

## 可选 / 未迁

`voice/` — 信令 WS，无 GORM 持久化（见 voice-ws-boundary 文档）

## 接入模式

1. `internal/biz/<domain>/store.go` — 接口
2. `internal/data/<domain>/store.go` — GORM
3. `internal/service/<domain>/<domain>.go` — 注入（大域按 `{domain}_{feature}.go` 拆分）
4. 域 Store：`internal/data/<domain>/`（经 `wire_svc` 注入 App）

## Store getters（RPC）

`UserStore` · `AdminStore` · `NotifyStore` · `PostStore` · `CommentStore` · `CommunityStore` · `GiftStore` · `VipStore` · `ChatStore` · `BehaviorStore` · `MemoryStore` · `AiStore` · `MoeStore`

## 验收

```bash
cd backend && go build ./cmd/moe-social
go test ./internal/biz/llm/... ./internal/biz/user/... ./internal/biz/admin/... ./internal/biz/moe/... -count=1
```
