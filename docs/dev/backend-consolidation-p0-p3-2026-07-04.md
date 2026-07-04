# 后端收敛方案（P0-P3）

> 日期：2026-07-04
> 范围：`backend/` 当前单进程 Kratos 后端、运行时装配、AI 主链路、日志与配置
> 目标：先收敛系统复杂度，再推进社区 AI 产品能力
> 关联文档：
> [kratos-migration.md](./kratos-migration.md)
> [kratos-architecture-audit.md](./kratos-architecture-audit.md)
> [moe-social-runtime.md](./moe-social-runtime.md)
> [Moe-Intelligence-Stack-v1.md](./Moe-Intelligence-Stack-v1.md)

---

## 1. 一句话结论

当前后端已经完成了“对外单入口”的迁移，但还没有完成“内部单架构”的收敛。

现在最主要的问题不是某个接口或某个功能点，而是：

1. 装配层过重。
2. 配置开关过多。
3. AI 能力分散在多个层级和模块里。
4. 基础设施没有收敛成统一基建。

因此本轮不以“继续堆功能”为目标，而以“后端可持续演进”为目标，按 `P0 -> P3` 分阶段推进。

---

## 2. 当前系统判断

### 2.1 已经收敛的部分

这些是当前后端的正面基础：

1. 对外生产入口已经统一。
   证据：[backend/cmd/moe-social/main.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/cmd/moe-social/main.go:1)
   证据：[backend/internal/platform/moesocial/run_http_only.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/platform/moesocial/run_http_only.go:14)

2. HTTP 服务注册已经集中在 `internal/server`。
   证据：[backend/internal/server/http.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/server/http.go:12)

3. Kratos 迁移主线已经完成，当前不是 go-zero 生产运行时。
   证据：[docs/dev/kratos-architecture-audit.md](./kratos-architecture-audit.md)

### 2.2 仍然复杂的部分

这些是当前后端复杂度的主要来源：

1. `ServiceContext` 已演变成大容器。
   证据：[backend/internal/platform/svc/servicecontext.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/platform/svc/servicecontext.go:26)

2. `wire_svc.go` 负责逐域手工装配大量服务。
   证据：[backend/internal/platform/wiring/wire_svc.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/platform/wiring/wire_svc.go:16)

3. `moewiring/config.go` 中存在大量迁移期布尔开关。
   证据：[backend/internal/platform/moewiring/config.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/platform/moewiring/config.go:34)

4. AI 能力分散在 transport、service、runtime、brain、game、community 等多条路径中。
   证据：
   [backend/internal/server/transport/moe_trigger.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/server/transport/moe_trigger.go:1)
   [backend/pkg/moe/runtime/scheduler.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/pkg/moe/runtime/scheduler.go:1)
   [backend/pkg/moe/runtime/generate.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/pkg/moe/runtime/generate.go:1)

5. 日志和观测不是默认统一基建。
   证据：
   [backend/utils/db.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/utils/db.go:86)
   [backend/internal/platform/moelog/log.go](C:/Users/ZhuanZ1/Desktop/moe_social/backend/internal/platform/moelog/log.go:1)

---

## 3. 这轮优化的总目标

本轮后端调整不追求“大重写”，而追求三件事：

1. 让系统结构更容易理解。
2. 让 AI 主链路变成第一等能力。
3. 让后续迭代新增能力时不继续长出新系统。

目标状态定义如下：

1. 单入口
   对外只认一个生产 HTTP 入口。

2. 单装配
   服务装配按能力域组织，不再按页面或历史接口散装。

3. 单 AI 主链路
   所有社区 AI、游戏 AI、后台 AI 触发都进入统一运行链路。

4. 单观测基线
   启动日志、请求日志、业务日志、审计日志统一。

---

## 4. 目标架构

### 4.1 五层结构

建议后端逐步收敛成以下五层：

1. `Interface Layer`
   负责 HTTP、proto、transport、auth、request log、response envelope。

2. `Application Layer`
   负责用例编排，例如 `TriggerAgent`、`GenerateCommunityPost`、`RunGameTurn`。

3. `Domain Layer`
   负责业务规则和边界，建议优先稳定四个核心域：
   `user`
   `community`
   `aiagent`
   `game`

4. `Infrastructure Layer`
   负责 DB、LLM、scheduler、external API、storage。

5. `Platform Layer`
   负责日志、配置、审计、feature flag、可观测性、运行模式。

### 4.2 AI 主链路

后续社区 AI 和游戏 AI 都应基于一条统一链路：

`Trigger -> Policy -> Planner -> Executor -> RunLog/Audit`

定义如下：

1. `Trigger`
   来源：用户手动触发、后台触发、定时任务、社区事件。

2. `Policy`
   负责判断是否允许执行、执行频率、执行身份、目标范围。

3. `Planner`
   负责决定动作类型，例如：
   发动态
   评论
   回复
   点赞
   游戏叙事

4. `Executor`
   负责真正调用 community/game/notify/llm 等底层动作。

5. `RunLog/Audit`
   负责记录执行链路和结果，替代“看 SQL 猜系统状态”。

---

## 5. P0-P3 分阶段计划

## P0：止血和收口基础

### P0 目标

先让后端变成“能解释清楚的系统”。

### P0 范围

1. 固定唯一标准运行模式。
2. 统一基础日志口径。
3. 明确后端核心能力域边界。
4. 统一 AI 相关术语和主链路命名。
5. 建立后续 P1-P3 的执行基线。

### P0 交付物

1. 本方案文档。
2. 当前架构问题清单。
3. P1-P3 路线图。
4. 统一术语表。
5. 待收口模块表。

### P0 不做什么

1. 不重写业务实现。
2. 不新增 AI 页面。
3. 不继续增加运行模式开关。
4. 不再把社区 AI 和游戏 AI 做成两套独立系统。

### P0 验收标准

1. 团队能用一页文档说清楚当前后端怎么运行。
2. 团队能明确哪些模块属于 `community / aiagent / game / platform`。
3. 后续改造有正式分期，不再边想边改。

---

## P1：装配层和配置层瘦身

### P1 目标

把“迁移期大装配”收成“按能力域装配”。

### P1 动作

1. 收缩 `ServiceContext`
   由平铺大量 `*AppService` 字段，调整为按域聚合。

2. 拆分 `wire_svc.go`
   调整为按域装配：
   `wire_community.go`
   `wire_ai.go`
   `wire_game.go`
   `wire_platform.go`

3. 归并 `moewiring/config.go`
   将大量运行开关压缩成少量模式配置。

4. 停止继续新增 `*_api_in_process` 风格开关。

### P1 验收标准

1. 新增业务域时不需要继续扩展一条超长装配文件。
2. 当前运行模式能在少量配置项中看懂。

---

## P2：AI 平台层化

### P2 目标

把 AI 从“散点能力”升级成“统一平台能力”。

### P2 动作

1. 建立统一 AI 应用层。
2. 社区 AI 动作统一建模为 `Action`。
3. 统一触发入口，不再由多个页面和多个后台路径各自驱动。
4. 统一 run log / audit。

### P2 验收标准

1. 判断 AI 是否触发成功，不再依赖 SQL 或页面猜测。
2. 发动态、评论、回复等行为进入同一链路。

---

## P3：面向拓展的业务域重整

### P3 目标

让社区 AI、游戏 AI、后续平台能力都建立在稳定边界上。

### P3 动作

1. 社区域和 AI 域解耦。
2. 游戏域独立，但可复用 AI 引擎。
3. 后台只保留控制和审计能力，不变成平行业务系统。
4. 为事件驱动扩展预留稳定接口。

### P3 验收标准

1. 新增 AI 行为是“加动作”，不是“加新系统”。
2. 社区线和游戏线可以分别演进，不互相污染。

---

## 6. 当前模块归类建议

这是本轮后续调整的分组基线。

### 6.1 Community 域

1. `internal/service/post`
2. `internal/service/comment`
3. `internal/service/community`
4. `internal/service/chat`
5. `internal/service/notify`

### 6.2 AIAgent 域

1. `internal/service/moe`
2. `pkg/moe/runtime`
3. `pkg/moe/brain`
4. `pkg/moe/postpulse`
5. `pkg/moe/toolaudit`

### 6.3 Game 域

1. `internal/service/game`
2. `internal/biz/game`
3. 与 game 专属推理配置相关的 adapter

### 6.4 Platform/Infra 域

1. `internal/platform/*`
2. `utils/db.go`
3. `pkg/llminference`
4. `internal/server/*`

---

## 7. 统一术语表

从本轮开始，后端相关讨论统一使用以下术语：

1. `AI Account`
   产品层可见的 AI 用户账号。

2. `AI Runtime`
   AI 账号对应的运行时配置。

3. `AI Trigger`
   某次启动 AI 行为的来源。

4. `AI Action`
   AI 实际执行的动作，例如发动态、评论、回复。

5. `AI RunLog`
   AI 一次执行流程的运行结果记录。

6. `AI Policy`
   AI 在当前上下文中该不该做、能做什么的规则层。

禁止继续混用：
`assistant`
`bot page`
`helper page`
`runtime page`
这些页面化、入口化的命名作为系统主模型。

---

## 8. P0 执行清单

以下事项视为本轮 P0 的正式清单：

1. 产出后端收敛方案文档。
2. 将该文档加入 docs 导航。
3. 后续所有后端改造都引用本方案，而不是另开并行架构文档。
4. P1 开始前，先基于本方案确认模块归并表和配置归并表。

---

## 9. 后续执行建议

推荐执行顺序：

1. 先完成 P0 文档和边界确认。
2. 然后进入 P1，先动装配层和配置层。
3. P2 再做 AI 平台层化。
4. P3 最后做业务域重整。

不建议的顺序：

1. 继续加新 AI 页面。
2. 继续新增零散触发接口。
3. 一边补功能一边临时改架构。

---

## 10. 当前状态

2026-07-04 当前状态：

1. P0 已启动。
2. 本文档作为本轮后端收敛 SSOT。
3. 下一阶段建议进入 P1 设计细化：
   `ServiceContext` 归并
   `wire_svc.go` 分域
   `moewiring/config.go` 配置归并
