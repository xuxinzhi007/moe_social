# moe-social 运行时架构（单进程 Hybrid）

> **更新：2026-05-27** · FS-9 后契约入口为 `api/moe.api`、`rpc/moe.proto`（分片 SSOT 在 `api/defs`、`rpc/defs`）  
> **纯 Kratos 落地**：[kratos-pure-rollout.md](./kratos-pure-rollout.md)

## 是不是「单体」？

**是部署上的单体，不是「纯 Kratos 微服务拆分」。**

| 维度 | 实际形态 |
|------|----------|
| **进程** | 默认 **一个 OS 进程**（`make moe-social`） |
| **对外** | 仅 **HTTP :8888**（Flutter / moe-admin / 第三方 REST） |
| **对内** | **gRPC :8080**（同进程内 API 调 RPC，或 `*gw` 直调 `biz` 不走回环） |
| **编排** | [Kratos](https://go-kratos.dev/) `kratos.App` 包装 go-zero `rest.Server`；RPC 为 go-zero `zrpc` |
| **代码分层** | `internal/biz` → `internal/service` → `api/internal/*gw`（域边界清晰） |
| **契约** | goctl 生成 handler/logic；**按域分片** 编辑 `defs/`，避免混域 |

因此：**一个命令拉起 API + RPC**，与「Kratos 单体内聚、按域分包」一致；**不是**每个域独立部署一个 Kratos 微服务。

## 一条命令做了什么？

```bash
cd backend
make moe-social    # 入口：cmd/moe-social-stack
```

等价于（简化）：

```text
1. 启动 zrpc（rpc/runserver）→ 监听 :8080
2. 等待 gRPC 就绪
3. 启动 rest（api/runserver）→ 监听 :8888
4. kratos.App.Run() 阻塞；退出时一并停止 RPC
```

可选：

- `-agent=true`：本机 deploy-agent `:19010`
- `-monitor=true`：RPC debug `:19011`（moe-admin RPC 监控页转发）

配置默认：

- `api/etc/moe.yaml`
- `rpc/etc/moe.yaml`

## 和「纯 Kratos 试点」的区别

| | **生产 Hybrid（moe-social）** | **试点（moe-kratos :1903x）** |
|--|------------------------------|-------------------------------|
| 用途 | 日常开发 / 生产 | 验证 Kratos 分层与 VIP 只读等 |
| 契约 | go-zero `moe.api` / `moe.proto` | 域 `api/*/v1/*.proto` stub |
| 对外 | **:8888** | **非对外** |

## 契约文件（FS-8 / FS-8b / FS-9）

| 用途 | 编辑这里 | goctl 入口（勿手改 RPC 列表） |
|------|----------|------------------------------|
| HTTP 类型 + 路由分域 | `api/defs/*.api` | `api/moe.api` |
| RPC message + 分域 rpc | `rpc/defs/common.proto`、`rpc/defs/services/*.rpcfrag` | `rpc/moe.proto`（assemble 生成） |

生成：

```bash
make gen-api    # moe.api
make gen-rpc    # assemble moe.proto + goctl
```

验收：

```bash
make verify-sprint-fs9   # FS-8b + FS-10 + 无 legacy super.* 文件名
```

## 仍保留的 `super` 命名

- **Protobuf 包名** `package super`、**Go 包** `backend/rpc/pb/super`、**gRPC 服务名** `Super`：与历史生成代码兼容，FS-9 **未改**（避免全仓 import 重命名）。
- 新功能应写在域 `defs` 碎片中，而不是恢复 `super.api` / `super.proto` 单体文件。
