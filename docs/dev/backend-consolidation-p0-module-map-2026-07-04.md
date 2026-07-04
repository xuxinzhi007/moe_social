# 后端收敛 P0：模块归并表

> 日期：2026-07-04
> 主文档：
> [backend-consolidation-p0-p3-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-p3-2026-07-04.md)

## 1. 目的

本表用于回答一个问题：
当前代码里的模块，后续应该继续存在于哪个能力域里，哪些不应继续扩张。

## 2. 归并表

| 当前模块/目录 | 当前角色 | 目标归属 | P0 结论 | 后续动作 |
|------|------|------|------|------|
| `internal/server` | HTTP 入口、协议适配、过滤器 | Interface Layer | 保留 | 继续作为唯一对外入口 |
| `internal/server/transport` | App 风格路由与触发接口 | Interface Layer | 保留但收口 | 不再扩散业务逻辑 |
| `internal/server/protohttp` | proto HTTP 适配 | Interface Layer | 保留 | 只做协议适配 |
| `internal/platform/moesocial` | 生产启动入口 | Platform Layer | 保留 | 固定为标准运行入口 |
| `internal/platform/wiring` | 服务装配 | Platform Layer | 保留但拆分 | P1 改成按域装配 |
| `internal/platform/svc` | ServiceContext 容器 | Platform Layer | 保留但瘦身 | P1 改成按域聚合 |
| `internal/platform/moewiring` | 配置开关与域服务构造 | Platform Layer | 保留但压缩 | P1 归并配置模式 |
| `internal/service/post` | 发帖应用服务 | Community Domain | 保留 | 归入 Community 域装配 |
| `internal/service/comment` | 评论应用服务 | Community Domain | 保留 | 归入 Community 域装配 |
| `internal/service/community` | 社区聚合应用服务 | Community Domain | 保留 | 作为 Community 主服务之一 |
| `internal/service/chat` | 聊天/互动服务 | Community Domain | 保留 | 与 Community 协同，但不混入 AI 平台层 |
| `internal/service/notify` | 通知服务 | Community Domain | 保留 | 后续可下沉为共享能力 |
| `internal/service/moe` | AI 管理与执行入口 | AIAgent Domain | 保留 | 作为 AI 平台主入口之一 |
| `pkg/moe/runtime` | AI 运行时、调度、生成 | AIAgent Domain | 保留 | 收口为 Trigger/Executor 主链路 |
| `pkg/moe/brain` | AI 记忆、策略、上下文 | AIAgent Domain | 保留 | 收口为 Policy/Planner 支撑层 |
| `pkg/moe/postpulse` | 社区内容检索辅助 | AIAgent Domain | 保留 | 作为 AI 输入能力 |
| `pkg/moe/toolaudit` | AI 工具审计 | Platform Layer | 保留 | 并入统一 audit/runlog 体系 |
| `internal/service/game` | 游戏应用服务 | Game Domain | 保留 | 与 Community/AI 解耦 |
| `internal/biz/game` | 游戏核心规则 | Game Domain | 保留 | 复用 AI 引擎但不混入社区主链路 |
| `pkg/llminference` | 推理客户端 | Infrastructure Layer | 保留 | 统一为 LLM 调用底座 |
| `utils/db.go` | DB 初始化与连接池 | Infrastructure Layer | 保留但降耦合 | 后续从全局状态转向平台化注入 |
| `internal/platform/moelog` | 日志封装 | Platform Layer | 保留但升级 | 统一 access/business/error/audit |

## 3. P0 结论

1. 以后不再按“页面/入口”定义后端模块。
2. 后端核心能力域固定为：
   `Community`
   `AIAgent`
   `Game`
   `Platform/Infra`
3. 以后新增能力时，先判断属于哪个域，再决定放在哪层。
