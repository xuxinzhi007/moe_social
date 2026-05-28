# Backend 布局说明（PK-13 后）

## 你怎么跑

```bash
make moe-social    # 单进程：Kratos HTTP :8888 + Kratos gRPC :8080
```

配置 SSOT：`config/config.yaml`（`-f`，可省略）。

## 为什么还有 `api/` 和 `rpc/`？

| 目录 | 角色 | 是否单独部署 |
|------|------|----------------|
| **`api/`** | HTTP 契约（`moe.api` / `defs`）、goctl handler/logic、`*gw` | ❌ 否 |
| **`rpc/`** | gRPC 契约（`moe.proto`）、Super/MoeAdmin logic | ❌ 否 |
| **`internal/biz/`** | 业务 SSOT | 进程内 |
| **`internal/service/`** | Kratos 薄 service（试点域） | 进程内 |
| **`internal/platform/moesocial/`** | 单进程启动编排 | — |
| **`config/`** | 运行时配置 SSOT | — |

**一个 OS 进程** 同时装配 API `ServiceContext` 与 RPC `ServiceContext`；对外只暴露 **8888 + 8080**。

```text
Client → :8888  Kratos HTTP (api/moehttp) → api/logic → *gw → biz
              ↘ :8080  Kratos gRPC → rpc/server → rpc/logic → biz
```

`api/etc/moe.yaml`、`rpc/etc/moe.yaml` 是 **goctl 结构片段**；端口与开关以 `config/config.yaml` 的 `runtime` / `moe` 为准。

## 后续整理（非本 PR）

- 域逻辑继续收到 `internal/service` + 域 proto（PK-6+）
- 长期可合并生成链，但 **不要求** 删除 `api/`、`rpc/` 目录名
