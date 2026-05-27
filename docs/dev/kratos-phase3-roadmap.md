# Phase 3：纯 Kratos 路线图（后续里程碑）

> 混合迁移（Phase 1+2）已 100% 完成；本阶段为**下一阶段**，不阻塞当前上线。

## 目标

- 单进程 `cmd/moe-social` + `kratos.App`
- HTTP / gRPC 统一注册
- 配置 `conf.proto` + Wire 注入
- 按域退役 `super.api` / go-zero 启动

## 建议顺序

1. 引入 `github.com/go-kratos/kratos/v2` 与 `cmd/moe-social` 空壳（health + 现有 go-zero 并行）
2. 将 `api/moe/v1` 注册为 gRPC 服务（与 legacy Super 并存）
3. Admin HTTP 从 grpc-gateway 或 Kratos HTTP 注解生成
4. User / VIP 等域按模块迁移
5. 下线 `api/super.go` / `rpc/super.go` 双进程

## 参考

- [kratos-hybrid-migration-plan.md](./kratos-hybrid-migration-plan.md)
- [go-kratos/kratos](https://github.com/go-kratos/kratos)
