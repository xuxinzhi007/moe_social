# 后端收敛 P0：配置归并表

> 日期：2026-07-04
> 主文档：
> [backend-consolidation-p0-p3-2026-07-04.md](C:/Users/ZhuanZ1/Desktop/moe_social/docs/dev/backend-consolidation-p0-p3-2026-07-04.md)

## 1. 目的

本表用于回答另一个问题：
当前配置项里，哪些是长期保留的，哪些是迁移期开关，哪些应该在 P1 合并。

## 2. 归并表

| 当前配置键 | 当前作用 | 类型判断 | P0 结论 | P1 方向 |
|------|------|------|------|------|
| `server.host` / `server.port` | 对外服务基础配置 | 长期保留 | 保留 | 不调整 |
| `runtime.http_host` / `runtime.http_port` | 运行时 HTTP 端口 | 长期保留 | 保留 | 与生产入口说明对齐 |
| `api.timeout_ms` | API 超时 | 长期保留 | 保留 | 纳入统一 runtime 视图 |
| `llm_inference.*` | 推理服务配置 | 长期保留 | 保留 | 作为统一 LLM 基础设施配置 |
| `memory.*` | 记忆检索配置 | 长期保留 | 保留 | 保持为 AI 支撑配置 |
| `database.*` | DB 配置 | 长期保留 | 保留 | 不调整 |
| `moe.enabled` | Moe 主开关 | 长期保留 | 保留 | 作为 AI 平台总开关 |
| `moe.bot_scheduler_*` | AI 定时调度 | 长期保留 | 保留 | 归入 AI Runtime 配置域 |
| `moe.dream_scheduler_*` | AI Dream 调度 | 长期保留 | 保留 | 归入 AI Runtime 配置域 |
| `moe.bot_post_model` | AI 发帖默认模型 | 长期保留 | 保留 | 后续并入 AI Runtime 模型策略 |
| `moe.api_in_process` | 迁移期装配开关 | 迁移期开关 | 冻结，不再扩张 | P1 合并/退役 |
| `moe.single_process` | 单进程模式开关 | 迁移期开关 | 固定为标准模式 | P1 收敛为 `server.mode` |
| `moe.*_api_in_process` | 各域进程内启停 | 迁移期开关 | 冻结，不再新增 | P1 合并/退役 |
| `moe.kratos_pure_enabled` | 纯 Kratos 模式 | 迁移期开关 | 视为当前标准 | P1 收敛为 `server.mode` |
| `moe.kratos_http_front_enabled` | 混合前台模式 | 迁移期开关 | 不再扩张 | P1 退役 |
| `moe.kratos_grpc_managed` | 历史托管开关 | 迁移期开关 | 不再扩张 | P1 评估退役 |
| `moe.kratos_*_http_enabled` | 试点/灰度开关 | 迁移期开关 | 冻结 | P1 统一归并 |
| `moe.kratos_pilot_read_enabled` | 试点读流量开关 | 迁移期开关 | 冻结 | P1 统一归并 |
| `moe.super_grpc_retired` | 历史兼容开关 | 迁移期开关 | 不再扩张 | P1/P2 清退 |

## 3. P0 结论

从现在开始，配置分三类理解：

1. `Core Runtime`
   例如：DB、HTTP、Timeout、LLM。

2. `AI Runtime`
   例如：scheduler、memory、model policy。

3. `Migration Flags`
   例如：`*_in_process`、`kratos_*`、`pilot_*`。

P0 结论是：

1. 长期配置继续保留。
2. 迁移期开关全部冻结，不再新增。
3. P1 将尝试把迁移期开关压成更少的模式配置，例如：
   `server.mode`
   `ai.mode`
   `observability.mode`
