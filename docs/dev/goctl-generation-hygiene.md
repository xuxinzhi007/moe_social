# goctl 生成与空壳冲突说明

> **更新：2026-05-27** · 架构：[kratos-migration.md](./kratos-migration.md)

## 问题是什么？

`make gen-api` / `make gen-rpc` 会为每个 `@handler` / RPC 方法生成独立 `*logic.go`。  
本仓库部分接口已**合并**到单个 `*_logic.go` 或迁到 `internal/biz` + `*gw`，goctl 可能再生成空壳 → `redeclared` / `not enough return values`。

## 当前做法

```bash
cd backend
make gen-api    # 或 make gen-rpc / make gen-all
# 自动执行 scripts/gen/prune-*-logic-shells.sh
make check
```

- 孤儿清单：`backend/scripts/goctl-orphan-stubs.txt`、`goctl-rpc-orphan-stubs.txt`
- Moe Admin：`make gen-moe-admin`

## 新接口（Kratos 纪律）

**不要**为全新能力扩 `api/defs` → 见 [new-api-kratos.md](./new-api-kratos.md)（域 proto + `internal/service`）。

存量维护仍可用 `make gen-api` + `api/internal/logic`。

## 日常 `make gen`

**不会**跑 goctl api/rpc，**不会**覆盖已有 logic 实现；只更新域 `*.pb.go` 与 `api/moehttp/routes_*_gen.go`。
