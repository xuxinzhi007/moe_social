# Kratos 迁移 — 状态板（Current / Next）

> **最后更新：2026-05-28**（P5-D 生产二进制零 go-zero 依赖）  
> **读这个**：本文 = **当前状态 + 下一步** 快照

---

## 当前状态（Current）

| 阶段 | 状态 | 说明 |
|------|------|------|
| **P0–P3（生产）** | ✅ **100%** | compat 263 · api logic 0 · `/migration percent=100` |
| **P4（理想目录）** | ✅ **~100%** | data 20/21 域 · 独立 gRPC **12/12** |
| **P5-A（Super 运行时）** | ✅ **100%** | 单进程不注册 Super · API 无 zrpc 回环 · AppAdapter |
| **P5-B（logic + 契约）** | ✅ **100%** | `rpc/internal/logic` **0** · `superserver` 已删 · `moe.proto` 无 `service Super` |
| **P5-C（gateway Super）** | ✅ **100%** | `api/*gw` 无 `SuperClient` · 分体 `grpcclient` dial MoeAdmin |
| **P5-D（零 go-zero 生产）** | ✅ **100%** | `go list -deps ./cmd/moe-social` 无 `go-zero` · hybrid 回滚 `-tags hybrid` |

### P5 进度

| 轨道 | 状态 | baseline |
|------|------|----------|
| **P5-A 运行时** | ✅ | `super_grpc_retired` + `single_process` |
| **P5-B rpc logic 清库** | ✅ | **209 → 0** 文件 |
| **P5-C gateway** | ✅ | 23× `*gw` 去 `moe.SuperClient`；分体 dial `MoeAdminClient` |
| **P5-D 生产零 go-zero** | ✅ | 默认构建；legacy 在 `//go:build hybrid` |

详见 [kratos-p5-super-retirement.md](./kratos-p5-super-retirement.md)

### 独立 gRPC（12）

`Landing` · `Checkin` · `Achievement` · `PostService` · `GiftService` · `MoeAdmin` · `UserService` · `CommentService` · `Community` · `PrivateMessageService` · `NotifyService` · `VipService`

### 进度百分比（汇报用）

| 目标 | 完成度 |
|------|--------|
| 生产 Kratos（`make moe-social`） | **100%** |
| P5 Super 退役 + 生产零 go-zero | **100%** |
| 仓库删除全部 go-zero 源文件 | **未做**（hybrid 回滚保留） |

### 文档索引（P5）

| 文档 | 用途 |
|------|------|
| [kratos-p5-super-retirement.md](./kratos-p5-super-retirement.md) | P5-A/B/C |
| [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) | P5-D 验收 |
| [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) | 分体部署 |
| [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md) | 域 gRPC 冒烟 |

### 验收

```bash
cd backend && go build ./api ./rpc ./cmd/moe-social   # ✅
go test ./internal/platform/kratosprogress/... -count=1  # ✅
go list -deps ./cmd/moe-social | grep go-zero          # 应无输出（P5-D）
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {percent, p5: .p5_super_runtime_pct, rpc_left: .rpc_logic_files_left}'
```

---

## 下一步（Next）

| 优先级 | 任务 | 文档/脚本 |
|--------|------|-----------|
| 1 | 本地 grpc 冒烟 notify/chat/vip | [grpc-smoke-notify-chat-vip.md](./grpc-smoke-notify-chat-vip.md) |
| 2 | 分体 api/rpc 联调（若需要） | [kratos-p5-split-deploy.md](./kratos-p5-split-deploy.md) |
| 3 | 可选：`go.mod` 移除 go-zero | [kratos-p5d-zero-gozero.md](./kratos-p5d-zero-gozero.md) §可选 |

---

## 自检

```bash
cd backend && go build ./...
make audit-logic-orphans          # api logic none
go list -deps ./cmd/moe-social | grep go-zero   # P5-D：无输出
curl -s http://127.0.0.1:8888/migration | jq '.breakdown | {p5: .p5_super_runtime_pct, rpc: .rpc_logic_files_left}'
```
