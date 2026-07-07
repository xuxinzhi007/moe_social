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
| **Model** | `model/` | `life_entity.go`、`life_event_log.go`、`life_world.go` |
| **Wire** | `wire_life.go` + `api_life.go` | Feature Flag 控制 + 依赖注入 |

### 2.2 前端分层

| 层级 | 文件 | 职责 |
|------|------|------|
| **Pages** | `life_world_page.dart` | 世界主页（连接状态、摘要卡、地图、Tab） |
| | `life_entity_detail.dart` | 实体详情页 |
| **Widgets** | `life_world_map.dart` | 2D 世界地图渲染 |
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

**繁殖条件：**
- Energy > 72 且 Hunger > 68 且 Mood > 74
- 额外 2.5% 概率触发
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

### 前端

- ✅ 世界主页（连接状态 + 摘要卡 + 地图 + Tab）
- ✅ 实体详情页
- ✅ AnimatedPositioned 精灵渲染
- ✅ 事件入场动画
- ✅ WebSocket 自动重连（指数退避 3s→6s→12s→…→10s 上限）
- ✅ 双格式 JSON 兼容（snake_case + camelCase）
- ✅ Feature Flag 入口（`showLifeEngine`）

---

## 5. 发现的 Bug

### 5.1 严重 Bug

#### Bug #1：死亡实体前端永不消失

- **现象**：实体死亡后，其精灵仍永久显示在地图界面上，不会消失。
- **位置**：`tick.go` + `life_provider.dart`
- **根因分析**：

  后端 `tick.go` 第 71 行在实体死亡时执行 `delete(mutableEntities, id)` 从内存 map 中移除，但广播的 `TickBroadcast` 中仅包含存活实体的 `EntityDiff`（第 82–92 行），**不包含任何"已移除实体 ID"字段**。

  前端 `life_provider.dart` 的 `_onStateUpdate` 方法（第 59–73 行）只做**增量合并**——遍历 `entityChanges` 更新 `_entities` Map，**没有任何删除逻辑**。由于死亡实体不再出现在增量更新中，前端 `_entities[id]` 永远不会被移除，导致死亡实体永远残留在地图上。

- **修复方向**：
  1. 后端 `TickBroadcast` 增加 `removed_entity_ids []uint` 字段，在死亡时将 ID 加入列表。
  2. 前端 `_onStateUpdate` 中读取 `removed_entity_ids`，从 `_entities` Map 中移除对应条目。

#### Bug #2：死亡实体未从 DB 删除

- **现象**：服务重启后，之前死亡的实体会重新出现在世界中（"复活"）。
- **位置**：`tick.go`
- **根因分析**：

  实体死亡时（`tick.go` 第 50–73 行），代码只执行了两个操作：
  1. 入队一条 `death` 事件日志（`EnqueueEvent`）
  2. 从内存 `mutableEntities` map 中 `delete` 该实体

  **但从未调用任何 DB 删除操作**（如 `store.DeleteEntity(ctx, id)`）。由于 `initWorld`（第 227 行）在启动时通过 `store.ListEntities` 从数据库加载所有实体，而死亡的实体仍留在 DB 中，重启后它们会被重新加载到内存中，造成"复活"。

- **修复方向**：
  1. 在死亡逻辑中调用 `engine.persistence.EnqueueDeleteEntity(entity.ID)` 或直接同步删除。
  2. 或者在 `Store` 接口增加 `DeleteEntity(ctx, id)` 方法，Data 层实现软删除/硬删除。

#### Bug #3：WorldGrid 不持久化

- **现象**：服务重启后，生态网格数据（食物分布、危险区域、地形状态）全部丢失，回到初始状态。
- **位置**：`tick.go` + `world_cache.go`
- **根因分析**：

  `WorldGrid`（`types.go` 第 55–59 行）是一个纯内存结构，存储在 `WorldSnapshot.Grid` 中。每个 Tick 中 `updateWorldEcology` 对 Grid 的修改（食物再生、危险波动、地形切换）**只影响内存数据**，从未被序列化到数据库。

  当服务重启时，`initWorld`（`tick.go` 第 247 行）调用 `newWorldGrid(engine.config)` 创建全新空白 Grid，所有生态模拟进展丢失。

- **修复方向**：
  1. 新增 `life_world_grids` 表，存储序列化 Grid JSON。
  2. 在 `initWorld` 中尝试从 DB 加载 Grid，找不到时再创建新 Grid。
  3. 定期（如每 N 个 Tick）将 Grid 入队持久化。

### 5.2 中等 Bug

#### Bug #4：WorldSnapshot 并发竞争

- **现象**：潜在数据竞争，极端情况下可能导致 panic。
- **位置**：`tick.go` vs `ws_hub.go`
- **根因分析**：

  `RunLifeTick` 在 `tick.go` 第 161 行执行 `snap.Entities = mutableEntities`，直接修改了 `WorldSnapshot` 的 `Entities` 字段（指针赋值）。而 `sendSnapshot`（`ws_hub.go` 第 147 行）通过 `engine.GetWorldCache().Get(worldID)` 获取同一个 `*WorldSnapshot` 指针，然后遍历 `snap.Entities`（第 162 行）。

  虽然 `WorldCache` 的 `Get`/`Set` 操作有 `sync.RWMutex` 保护，但 **`Get` 返回的是指针**——一旦获取到指针后，对 `snap.Entities` 字段的读写就不再受锁保护。Tick goroutine 写入 `snap.Entities` 的同时，WebSocket goroutine 可能在读取 `snap.Entities`，形成 **data race**。

  注意：当前代码中 Tick 使用 `mutableEntities` 做深拷贝操作，且赋值是原子级别的指针替换，实际触发 panic 的概率较低，但在 Go race detector 下会被检出。

- **修复方向**：
  1. `sendSnapshot` 中获取 snap 后，再做一次 `Entities` map 的浅拷贝。
  2. 或者让 `RunLifeTick` 构建一个全新的 `WorldSnapshot` 并通过 `cache.Set()` 替换，而非原地修改。

### 5.3 轻微 Bug

#### Bug #5：onConnected 重复触发

- **现象**：每次收到 WebSocket 消息时都会触发 `onConnected` 回调，导致不必要的 widget rebuild。
- **位置**：`life_ws_service.dart` 第 172–174 行
- **根因分析**：

  `_handleRawMessage` 中判断 `if (!_connecting)` 就调用 `onConnected?.call()`。由于 `_connecting` 在 `connect()` 的 `finally` 块中被设为 `false`（第 138 行），**连接建立后 `_connecting` 永远为 `false`**，因此每收到一条消息都会触发 `onConnected`。

  `life_provider.dart` 中 `onConnected` 回调（第 23–27 行）会调用 `notifyListeners()`，导致所有依赖该 Provider 的 widget 重新 build。

- **修复方向**：
  1. 增加 `_notifiedConnected` 标志位，只在首次从 false→true 时触发。
  2. 或者在 `connect()` 成功建立连接后立即调用 `onConnected`，消息处理中不再重复触发。

#### Bug #6：事件时间戳不准确

- **现象**：前端事件的时间戳全部是消息到达时间，而非服务端实际发生时间。
- **位置**：`types.go` + `life_state.dart`
- **根因分析**：

  后端 `EventDiff` 结构（`types.go` 第 89–96 行）**没有 `timestamp` 字段**。前端 `LifeEvent.fromJson`（`life_state.dart` 第 152–164 行）尝试解析 `json['timestamp']`，但后端从未发送该字段，所以 `_parseTimestamp(nil)` 始终 fallback 到 `DateTime.now()`（第 247 行）。

  这意味着所有事件的时间戳反映的是**前端收到消息的时刻**，而非服务端 Tick 处理的时刻，在消息延迟或批量到达时时间戳不准确。

- **修复方向**：
  1. 后端 `EventDiff` 增加 `Timestamp time.Time` 字段。
  2. 前端 `LifeEvent.fromJson` 已有双格式兼容逻辑，无需改动。

#### Bug #7：seeking_rest 无中文标签

- **现象**：当实体处于 `seeking_rest` 行为状态时，前端 fallback 显示默认的"停留中"而非"寻找休息处"。
- **位置**：`life_state.dart` 第 63–84 行
- **根因分析**：

  `LifeEntity.actionLabel` 的 switch 语句中列出了 8 种行为的中文映射，但**缺少 `seeking_rest` 的 case**。后端 `types.go` 第 14 行定义了 `ActionSeekingRest LifeAction = "seeking_rest"`，且 `tick.go` 第 196 行有对应的中文描述 `"在寻找安全角落"`，但前端 `actionLabel` 遗漏了该映射，导致进入 `default` 分支显示"停留中"。

- **修复方向**：
  在 `actionLabel` 的 switch 中增加：
  ```dart
  case 'seeking_rest':
    return '寻找休息处';
  ```

---

## 6. 未完成功能

| 功能 | 现状 | 影响 |
|------|------|------|
| **用户交互操作** | `POST /api/life/action` 返回 501 Not Implemented | 用户无法对实体执行任何操作 |
| **Proto 定义** | Life 域无 `.proto` 文件 | 唯一缺失 Proto 的模块，无法使用 gRPC |
| **WS 鉴权** | `CheckOrigin` 始终返回 `true`，无 token 校验 | 任意来源可建立 WS 连接 |
| **多世界支持** | `worldId` 硬编码为 `"default"` | 无法运行多个独立世界 |
| **历史回放** | 未实现 | 无法回顾过去的生态事件 |
| **实体搜索/筛选** | 未实现 | 大量实体时难以定位 |
| **暂停/加速控制** | 未实现 | 无法控制模拟速度 |

---

## 7. 优化建议

### 7.1 后端优化

| 问题 | 当前实现 | 建议 |
|------|---------|------|
| 随机数生成 | 使用 `math/rand` 全局函数 | 改用独立 `rand.Source`，避免全局锁竞争 |
| 广播并发 | `BroadcastState` 为每个 member 起 goroutine | 使用 worker pool 限制并发数 |
| 持久化丢弃 | channel 满时直接丢弃 | 保留脏标记，下次 flush 时重试 |
| flush 失败处理 | 失败仅 log，数据丢失 | 失败后将数据放回队列或保留脏标记 |
| 生命周期 | `context.Background()` 用于 DB 操作 | 改用服务生命周期 context |
| 代码风格 | `persistence.go` 使用 `goto` 跳出循环 | 改为 `for` + `select` + `break` 模式 |
| 测试覆盖 | 无单元测试 | 补充 engine、behavior、ecology 测试 |

### 7.2 前端优化

| 问题 | 当前实现 | 建议 |
|------|---------|------|
| 实体删除 | `_entities` Map 无删除逻辑 | 配合 `removed_entity_ids` 支持删除 |
| Provider 生命周期 | `dispose` 设置标志位但不主动断连 | `dispose` 中主动调用 `_wsService.disconnect()` |
| 颜色硬编码 | 使用硬编码颜色值 | 替换为主题 Token（`Theme.of(context)`） |
| 地图交互 | 固定尺寸渲染 | 增加 `InteractiveViewer` 支持缩放/平移 |
| 事件列表 | 详情页事件直接渲染 | 改用 `ListView.builder` 提升性能 |
| 路由 | 硬编码导航 | 统一命名路由 |
| 测试覆盖 | 无 Widget 测试 | 补充关键组件测试 |

---

## 8. 执行路线图

### 第 1 周（P0）— Bug 修复冲刺

| 优先级 | 任务 | 预估工时 |
|--------|------|---------|
| P0-1 | 死亡实体前后端同步（增加 `removed_entity_ids` + 前端删除逻辑） | 4h |
| P0-2 | 死亡实体 DB 删除（Store 增加 DeleteEntity + tick 调用） | 2h |
| P0-3 | WorldGrid 持久化（新建表 + 序列化/反序列化） | 4h |
| P0-4 | Snapshot 竞态修复（构建新 Snapshot 替换原地修改） | 2h |
| P0-5 | 前端小 Bug 修复（onConnected 重复、seeking_rest 标签） | 1h |

### 第 2 周（P1）— 数据层 + API

| 优先级 | 任务 | 预估工时 |
|--------|------|---------|
| P1-1 | 实现 `POST /api/life/action` 端点 | 6h |
| P1-2 | Store 查询扩展（分页、筛选、排序） | 4h |
| P1-3 | EventLog TTL 清理（定期归档/删除旧事件） | 2h |
| P1-4 | 数据库迁移脚本 | 2h |

### 第 3 周（P1 下）— 前端打磨 + 安全

| 优先级 | 任务 | 预估工时 |
|--------|------|---------|
| P1-5 | Loading 态 + 主题 Token 替换 | 3h |
| P1-6 | WebSocket 鉴权（token 校验 + Origin 检查） | 4h |
| P1-7 | 补充后端单元测试 + 前端 Widget 测试 | 6h |

### 远期（P2）— 功能演进

| 任务 | 说明 |
|------|------|
| Proto 定义补全 | 为 Life 域添加 protobuf 定义，支持 gRPC |
| 角色体系迁移 | 实体从简单属性系统迁移到角色/职业体系 |
| 背包/道具系统 | 实体可持有物品，影响属性和行为 |
| 历史回放 | 基于 EventLog 实现时间轴回放 |
| 多世界支持 | 解除 worldId 硬编码，支持创建/切换世界 |
