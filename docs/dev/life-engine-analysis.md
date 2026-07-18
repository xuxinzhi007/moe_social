# 数字生命模拟器现状分析

> 文档生成时间：2026-07-07  
> 模块：`life` 域（数字生命模拟器）  
> 范围：后端 `backend/internal/biz/life/` + 前端 `lib/pages/life/` / `lib/widgets/life/`

---

## 1. 项目概述

数字生命模拟器作为独立 `life` 域集成到 Moe Social 后端（与 `game` 域平级），提供基于 Tick 驱动的生态模拟能力。模拟器包含完整的后端引擎、WebSocket 实时广播和前端 2D 可视化界面。

- **总代码量**：约 3,500+ 行
  - 后端：~1,700 行
  - 前端：~1,800 行
- **通信协议**：WebSocket（`/ws/life`）+ REST API（4 端点）
- **Feature Flag**：后端 `life_engine_enabled`，前端 `showLifeEngine`，双层开关独立回滚

---

## 2. 架构概览

### 2.1 后端分层

| 层级 | 路径 | 职责 |
|------|------|------|
| **Transport** | `/ws/life` + REST API | WebSocket 实时推送 + 4 个 REST 端点（`/api/life/world`、`/api/life/entities`、`/api/life/events`、`/api/life/action`） |
| **Service** | `service/life/life.go` | AppService 组装 Store→Hub→Engine，对外暴露统一接口 |
| **Biz** | `biz/life/` | 核心引擎逻辑：engine、tick、behavior、ecology、persistence、world_cache、ws_hub、store（接口）、types |
| **Data** | `data/life/store.go` | GORM 实现，负责 MySQL 读写 |
| **Model** | `model/` | `life_entity.go`、`life_event_log.go`、`life_world.go`、`life_relationship.go` |
| **Wire** | `wire_life.go` + `api_life.go` | Feature Flag 控制 + 依赖注入 |

### 2.2 前端分层

> 2026-07-18 更新：当前 `life_world_page.dart` 已从早期地图/Tab 主页收束为「AI 伙伴」陪伴首页。地图、Canvas 和面板组件仍保留为可复用/历史能力，但默认体验优先展示单个生命、照料建议、小世界概况、状态条、居民切换和最近事件。

| 层级 | 文件 | 职责 |
|------|------|------|
| **Pages** | `life_world_page.dart` | AI 伙伴陪伴首页（照料建议、小世界概况、状态、居民切换、最近事件） |
| | `life_entity_detail.dart` | 实体详情页 |
| | `life_relationship_page.dart` | 蛛网式关系可视化页面 |
| **Widgets** | `life_world_map.dart` | 2D 世界地图渲染（保留能力，非当前默认首页） |
| | `life_entity_sprite.dart` | AnimatedPositioned 精灵渲染 |
| | `life_event_feed.dart` | 事件流（带动画入场） |
| **Provider** | `life_provider.dart` | ChangeNotifier 状态管理，维护实体 Map + 事件列表 |
| **Service** | `life_ws_service.dart` | WebSocket 连接管理（指数退避重连、心跳） |
| **Model** | `life_state.dart` | 数据模型 + JSON 解析（双格式兼容） |

---

## 3. 核心机制

### 3.1 Tick 引擎（5 秒周期）

每个 Tick 执行以下流程：

1. **加载/初始化世界** — 首次从 DB 加载，若无数据则创建 6 个种子实体
2. **深拷贝实体** — 复制为 `mutableEntities`，避免并发修改缓存
3. **更新生态网格** — 32×18 WorldGrid 执行食物再生、危险波动、地形切换
4. **遍历实体** — 对每个实体依次执行：
   - 属性衰减（`decayAttributes`）
   - 环境效果（`applyEnvironmentEffects`）
   - 死亡判定（`shouldDie`）
   - 行为决策（`decideAction`）
   - 行动应用（`applyAction`）
   - 繁殖检查（`maybeSpawnOffspring`）
5. **收尾** — 持久化入队 + 更新缓存 + 广播差异

### 3.2 属性系统

| 属性 | 每 Tick 衰减 | 环境增益/惩罚 |
|------|-------------|--------------|
| **Hunger** | -0.8 | 进食回复 |
| **Energy** | -0.45 | Danger>35 时额外 -0.3 |
| **Mood** | -0.18 | Danger>35 → -0.9；不可居住 → -0.6；Moisture>75 → +0.2 |

### 3.3 行为决策树

按优先级从高到低：

```
Energy < 15       → Sleep（休息）
Hunger < 26       → SeekFood（觅食）
Mood < 28         → Wander（漫游）
18% 随机概率       → Walk（行走）
否则               → Idle（停留）
```

### 3.4 死亡与繁殖

**死亡条件：**
- Hunger ≤ 2 或 Energy ≤ 2 → 必定死亡
- Danger > 92 时 → 8% 概率死亡
- 老年阶段（elder）`age_ticks >= max_age_ticks` → 自然死亡

**繁殖条件：**
- Energy > 72 且 Hunger > 68 且 Mood > 74
- 仅成年（adult）阶段可繁殖
- 额外 2.5% 概率触发（mate 关系概率翻倍）
- 世界实体上限 50

### 3.5 WebSocket 协议

| 方向 | 消息类型 | 格式 |
|------|---------|------|
| 客户端→服务端 | subscribe | `{"type":"subscribe","world":"default"}` |
| 客户端→服务端 | ping | `{"type":"ping"}` |
| 服务端→客户端 | state_snapshot | 全量世界快照（首次订阅时发送） |
| 服务端→客户端 | life_state | 增量状态更新（每 Tick 广播） |
| 服务端→客户端 | pong | 心跳回复 |

---

## 4. 已实现功能清单

### 后端

- ✅ 5 秒 Tick goroutine 循环
- ✅ 内存优先 WorldCache
- ✅ 6 个种子实体（小花🐰、时雨🦊、团子🐹、啾啾🐥、泡泡🐠、小眠🦌）
- ✅ 三维属性系统 + 衰减
- ✅ 10 种行为状态 + 决策树
- ✅ 环境效应系统
- ✅ 32×18 生态网格
- ✅ 繁殖/死亡系统
- ✅ 异步批量持久化（PersistenceWriter）
- ✅ WebSocket Hub（按世界广播）
- ✅ REST API（4 端点）
- ✅ Feature Flag（`life_engine_enabled`）
- ✅ 实体成长与进化系统（4 阶段：幼年→少年→成年→老年，经验积累、属性上限/衰减修正、老年自然死亡）
- ✅ 社交关系网络系统（friend/rival/mate 三种关系，亲密度机制，关系形成/衰减/升级/解除）
- ✅ 用户操作端点（`POST /api/life/action`：feed/pet，含冷却与 429 响应）
- ✅ 社交关系 REST API（`GET /api/life/relationships`）
- ✅ 关系影响行为决策（趋向朋友、远离对手）
- ✅ mate 关系繁殖概率翻倍
- ✅ WorldGrid 持久化（每 10 tick 序列化到 DB）
- ✅ 死亡实体 DB 软删除（`is_alive` 字段）
- ✅ WorldSnapshot 原子替换（消除竞态）
- ✅ 优雅关闭支持（可取消 context + Shutdown）

### 前端

- ✅ 世界主页（连接状态 + 摘要卡 + 地图 + Tab）
- ✅ 实体详情页
- ✅ AnimatedPositioned 精灵渲染
- ✅ 事件入场动画
- ✅ WebSocket 自动重连（指数退避 3s→6s→12s→…→10s 上限）
- ✅ 双格式 JSON 兼容（snake_case + camelCase）
- ✅ Feature Flag 入口（`showLifeEngine`）
- ✅ 用户操作交互（喂食/抚摸按钮 + 地图长按菜单）
- ✅ 操作反馈动画（❤️/✨ 上浮）
- ✅ 冷却温和提示（琥珀色 vs 红色）
- ✅ 成长阶段 UI（阶段标签、进度条、年龄显示、精灵大小/透明度变化）
- ✅ 蛛网式关系可视化页面（SpiderWebPainter + 力导向布局 + InteractiveViewer）
- ✅ 成长事件金色高亮
- ✅ 社交事件绿色高亮
- ✅ 首次连接 Loading 态

---

## 5. 发现的 Bug（均已修复）

### 5.1 ~~严重 Bug~~（已修复）

#### ~~Bug #1：死亡实体前端永不消失~~ ✅ 已修复

- **现象**：实体死亡后，其精灵仍永久显示在地图界面上，不会消失。
- **修复方式**：后端 `TickBroadcast` 增加 `removed_entity_ids` 字段，死亡时将 ID 加入列表；前端 `_onStateUpdate` 读取该列表并从 `_entities` Map 中移除对应条目。

#### ~~Bug #2：死亡实体未从 DB 删除~~ ✅ 已修复

- **现象**：服务重启后，之前死亡的实体会重新出现在世界中（"复活"）。
- **修复方式**：Store 接口新增 `DeleteEntity` 方法，Data 层实现软删除（设置 `is_alive = false`）；死亡逻辑中调用 `store.DeleteEntity` 同步标记。

#### ~~Bug #3：WorldGrid 不持久化~~ ✅ 已修复

- **现象**：服务重启后，生态网格数据全部丢失。
- **修复方式**：WorldGrid 每 10 tick 序列化（JSON）写入 `life_worlds` 表的 `grid_data` 字段；`initWorld` 启动时优先从 DB 加载 Grid，找不到时再创建新 Grid。

### 5.2 ~~中等 Bug~~（已修复）

#### ~~Bug #4：WorldSnapshot 并发竞争~~ ✅ 已修复

- **现象**：潜在数据竞争，Tick goroutine 与 WebSocket goroutine 同时读写 Snapshot。
- **修复方式**：`RunLifeTick` 构建全新 `WorldSnapshot` 并通过 `cache.Set()` 原子替换，而非原地修改指针字段，消除竞态。

### 5.3 ~~轻微 Bug~~（已修复）

#### ~~Bug #5：onConnected 重复触发~~ ✅ 已修复

- **现象**：每次收到 WebSocket 消息时都会触发 `onConnected` 回调，导致不必要的 widget rebuild。
- **修复方式**：增加 `_notifiedConnected` 标志位，仅在首次连接成功时触发 `onConnected`，后续消息不再重复调用。

#### ~~Bug #6：事件时间戳不准确~~ ✅ 已修复

- **现象**：前端事件的时间戳全部是消息到达时间，而非服务端实际发生时间。
- **修复方式**：后端 `EventDiff` 增加 `Timestamp` 字段，tick 处理时填充服务端时间；前端已有双格式解析逻辑，无需改动。

#### ~~Bug #7：seeking_rest 无中文标签~~ ✅ 已修复

- **现象**：`seeking_rest` 行为状态 fallback 显示"停留中"而非"寻找休息处"。
- **修复方式**：前端 `actionLabel` switch 中补充 `case 'seeking_rest': return '寻找休息处';`。

---

## 6. 未完成功能

| 功能 | 现状 | 影响 |
|------|------|------|
| **Proto 定义** | Life 域无 `.proto` 文件 | 唯一缺失 Proto 的模块，无法使用 gRPC |
| **WS 鉴权** | `CheckOrigin` 始终返回 `true`，无 token 校验 | 任意来源可建立 WS 连接 |
| **多世界支持** | `worldId` 硬编码为 `"default"` | 无法运行多个独立世界 |
| **历史回放** | 未实现 | 无法回顾过去的生态事件 |
| **实体搜索/筛选** | 未实现 | 大量实体时难以定位 |
| **暂停/加速控制** | 未实现 | 无法控制模拟速度 |

---

## 7. 优化建议

### 7.0 当前前端体验收束（2026-07-18）

当前阶段优先按「个人小世界 / 陪伴」优化，不再把数字生命作为游戏大厅或复杂地图工具来推进：

1. 首屏先回答「谁需要关注」和「现在该做什么」。
2. 世界摘要作为辅助上下文展示，不压过选中生命。
3. 互动入口保持少量高意图：喂食、陪伴、详情、互动故事。
4. 离线时可读缓存状态，但禁用会修改服务端状态的操作。
5. 后续优先补事件分组、居民照料优先级和背包道具建议，再考虑历史回放或模拟速度控制。

### 7.1 后端优化

| 问题 | 当前实现 | 建议 |
|------|---------|------|
| 随机数生成 | 使用 `math/rand` 全局函数 | 改用独立 `rand.Source`，避免全局锁竞争 |
| 广播并发 | `BroadcastState` 为每个 member 起 goroutine | 使用 worker pool 限制并发数 |
| 持久化丢弃 | channel 满时直接丢弃 | 保留脏标记，下次 flush 时重试 |
| flush 失败处理 | 失败仅 log，数据丢失 | 失败后将数据放回队列或保留脏标记 |
| 代码风格 | `persistence.go` 使用 `goto` 跳出循环 | 改为 `for` + `select` + `break` 模式 |
| 测试覆盖 | 无单元测试 | 补充 engine、behavior、ecology、growth、social 测试 |

### 7.2 前端优化

| 问题 | 当前实现 | 建议 |
|------|---------|------|
| Provider 生命周期 | `dispose` 设置标志位但不主动断连 | `dispose` 中主动调用 `_wsService.disconnect()` |
| 颜色硬编码 | 使用硬编码颜色值 | 替换为主题 Token（`Theme.of(context)`） |
| 事件列表 | 详情页事件直接渲染 | 改用 `ListView.builder` 提升性能 |
| 路由 | 硬编码导航 | 统一命名路由 |
| 测试覆盖 | 无 Widget 测试 | 补充关键组件测试 |

---

## 8. 执行路线图

### 第 1 周（P0）— Bug 修复冲刺 ✅ 已完成

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P0-1 | 死亡实体前后端同步（增加 `removed_entity_ids` + 前端删除逻辑） | ✅ 已完成 |
| P0-2 | 死亡实体 DB 删除（Store 增加 DeleteEntity + tick 调用） | ✅ 已完成 |
| P0-3 | WorldGrid 持久化（序列化到 life_worlds 表） | ✅ 已完成 |
| P0-4 | Snapshot 竞态修复（构建新 Snapshot 原子替换） | ✅ 已完成 |
| P0-5 | 前端小 Bug 修复（onConnected 重复、seeking_rest 标签、时间戳） | ✅ 已完成 |

### 第 2 周（P1）— 数据层 + API ✅ 已完成

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P1-1 | 实现 `POST /api/life/action` 端点（feed/pet） | ✅ 已完成 |
| P1-2 | 社交关系 REST API（`GET /api/life/relationships`） | ✅ 已完成 |
| P1-3 | 实体成长系统后端（growth.go） | ✅ 已完成 |
| P1-4 | 社交关系系统后端（social.go） | ✅ 已完成 |

### 第 3 周（P1 下）— 前端打磨 + 安全 ✅ 已完成

| 优先级 | 任务 | 状态 |
|--------|------|------|
| P1-5 | 用户操作交互 UI + 反馈动画 + 冷却提示 | ✅ 已完成 |
| P1-6 | 成长阶段 UI（标签、进度条、精灵变化） | ✅ 已完成 |
| P1-7 | 蛛网式关系可视化页面 | ✅ 已完成 |
| P1-8 | 首次连接 Loading 态 + 事件高亮 | ✅ 已完成 |

### 远期（P2）— 功能演进

| 任务 | 说明 |
|------|------|
| Proto 定义补全 | 为 Life 域添加 protobuf 定义，支持 gRPC |
| WS 鉴权 | WebSocket 连接增加 JWT token 校验 |
| 多世界支持 | 解除 worldId 硬编码，支持创建/切换世界 |
| 历史回放 | 基于 EventLog 实现时间轴回放 |
| 角色体系迁移 | 实体从简单属性系统迁移到角色/职业体系 |
| 背包/道具系统 | 实体可持有物品，影响属性和行为 |

---

## 9. 本次会话已实现总结

### 阶段一：用户交互深化 ✅ 已完成

**核心交付物：**
- 前端：实体详情页喂食/抚摸按钮、地图长按操作菜单、操作反馈浮动动画（❤️/✨）、冷却温和提示（琥珀色/红色双色态）
- 后端：`POST /api/life/action` 端点实现 feed/pet 两种操作（含冷却限制与 429 响应）、操作事件日志
- 首次连接 Loading 态

### 阶段二：实体成长与进化 ✅ 已完成

**核心交付物：**
- 后端：4 阶段成长系统（幼年→少年→成年→老年），`growth.go` 封装成长阶段逻辑；经验积累机制（每 tick +1，操作额外奖励）；属性上限/衰减随阶段修正；老年自然死亡（`is_alive` 软删除）；成长事件日志（`growth` 类型）
- 前端：成长阶段标签、经验进度条、年龄显示、精灵大小/透明度随阶段变化、成长事件金色高亮

### 阶段三：社交关系网络 ✅ 已完成

**核心交付物：**
- 后端：`social.go` 封装社交关系逻辑；friend/rival/mate 三种关系类型；亲密度机制（距离检测 + 同区域积累 + 衰减）；关系形成/升级/解除自动判定；关系影响行为决策（趋向朋友、远离对手）；mate 关系繁殖概率翻倍；`GET /api/life/relationships` REST API
- 前端：蛛网式关系可视化页面（`SpiderWebPainter` + 力导向布局 + `InteractiveViewer`），社交事件绿色高亮

---

## 10. 新增数据表

### life_relationships

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `uint` | 主键 |
| `world_id` | `string(64)` | 所属世界 ID |
| `entity_id` | `uint` | 实体 ID |
| `target_id` | `uint` | 目标实体 ID |
| `relation_type` | `string(16)` | 关系类型：friend/rival/mate |
| `affinity` | `float64` | 亲密度（0-100） |
| `created_at` | `time.Time` | 创建时间 |
| `updated_at` | `time.Time` | 更新时间 |

---

## 11. 新增文件

| 文件路径 | 说明 |
|----------|------|
| `backend/internal/biz/life/growth.go` | 成长阶段系统（阶段定义、经验阈值、属性修正、成长触发） |
| `backend/internal/biz/life/social.go` | 社交关系系统（亲密度计算、关系形成/衰减/升级/解除、行为影响） |
| `backend/model/life_relationship.go` | 关系数据模型（LifeRelationship 结构体 + GORM tag） |
| `lib/pages/life/life_relationship_page.dart` | 蛛网式关系可视化页面（SpiderWebPainter + 力导向布局） |
