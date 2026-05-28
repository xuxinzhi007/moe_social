# Kratos P4 — 架构洁癖（P3 之后）



> **更新：2026-05-28**  

> **前置**：P3 logic 清库 ✅ · `make check` ✅ · `/migration percent=100`



P3 完成「生产路径 Kratos 化 + logic 退役」。P4 面向官方分层洁癖与契约收敛。



---



## 轨道总览



| 轨道 | 目标 | 状态 | 说明 |

|------|------|------|------|

| **P4-D** | `internal/data` repo 层 | ✅ **~95%** | 20/21 域 · voice 除外 |

| **P4-C** | 契约收敛 FS-8/9 | ✅ **100%** | 12 独立 gRPC（Super 已 P5 退役） |

| **P4-H** | go-zero Hybrid 壳 | ✅ build tag | 默认 `!hybrid` 空 stub；回滚 `-tags hybrid` |

| **P4-B** | bridge 永久保留 | ✅ | `/swagger`、`/swagger/doc.json`（2 条） |



---



## P4-D · data 层



**原则**：GORM 从 biz 抽到 `internal/data/<domain>/`；biz 通过小接口依赖 repo。



| 批次 | 域 | 状态 |

|------|-----|------|

| D1 | landing（反馈 CRUD） | ✅ `internal/data/landing/` |

| D2 | checkin、achievement | ✅ `internal/data/checkin/` · `internal/data/achievement/` |

| D3 | user | ✅ `internal/data/user/` |

| D4 | post · comment · community · gift · behavior · notify · vip · chat | ✅ |

| D5 | admin（核心） | ✅（insights_ops 待拆） |

| D6 | ai · llm · moe | ✅ `internal/data/{ai,llm,moe}/` |

| D7 | admin insights_ops | ✅ AdminStore |

| D8 | voice | ⬜ 无 DB（可选） |



验收：



```bash

cd backend

go test ./internal/data/... ./internal/biz/checkin/... ./internal/biz/achievement/... ./internal/biz/user/... -count=1

go build ./cmd/moe-social

```



详见 [internal/data/README.md](../../backend/internal/data/README.md)。



---



## P4-C · 契约（FS-8/9 余量）



**已完成（结构）**：



- HTTP：`api/defs/*.api` 分片（FS-8）

- RPC：`rpc/defs/services/*.rpcfrag` → `rpc/moe.proto`（FS-8b/9）

- Go import：`backend/rpc/pb/moe`；`pb/super` 为 FS-9b 垫片



**已完成（运行时切域）**：

- **`landing.v1.Landing`** · **`checkin.v1.Checkin`** · **`achievement.v1.Achievement`**
- **`post.v1.PostService`** · **`gift.v1.GiftService`** · **`moe.v1.MoeAdmin`**
- **`user.v1.UserService`** · **`comment.v1.CommentService`** · **`community.v1.Community`**
- **`chat.v1.PrivateMessageService`** · **`notify.v1.NotifyService`** · **`vip.v1.VipService`**
- 注册：`rpc/runserver/kratos.go`（与 `Super` 并存，Super 向后兼容）

**未完成（可选）**：

- voice WS 边界文档 · Super 逐步退役（产品节奏）

- HTTP 新能力 **仅** `api/<domain>/v1/*.proto`（纪律见 [new-api-kratos.md](./new-api-kratos.md)）



命令：



```bash

cd backend

make gen-moe-proto          # api/**/v1/*.proto → *.pb.go

make fs8-split-super-proto  # 慎用：重切 rpc/defs

make gen-rpc && go build ./rpc

```



---



## P4-H · go-zero 壳



| 路径 | 默认构建 | Hybrid 回滚 (`-tags hybrid`) |

|------|----------|------------------------------|

| `api/internal/handler/routes.go` | **不编译**（`//go:build hybrid`） | `RegisterHandlers` 全量路由 |

| `api/internal/handler/routes_stub.go` | 空 `RegisterHandlers` | **不编译** |

| `api/internal/handler/*/` | 默认不拉入依赖链 | 经 routes.go import |

| `api/internal/logic/` | **空**（`.gitkeep`） | gen-api 后 `prune-api-logic-retired.sh` |



`make gen-api` 后自动跑 `scripts/gen/tag-hybrid-routes.sh` 补 build tag。



Hybrid 编译示例：



```bash

cd backend

go build -tags hybrid -o bin/moe-social-hybrid ./cmd/moe-social

```



说明：[api/internal/handler/README.md](../../backend/api/internal/handler/README.md)



---



## P4 验收（阶段性）



```bash

cd backend && make check

make audit-logic-orphans          # none

test -z "$(find api/internal/logic -name '*.go' ! -name '.gitkeep' 2>/dev/null | head -1)"

curl -s http://127.0.0.1:8888/migration | jq '.percent'   # 100（logic=0）

```



**P4 全部完成**（理想目录）= D 层域全覆盖 + 主要域 Super 切域 gRPC + 可选移除 Hybrid 壳。



---



## 相关文档



| 文档 | 用途 |

|------|------|

| [kratos-migration-status.md](./kratos-migration-status.md) | 状态板 |

| [kratos-architecture-complete.md](./kratos-architecture-complete.md) | DoD |

| [goctl-generation-hygiene.md](./goctl-generation-hygiene.md) | gen-api 纪律 |

| [kratos-p4-sprint-80.md](./kratos-p4-sprint-80.md) | Sprint 80 并行分工与进度 |

| [new-api-kratos.md](./new-api-kratos.md) | 新接口契约 SSOT |

