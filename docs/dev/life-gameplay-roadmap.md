# 数字生命模拟器 — 玩法演进实施计划

> **版本**: v1.2 · **最后更新**: 2026-07-10  
> **当前状态**: 阶段一（用户交互深化）✅ · 阶段二（实体成长与进化）✅ · 阶段三（社交关系网络）✅ · 阶段四/五待实施  
> **产品定位**: 增强型功能（P1）· 详见 `docs/product/product-positioning.md` §2.1

---

## 1. 愿景与目标

### 1.1 核心愿景

**数字生命是用户手机里的个人小世界。**

用户可干预，但生命自主演化。每个数字生命都有独立个性。完全随机化，一切皆有可能。发生不同事件、生长、社交——一个用户自己的私密小世界。

### 1.2 设计原则

- **涌现而非编排**：不预设剧本，让规则驱动行为，让行为涌现故事
- **个性而非模板**：每个生命都有独立的性格、成长轨迹和行为偏好
- **随机而非混乱**：一切皆有可能，但遵循内在逻辑和生态规律
- **干预而非控制**：用户可以喂食、抚摸、使用道具，但生命按自己的意志行动
- **私密而非社交**：这是用户自己的小世界，不需要与他人比较或竞争

### 1.3 技术实现方向

- 生态沙盒骨架（规则驱动、地形演化、食物链）+ 轻量互动（喂食/道具/观察）
- **暂缓**：AI 对话、社交分享、多人联机

### 1.4 当前状态

阶段一至三已完成。用户可以对实体执行喂食/抚摸操作，实体拥有 4 阶段成长系统（幼年→少年→成年→老年），实体间可形成 friend/rival/mate 社交关系并影响行为决策。前端提供操作交互、成长进度可视化、蛛网式关系图谱等完整体验。后续将进入阶段四（背包与道具系统）。

---

## 2. 阶段规划总览

| 阶段 | 名称 | 周期 | 核心交付 | 状态 |
|------|------|------|----------|------|
| 一 | 用户交互深化 | 1 周 | 前端操作按钮 + 后端冷却/日志 | ✅ 已完成 |
| 二 | 实体成长与进化 | 2 周 | 年龄/成长阶段/经验值系统 | ✅ 已完成 |
| 三 | 社交关系网络 | 2 周 | 关系表 + 亲密度 + 社交行为 | ✅ 已完成 |
| 四 | 背包与道具系统 | 2 周 | 道具表 + 背包 + 使用机制 | 待实施 |
| 五 | 个性化与高级玩法 | 3 周 | 命名/装扮/性格/成就/对话 | 待实施 |

---

## 3. 阶段一：用户交互深化 ✅ 已完成

**目标**：前端对接 `POST /api/life/action` 端点，用户可以操作实体，并获得视觉和事件反馈。

**实现摘要**：
- 实体详情页添加喂食🍖/抚摸🤚按钮，地图长按弹出操作菜单（查看详情/喂食/抚摸）
- 操作反馈动画：喂食 ❤️ 上浮、抚摸 ✨ 上浮，持续 1.2s 后自动消失
- 操作含冷却限制，冷却中返回 429 HTTP 响应
- 前端冷却温和提示（琥珀色倒计时 vs 红色提示）
- 操作事件在事件流中以 `user_` 前缀显示，带对应图标
- 首次连接 Loading 态

### 3.1 实体详情页添加操作按钮（喂食🍖、抚摸🤚）

- **工作量**: 中
- **涉及文件**:
  - `lib/pages/life/life_entity_detail.dart` — 在 `_StatBar` 列表下方添加操作按钮区域
  - `lib/providers/life_provider.dart` — 新增 `sendAction(entityId, action, params)` 方法，通过 HTTP 调用后端
  - `lib/services/life_ws_service.dart` — 新增 `sendLifeAction()` 静态方法（HTTP POST 到 `/api/life/action`）
- **修改内容**:
  - 详情页属性条下方增加两个圆角按钮：「🍖 喂食」「🤚 抚摸」
  - 按钮点击调用 `LifeProvider.sendAction(entity.id, 'feed', null)` / `'pet'`
  - 操作结果以 SnackBar 显示（成功："你喂了小花" / 失败："冷却中，请等待 X 秒"）
- **验收标准**: 点击喂食按钮后实体 Hunger 值在下一个 tick 广播中可见增长，SnackBar 提示操作结果

### 3.2 地图长按实体弹出操作菜单

- **工作量**: 中
- **涉及文件**:
  - `lib/widgets/life/life_world_map.dart` — 在 `onEntityTap` 回调基础上增加 `onEntityLongPress`
  - `lib/pages/life/life_world_page.dart` — `LifeWorldMap` 的 `onEntityTap` 改为长按弹出 `BottomSheet` 操作菜单
  - `lib/widgets/life/life_entity_sprite.dart` — 添加 `onLongPress` 手势检测
- **修改内容**:
  - 长按实体弹出底部菜单（`showModalBottomSheet`），包含：查看详情、喂食、抚摸、移动到此处
  - 「移动到此处」进入拖拽模式，用户点击地图某处发送 `move` 操作（params: `{x, y}`）
- **验收标准**: 长按实体弹出菜单，各操作可正常触发并反馈结果

### 3.3 操作反馈动画

- **工作量**: 小
- **涉及文件**:
  - `lib/widgets/life/life_entity_sprite.dart` — 添加浮动 emoji 动画叠加层
  - `lib/pages/life/life_entity_detail.dart` — 按钮点击后触发反馈动画
- **修改内容**:
  - 喂食时实体上方浮动 ❤️ 动画（`AnimatedPositioned` + `FadeTransition`，持续 1.2s）
  - 抚摸时实体上方浮动 ✨ 动画
  - 详情页按钮点击后按钮短暂缩放（`ScaleTransition`）
- **验收标准**: 操作后 1 秒内可见浮动 emoji 动画，动画结束后自动消失

### 3.4 操作冷却机制

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/engine.go` — `ApplyUserAction` 方法增加冷却校验
  - `backend/internal/biz/life/types.go` — 新增 `ActionCooldown` 常量和冷却记录结构
  - `lib/providers/life_provider.dart` — 前端侧维护 `_cooldownUntil` Map，操作前预检
- **修改内容**:
  - 后端 `LifeEngine` 新增 `actionCooldowns map[uint]time.Time` 字段，记录每个实体上次操作时间
  - `ApplyUserAction` 开头检查：`now < cooldown[entityID]` 则返回 `{Success: false, Message: "冷却中，请等待 X 秒"}`
  - 冷却时长：`const actionCooldownSec = 5`（5 秒）
  - 前端 `_cooldownUntil` Map 做预检，冷却中按钮置灰并显示倒计时
- **验收标准**: 5 秒内重复操作返回冷却提示，前端按钮显示倒计时，冷却结束后自动恢复可用

### 3.5 操作事件显示在事件流中

- **工作量**: 小
- **涉及文件**:
  - `lib/widgets/life/life_event_feed.dart` — 事件流渲染增加用户操作类型图标
  - `lib/models/life_state.dart` — `LifeEvent.type` 已支持 `user_feed`/`user_pet` 等类型（后端已生成）
- **修改内容**:
  - 事件类型以 `user_` 前缀识别用户操作（后端 `ApplyUserAction` 已写入 `event_type: "user_"+action`）
  - `life_event_feed.dart` 中根据事件类型显示不同图标：`user_feed` → 🍖，`user_pet` → 🤚
  - 用户操作事件高亮显示（背景色加浅绿底）
- **验收标准**: 执行操作后，事件流 Tab 中出现带对应图标的用户操作事件，文案为 "小花 被用户喂食" 等

### 3.6 后端 action 端点增强

- **工作量**: 小
- **涉及文件**:
  - `backend/internal/biz/life/engine.go` — 添加冷却字段、增强事件日志
  - `backend/internal/server/protohttp/life/life.go` — `actionHandler` 返回冷却剩余时间
  - `backend/internal/biz/life/types.go` — `ActionResult` 增加 `CooldownRemaining` 字段
- **修改内容**:
  - `ActionResult` 增加 `CooldownRemaining int` 字段（秒数）
  - `actionHandler` 在冷却中返回 `429 Too Many Requests` 而非 `400`
  - 事件日志 `Description` 字段已包含 `"小花 被用户喂食"`（现有逻辑），无需修改
- **验收标准**: 冷却中调用返回 429 + 剩余秒数，正常操作返回 200 + 实体最新状态

---

## 4. 阶段二：实体成长与进化系统 ✅ 已完成

**目标**：实体随时间成长，有阶段性外观变化和属性上限差异，引入自然寿命机制。

**实现摘要**：
- 4 阶段成长系统：幼年（baby）→少年（juvenile）→成年（adult）→老年（elder），经验积累触发阶段转换
- 属性上限/衰减随阶段修正：幼年上限×0.7、老年衰减×1.5
- 老年自然死亡机制（`is_alive` 软删除），仅成年阶段可繁殖
- mate 关系繁殖概率翻倍
- 后端 `growth.go` 封装成长阶段逻辑
- 前端：成长阶段标签、经验进度条、年龄显示、精灵大小/透明度随阶段变化
- 成长事件金色高亮显示

### 4.1 数据模型扩展：年龄、成长阶段、经验值

- **工作量**: 大
- **涉及文件**:
  - `backend/model/life_entity.go` — 新增字段
  - `backend/model/life_world.go` — 无需修改
  - `backend/internal/biz/life/types.go` — `EntityDiff` 新增成长阶段字段
  - `lib/models/life_state.dart` — `LifeEntity` 新增对应字段
- **字段设计**:

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `age_ticks` | `int64` | `0` | 实体存活的 tick 数 |
| `growth_stage` | `string` | `"baby"` | 成长阶段：`baby`/`juvenile`/`adult`/`elder` |
| `experience` | `int64` | `0` | 累积经验值 |
| `birth_tick` | `int64` | `0` | 诞生时的世界 tick 计数 |
| `max_age_ticks` | `int64` | `8640` | 自然寿命上限（约 12 小时 @5s/tick） |

- **修改内容**:
  - `LifeEntity` 结构体新增 5 个字段，GORM tag 含 `default` 值
  - `EntityDiff` 新增 `GrowthStage string` 和 `AgeTicks int64` 字段
  - 前端 `LifeEntity` 新增 `growthStage`、`ageTicks`、`experience` 字段及 JSON 解析
  - AutoMigrate 自动添加列（GORM 已有机制）
- **验收标准**: 数据库表自动新增字段，WebSocket 广播包含成长阶段信息

### 4.2 成长阶段设计

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/types.go` — 定义阶段常量和属性倍率
  - `backend/internal/biz/life/behavior.go` — `decayAttributes` 中根据阶段调整衰减率和上限
- **阶段设计**:

| 阶段 | 标识 | 经验阈值 | 属性上限倍率 | 衰减倍率 | 外观变化 |
|------|------|----------|-------------|---------|----------|
| 幼年 | `baby` | 0 | ×0.7 | ×1.2 | 原始 emoji + 🍼 后缀 |
| 少年 | `juvenile` | 500 | ×0.85 | ×1.0 | 原始 emoji |
| 成年 | `adult` | 2000 | ×1.0 | ×1.0 | 原始 emoji + ✦ 装饰 |
| 老年 | `elder` | 5000 | ×0.8 | ×1.5 | 原始 emoji + 🧓 后缀 |

- **修改内容**:
  - 新增 `growthStageConfig` map，存储每阶段的阈值、属性倍率、衰减倍率
  - `decayAttributes` 函数签名改为 `decayAttributes(e *model.LifeEntity, stage string)`，老年阶段 `hungerDecayRate × 1.5`
  - 幼年阶段 Hunger 上限为 70（100×0.7），老年阶段 Mood 衰减加速
- **验收标准**: 不同阶段实体属性衰减速度不同，老年实体更快饥饿和疲惫

### 4.3 经验系统与成长触发

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/tick.go` — `RunLifeTick` 循环内新增经验累积和成长判定逻辑
  - `backend/internal/biz/life/engine.go` — 新增 `checkGrowth` 辅助函数
- **修改内容**:
  - 每个 tick 结束后，存活实体 `experience += 1`，`age_ticks += 1`
  - 检查 `experience` 是否达到下一阶段阈值，触发 `GrowthStage` 变更
  - 成长时生成 `EventType: "growth"` 事件：`"小花 成长为少年阶段！"`
  - 检查 `age_ticks >= max_age_ticks`，触发自然死亡（同 `shouldDie` 路径）
  - 用户操作（feed/pet）额外奖励经验：feed +5，pet +3
- **验收标准**: 实体持续存活后经验累积，达到阈值时自动升级并产生事件日志

### 4.4 外观变化

- **工作量**: 小
- **涉及文件**:
  - `lib/widgets/life/life_entity_sprite.dart` — 根据 `growthStage` 渲染不同视觉
  - `lib/pages/life/life_entity_detail.dart` — 大号头像区域显示阶段装饰
- **修改内容**:
  - `life_entity_sprite.dart` 中根据 `entity.growthStage` 在 emoji 旁叠加装饰图标
  - `baby` → emoji 缩小显示 + 🍼 角标
  - `adult` → 正常大小 + 底部 ✦ 光晕
  - `elder` → 略透明 + 🧓 角标
  - 详情页头像容器边框颜色随阶段变化（baby=粉、adult=金、elder=灰）
- **验收标准**: 不同成长阶段实体在地图和详情页有明显视觉区分

### 4.5 寿命机制

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/behavior.go` — `shouldDie` 增加寿命判定
  - `backend/internal/biz/life/ecology.go` — `maybeSpawnOffspring` 中仅允许 `adult` 阶段繁殖
- **修改内容**:
  - `shouldDie` 新增判定：`age_ticks >= max_age_ticks` 返回 `true`
  - 老年阶段（`elder`）：`age_ticks > max_age_ticks * 0.75` 后，每 tick 有 2% 概率自然死亡
  - 繁殖条件增加 `growth_stage == "adult"` 校验（当前仅检查属性阈值）
  - 死亡事件 Description 区分死因：`"生态压力消亡"` vs `"寿终正寝"`
- **验收标准**: 老年实体有概率自然死亡，仅成年实体可繁殖，死亡事件文案区分死因

### 4.6 前端成长进度条 + 成长动画

- **工作量**: 中
- **涉及文件**:
  - `lib/pages/life/life_entity_detail.dart` — 属性条上方新增成长进度区域
  - `lib/widgets/life/life_entity_sprite.dart` — 成长升级时的粒子动画
- **修改内容**:
  - 详情页 emoji 头像下方增加成长进度条：显示当前经验 / 下一阶段阈值
  - 进度条使用 `LinearProgressIndicator`，标注 "幼年 → 少年 (320/500)"
  - 升级触发时，精灵图播放缩放 + 闪烁动画（`AnimationController` 2s）
  - 事件流中出现升级事件时自动滚动到顶部
- **验收标准**: 详情页可见成长进度，升级时有动画反馈

### 4.7 成长事件记录 + 通知

- **工作量**: 小
- **涉及文件**:
  - `backend/internal/biz/life/tick.go` — 成长事件已写入 `LifeEventLog`（4.3 中实现）
  - `lib/providers/life_provider.dart` — 新增 `growthEvents` getter 过滤成长类事件
- **修改内容**:
  - 后端：成长事件 `EventType: "growth"`，`Description: "小花 从幼年成长为少年！"`
  - 前端：`LifeProvider` 新增 `List<LifeEvent> get growthEvents` 过滤 `type == "growth"` 的事件
  - 世界页面增加成长事件通知横幅（`Dismissible` 横幅，3 秒后自动消失）
- **验收标准**: 实体成长时世界页面出现通知横幅，事件流可筛选查看成长历史

---

## 5. 阶段三：社交关系网络 ✅ 已完成

**目标**：实体间建立关系（朋友/对手/伴侣），关系影响行为决策，前端可视化关系图谱。

**实现摘要**：
- `life_relationships` 数据表（entity_id, target_id, relation_type, affinity 等）
- friend/rival/mate 三种关系类型，亲密度 0-100
- 亲密度机制：同区域实体自动积累、距离过远衰减、竞争行为触发 rival
- 关系影响行为决策：趋向朋友、远离对手
- mate 关系繁殖概率翻倍
- 后端 `social.go` 封装社交关系逻辑
- `GET /api/life/relationships` REST API
- 前端蛛网式关系可视化页面（SpiderWebPainter + 力导向布局 + InteractiveViewer）
- 社交事件绿色高亮显示

### 5.1 数据模型：life_relationships 表

- **工作量**: 大
- **涉及文件**:
  - `backend/model/` — 新建 `life_relationship.go`
  - `backend/internal/biz/life/store.go` — `Store` 接口新增关系 CRUD 方法
  - `backend/internal/data/life/store.go` — GORM 实现
  - `backend/internal/biz/life/types.go` — 新增关系类型常量
- **表设计**:

```go
// model/life_relationship.go
type LifeRelationship struct {
    ID           uint      `json:"id" gorm:"primaryKey"`
    WorldID      string    `json:"world_id" gorm:"size:64;not null;index:idx_life_rel_world"`
    EntityID     uint      `json:"entity_id" gorm:"not null;index:idx_life_rel_entity"`
    TargetID     uint      `json:"target_id" gorm:"not null;index:idx_life_rel_target"`
    RelationType string    `json:"relation_type" gorm:"size:16;not null"` // friend/rival/mate
    Affinity     float64   `json:"affinity" gorm:"default:50"`           // 0-100 亲密度
    CreatedAt    time.Time `json:"created_at"`
    UpdatedAt    time.Time `json:"updated_at"`
}
func (LifeRelationship) TableName() string { return "life_relationships" }
```

- **关系类型常量**:

```go
const (
    RelationFriend = "friend"
    RelationRival  = "rival"
    RelationMate   = "mate"
)
```

- **验收标准**: `AutoMigrate` 创建 `life_relationships` 表，支持通过 Store 接口 CRUD

### 5.2 亲密度系统

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/` — 新建 `social.go`，封装亲密度计算逻辑
  - `backend/internal/biz/life/tick.go` — tick 循环中调用亲密度更新
- **修改内容**:
  - 每个 tick 检测实体间距离（欧几里得距离 < 100），同区域实体 `affinity += 0.5`
  - 用户同时对两个实体执行操作（先后 feed 两个实体），增加它们之间的 affinity `+2`
  - Affinity > 80 自动升级为 `friend` 关系
  - Affinity < 20 且有竞争行为（争抢同一格食物）升级为 `rival`
  - 两个 `adult` 阶段 `friend` 关系且 Affinity > 90 可升级为 `mate`
- **验收标准**: 长时间在同一区域的实体自动建立 friend 关系，关系类型和亲密度可查询

### 5.3 行为决策增强

- **工作量**: 大
- **涉及文件**:
  - `backend/internal/biz/life/behavior.go` — `decideAction` 增加社交权重
  - `backend/internal/biz/life/social.go` — 新增 `socialInfluence` 函数
- **修改内容**:
  - `decideAction` 签名改为 `decideAction(e *model.LifeEntity, relationships []LifeRelationship) LifeAction`
  - 有 `friend` 关系的实体倾向移动到朋友附近（`ActionWalking` 目标偏移向朋友坐标）
  - 有 `rival` 关系的实体互相回避（距离 < 80 时触发 `ActionWandering` 远离）
  - `mate` 关系实体属性互相加成（Mood 衰减减半）
  - `ActionTalking` 触发条件：与 `friend` 距离 < 60 时概率提升至 30%
- **验收标准**: 朋友实体在地图上呈现聚集行为，对手实体互相远离

### 5.4 社交事件

- **工作量**: 小
- **涉及文件**:
  - `backend/internal/biz/life/social.go` — 生成社交事件
  - `backend/internal/biz/life/tick.go` — 收集并广播社交事件
- **修改内容**:
  - 新增事件类型：`make_friend`（"小花和时雨成为了朋友！"）、`rivalry`（"团子和啾啾发生了争吵"）、`bonding`（"小花和时雨结伴同行"）
  - 社交事件通过 `EventDiff` 广播，`EventType` 以 `social_` 前缀
- **验收标准**: 关系变化时产生对应事件，前端事件流可见

### 5.5 前端关系图谱展示

- **工作量**: 大
- **涉及文件**:
  - `lib/pages/life/` — 新建 `life_relations_page.dart`
  - `lib/pages/life/life_entity_detail.dart` — 增加关系 Tab
  - `lib/models/life_state.dart` — 新增 `LifeRelationship` 模型
  - `lib/providers/life_provider.dart` — 持有关系数据
  - `backend/internal/server/protohttp/life/life.go` — 新增 `GET /api/life/relationships` 端点
- **修改内容**:
  - 新页面使用 `CustomPaint` 绘制关系图谱：实体为节点，关系为连线
  - 连线颜色和样式区分关系类型：friend=绿色实线、rival=红色虚线、mate=粉色双线
  - 连线上标注亲密度数值
  - 详情页增加「关系」Tab，列出该实体的所有关系
  - 后端新增 REST 端点返回关系列表
- **验收标准**: 关系图谱页面正确渲染实体间关系，节点可点击跳转详情

### 5.6 用户查看和管理实体关系

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/server/protohttp/life/life.go` — 新增 `POST /api/life/relationship/action`
  - `lib/pages/life/life_relations_page.dart` — 关系管理 UI
- **修改内容**:
  - 后端支持：促进关系（两个实体 affinity +10）、疏远关系（affinity -10）
  - 前端：关系详情页提供「促进友谊」「制造矛盾」按钮
  - 操作有冷却（10 秒）
- **验收标准**: 用户可干预实体关系，操作后亲密度实时更新

---

## 6. 阶段四：背包与道具系统（2 周）

**目标**：用户拥有道具背包，可给实体使用道具产生效果，道具通过签到和成就获取。

### 6.1 数据模型：道具表 + 背包表

- **工作量**: 大
- **涉及文件**:
  - `backend/model/` — 新建 `life_item.go`、`life_inventory.go`
  - `backend/internal/biz/life/store.go` — Store 接口新增道具/背包方法
  - `backend/internal/data/life/store.go` — GORM 实现
- **表设计**:

```go
// model/life_item.go
type LifeItem struct {
    ID          uint    `json:"id" gorm:"primaryKey"`
    Name        string  `json:"name" gorm:"size:64;not null"`
    Emoji       string  `json:"emoji" gorm:"size:16"`
    ItemType    string  `json:"item_type" gorm:"size:16;not null"` // food/toy/medicine/decoration
    Description string  `json:"description" gorm:"size:256"`
    EffectKey   string  `json:"effect_key" gorm:"size:32"`        // hunger/energy/mood
    EffectValue float64 `json:"effect_value" gorm:"default:0"`    // 效果数值
    Duration    int     `json:"duration" gorm:"default:0"`        // 持续 tick 数，0=即时
    Rarity      string  `json:"rarity" gorm:"size:16;default:common"` // common/rare/epic
}
func (LifeItem) TableName() string { return "life_items" }

// model/life_inventory.go
type LifeInventory struct {
    ID        uint      `json:"id" gorm:"primaryKey"`
    UserID    string    `json:"user_id" gorm:"size:64;not null;index:idx_life_inv_user"`
    ItemID    uint      `json:"item_id" gorm:"not null"`
    Quantity  int       `json:"quantity" gorm:"default:1"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}
func (LifeInventory) TableName() string { return "life_inventory" }
```

- **初始道具设计**:

| ID | 名称 | Emoji | 类型 | 效果 | 数值 | 持续 | 稀有度 |
|----|------|-------|------|------|------|------|--------|
| 1 | 普通饲料 | 🌾 | food | hunger | +15 | 0 | common |
| 2 | 高级粮食 | 🍖 | food | hunger | +30 | 3 | rare |
| 3 | 小玩具 | 🧸 | toy | mood | +20 | 0 | common |
| 4 | 精力药水 | ⚡ | medicine | energy | +40 | 0 | rare |
| 5 | 治愈药草 | 🌿 | medicine | hunger+energy+mood | +10 each | 5 | epic |
| 6 | 小帽子 | 🎩 | decoration | — | — | — | common |

- **验收标准**: 数据库自动创建表和种子道具数据

### 6.2 获取方式

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/` — 新建 `item.go`，封装道具业务逻辑
  - `backend/internal/server/protohttp/life/life.go` — 新增道具获取端点
- **修改内容**:
  - **签到奖励**：复用已有 `checkin` 模块，签到时随机发放 1-2 个 common 道具
  - **成就解锁**：阶段五成就系统完成后对接，暂时预留接口
  - **活动发放**：管理员通过 `POST /api/life/items/grant` 手动发放（管理台对接）
  - REST 端点：`GET /api/life/inventory` 查询背包，`POST /api/life/items/claim` 领取签到奖励
- **验收标准**: 签到后背包中出现道具，查询接口返回正确数量和类型

### 6.3 道具使用机制

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/engine.go` — 新增 `ApplyItem` 方法
  - `backend/internal/biz/life/item.go` — 道具效果应用逻辑
  - `backend/internal/server/protohttp/life/life.go` — `POST /api/life/action` 扩展或新增 `POST /api/life/use-item`
- **修改内容**:
  - 新增端点 `POST /api/life/use-item`，请求体：`{entity_id, item_id}`
  - 即时效果：直接修改实体属性（如 hunger +15）
  - 持续效果（`duration > 0`）：实体附加 `activeEffects []ActiveEffect` 内存结构，每 tick 应用一次效果，duration 递减至 0
  - 使用后背包 `quantity -= 1`，quantity=0 时删除记录
  - 装饰类道具：修改实体 `Emoji` 字段或附加 `accessory` 字段
- **验收标准**: 使用道具后实体属性立即或持续变化，背包数量正确扣减

### 6.4 前端背包 UI + 道具使用交互

- **工作量**: 大
- **涉及文件**:
  - `lib/pages/life/` — 新建 `life_inventory_page.dart`
  - `lib/models/life_state.dart` — 新增 `LifeItem`、`LifeInventoryItem` 模型
  - `lib/providers/life_provider.dart` — 新增背包状态管理
  - `lib/pages/life/life_entity_detail.dart` — 增加「使用道具」按钮
- **修改内容**:
  - 世界页面 AppBar 增加背包入口图标（🎒）
  - 背包页面：网格展示道具，每个格子显示 emoji + 名称 + 数量角标
  - 道具使用流程：点击道具 → 弹出实体选择列表 → 选择实体 → 确认使用
  - 详情页增加「🎒 道具」按钮，点击弹出可用道具列表
  - 持续效果图标：实体旁显示 buff 图标（如 ⚡ 闪烁表示精力药水中）
- **验收标准**: 背包 UI 流畅，道具使用完整流程可走通，持续效果可视化

### 6.5 道具商店（可选，优先级低）

- **工作量**: 大
- **涉及文件**:
  - `lib/pages/life/` — 新建 `life_shop_page.dart`
  - `backend/internal/server/protohttp/life/life.go` — 新增商店端点
- **修改内容**:
  - 商店页面展示可购买道具，使用虚拟货币（与 VIP/积分 系统对接）
  - 限时折扣、新品上架等运营机制
- **验收标准**: 可选交付，如时间紧张可推迟到后续迭代

---

## 7. 阶段五：个性化与高级玩法（3 周）

**目标**：深度个性化和情感连接，让每个实体独一无二。

### 7.1 实体命名/改名

- **工作量**: 小
- **涉及文件**:
  - `backend/internal/biz/life/engine.go` — 新增 `RenameEntity` 方法
  - `backend/internal/server/protohttp/life/life.go` — 新增 `POST /api/life/rename`
  - `lib/pages/life/life_entity_detail.dart` — 名称旁增加编辑按钮
- **修改内容**:
  - 后端：`RenameEntity(worldName, entityID, newName)` 更新缓存 + 持久化
  - REST：`POST /api/life/rename` 请求体 `{entity_id, name}`，名称长度限制 2-12 字符
  - 前端：详情页名称右侧增加 ✏️ 图标，点击弹出输入框
  - 改名事件：`"小花 被更名为 花酱"`
- **验收标准**: 用户可给实体自定义名称，名称在所有 UI 中实时更新

### 7.2 实体装扮

- **工作量**: 中
- **涉及文件**:
  - `backend/model/life_entity.go` — 新增 `accessory` 字段
  - `lib/widgets/life/life_entity_sprite.dart` — 渲染装饰叠加层
  - `lib/pages/life/life_entity_detail.dart` — 装扮选择 UI
- **修改内容**:
  - `LifeEntity` 新增 `Accessory string` 字段（存储装饰 emoji 或 ID）
  - 精灵图渲染时在 emoji 右下角叠加装饰（如 🎩、🎀、👓）
  - 装扮来源：装饰类道具（阶段四），使用后绑定到实体
- **验收标准**: 装饰类道具使用后实体外观可见变化

### 7.3 实体性格系统

- **工作量**: 大
- **涉及文件**:
  - `backend/model/life_entity.go` — 新增 `personality` 字段
  - `backend/internal/biz/life/` — 新建 `personality.go`
  - `backend/internal/biz/life/behavior.go` — `decideAction` 中注入性格权重
- **字段设计**:

```go
// personality 为 JSON 字符串，存储性格维度
// {"active": 0.7, "quiet": 0.3, "gluttonous": 0.5, "brave": 0.6}
Personality string `json:"personality" gorm:"size:256;default:'{}'"`
```

- **性格维度**:

| 维度 | 标识 | 影响 |
|------|------|------|
| 活泼 | `active` | `ActionWalking`/`ActionWandering` 概率 +20% |
| 安静 | `quiet` | `ActionIdle`/`ActionSleeping` 概率 +20% |
| 贪吃 | `gluttonous` | `ActionSeekingFood` 阈值从 26 提升至 40 |
| 勇敢 | `brave` | 危险区域 Mood 衰减减半 |

- **性格生成**:
  - 新生实体随机生成性格（每维度 0.0-1.0，总和归一化）
  - 用户互动历史微调性格：频繁喂食 → `gluttonous += 0.01`/tick，频繁抚摸 → `active += 0.005`
- **验收标准**: 不同性格实体表现出可观察的行为差异

### 7.4 性格影响行为决策

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/behavior.go` — `decideAction` 增加性格参数
  - `backend/internal/biz/life/personality.go` — 性格解析和权重计算
- **修改内容**:
  - `decideAction` 签名改为 `decideAction(e *model.LifeEntity, relationships []LifeRelationship, personality PersonalityTraits) LifeAction`
  - 各行为概率乘以性格权重
  - `applyAction` 中性格相关效果加成（勇敢实体在危险区域 Energy 衰减减半）
- **验收标准**: 活泼实体移动更频繁，安静实体更倾向停留

### 7.5 成就系统

- **工作量**: 大
- **涉及文件**:
  - `backend/model/` — 新建 `life_achievement.go`
  - `backend/internal/biz/life/` — 新建 `achievement.go`
  - `backend/internal/server/protohttp/life/life.go` — 新增 `GET /api/life/achievements`
  - `lib/pages/life/` — 新建 `life_achievements_page.dart`
- **表设计**:

```go
type LifeAchievement struct {
    ID          uint      `json:"id" gorm:"primaryKey"`
    UserID      string    `json:"user_id" gorm:"size:64;not null;index:idx_life_achv_user"`
    AchieveKey  string    `json:"achieve_key" gorm:"size:64;not null"`
    Name        string    `json:"name" gorm:"size:64"`
    Description string    `json:"description" gorm:"size:256"`
    UnlockedAt  time.Time `json:"unlocked_at"`
}
func (LifeAchievement) TableName() string { return "life_achievements" }
```

- **成就列表**:

| Key | 名称 | 条件 |
|-----|------|------|
| `first_feed` | 初次投喂 | 首次执行 feed 操作 |
| `first_pet` | 温柔抚摸 | 首次执行 pet 操作 |
| `growth_juvenile` | 茁壮成长 | 任一实体成长到少年 |
| `growth_adult` | 独当一面 | 任一实体成长到成年 |
| `make_friend` | 友谊之花 | 实体建立首个 friend 关系 |
| `survivor_100` | 百日生存 | 实体存活 100 tick |
| `full_belly` | 饱餐一顿 | 实体 Hunger 达到 100 |
| `collector_10` | 道具收藏家 | 背包拥有 10 种不同道具 |

- **验收标准**: 达成条件后自动解锁成就，前端成就页面展示已解锁和未解锁列表

### 7.6 LLM 对话（远期，依赖 AI 模块对接）

- **工作量**: 大
- **涉及文件**:
  - `backend/internal/biz/life/` — 新建 `dialogue.go`
  - `backend/internal/server/protohttp/life/life.go` — 新增 `POST /api/life/chat`
  - `lib/pages/life/life_entity_detail.dart` — 增加对话入口
- **修改内容**:
  - 实体详情页增加「💬 对话」按钮
  - 后端构造 prompt：包含实体性格、当前属性、最近事件，调用已有 AI 模块（`backend/api/ai/v1/`）
  - 对话上下文维护，每轮对话记录到 `life_event_logs`
  - 示例 prompt：`"你是名叫小花的兔子，性格活泼(0.7)，当前饥饿度45，心情80。用一句话回复用户。"`
- **验收标准**: 对话响应体现性格和当前状态差异（低 Hunger 会抱怨饿）
- **依赖**: 已有 LLM 服务稳定、prompt 工程调优

### 7.7 实体日记

- **工作量**: 中
- **涉及文件**:
  - `backend/internal/biz/life/` — 新建 `diary.go`
  - `backend/internal/server/protohttp/life/life.go` — 新增 `GET /api/life/diary?entity_id=X`
  - `lib/pages/life/life_entity_detail.dart` — 新增「📖 日记」Tab
- **修改内容**:
  - 每日（每 17280 tick ≈ 24h）自动生成日记摘要
  - 摘要内容：当日属性变化趋势、发生的关键事件、交互次数
  - 存储到 `life_event_logs`，`EventType: "diary"`
  - 前端日记 Tab 以时间线形式展示
- **验收标准**: 实体详情页可查看历史日记，日记内容反映当日真实活动

### 7.8 分享功能

- **工作量**: 中
- **涉及文件**:
  - `lib/pages/life/life_entity_detail.dart` — 增加分享按钮
  - `lib/utils/` — 复用已有截图/分享工具
- **修改内容**:
  - 详情页 AppBar 增加「📤 分享」按钮
  - 使用 `RepaintBoundary` 截取实体卡片区域
  - 生成分享卡片：emoji + 名字 + 属性 + 性格 + 成长阶段
  - 调用系统分享（`Share.share`）
- **验收标准**: 可生成实体卡片图片并通过系统分享发送

---

## 8. 技术债务与基础设施

贯穿所有阶段需持续维护：

### 8.1 Proto 定义补全

- **当前状态**: Life 域使用纯 REST（`protohttp/life/life.go` 手动注册路由），无 `.proto` 定义
- **计划**: 阶段二完成后补充 `backend/api/life/v1/life.proto`，定义消息类型和 RPC 服务
- **收益**: 统一 API 规范，自动生成客户端/服务端代码，OpenAPI 文档自动同步

### 8.2 单元测试覆盖

- **当前状态**: `backend/internal/biz/life/` 无测试文件
- **每阶段要求**:
  - 阶段一：`engine_test.go` — `ApplyUserAction` 冷却和操作逻辑
  - 阶段二：`behavior_test.go` — 成长阶段属性衰减、寿命判定
  - 阶段三：`social_test.go` — 亲密度计算、关系升级
  - 阶段四：`item_test.go` — 道具效果、背包扣减
  - 阶段五：`personality_test.go`、`achievement_test.go`
- **前端**: `test/` 目录新增 `life_provider_test.dart`、`life_state_test.dart`

### 8.3 WebSocket 鉴权

- **当前状态**: `ws_hub.go` 的 WebSocket 连接无鉴权，任何人可订阅
- **计划**: 阶段三前完成，连接时验证 JWT token（复用已有 `auth_service.dart` 和后端 auth 中间件）
- **实现**: `ws_hub.go` 的 `handleConnection` 中解析 `token` query 参数

### 8.4 性能监控

- **当前状态**: 无 tick 耗时监控
- **计划**: `tick.go` 中 `RunLifeTick` 入口/出口添加耗时日志
- **告警**: tick 耗时 > 5s（一个 tick 周期）时 `moelog.Warnf`
- **长期**: 实体数量 > 30 后考虑分片处理或降低非关键计算频率

### 8.5 数据迁移脚本管理

- **当前状态**: GORM AutoMigrate 处理表结构
- **计划**: 阶段二开始有复杂字段变更时，引入 `backend/cmd/migrate/` 版本化迁移脚本
- **规范**: 每次 schema 变更对应一个迁移文件 `001_add_growth_fields.sql`

---

## 9. 里程碑时间线

| 周次 | 阶段 | 核心任务 | 状态 |
|------|------|----------|------|
| **Week 1** | 阶段一 | 前端操作按钮、地图长按菜单、操作反馈动画、后端增强 | ✅ 已完成 |
| **Week 2-3** | 阶段二 | 数据模型扩展、成长阶段设计、经验系统、寿命机制、前端成长 UI | ✅ 已完成 |
| **Week 4-5** | 阶段三 | 关系表、亲密度系统、行为决策增强、社交事件、关系图谱 UI | ✅ 已完成 |
| **Week 6** | 阶段四（上） | 道具表、背包表、初始道具数据、获取机制 | 待实施 |
| **Week 7** | 阶段四（下） | 使用机制、持续效果、前端背包 UI、商店（可选） | 待实施 |
| **Week 8** | 阶段五（上） | 命名/改名、装扮、性格系统 | 待实施 |
| **Week 9** | 阶段五（中） | 成就系统、性格影响行为、实体日记 | 待实施 |
| **Week 10** | 阶段五（下） | LLM 对话（如有条件）、分享功能、全面测试 | 待实施 |

---

## 10. 风险与依赖

### 10.1 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Tick 性能瓶颈 | 实体增长到 50 后 tick 耗时超 5s | 阶段三引入分片处理，减少非关键计算频率；性能监控告警 |
| WebSocket 并发 | 多用户同时订阅广播压力大 | WS 鉴权限流，阶段四考虑房间分组广播 |
| GORM AutoMigrate 风险 | 生产环境自动迁移可能丢数据 | 阶段二起引入版本化迁移脚本，生产环境禁用 AutoMigrate |
| LLM 对话延迟 | 对话响应慢影响体验 | 流式输出、预生成常用回复、fallback 到模板对话 |
| 内存增长 | WorldCache 实体 Map + 关系列表内存占用 | 限制实体上限 50（已有），关系数量限制每实体 10 条 |

### 10.2 产品风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 实体死亡用户流失 | 用户精心养的实体死亡导致挫败感 | 提供「复活」道具（稀有），死亡前预警通知 |
| 互动深度不足 | 操作种类有限导致用户失去兴趣 | 阶段四道具系统提供多样化互动，阶段五 LLM 对话增加情感维度 |
| 数值平衡 | 属性衰减/恢复/成长速度不合理 | 每阶段上线前做数值模拟测试，预留配置化参数（`behavior.go` 常量） |

### 10.3 外部依赖

| 依赖 | 阶段 | 说明 |
|------|------|------|
| 签到模块 | 四 | 道具获取依赖 `checkin` 模块的签到事件回调 |
| AI/LLM 服务 | 五 | 实体对话依赖 `backend/api/ai/v1/` 已有 LLM 接口 |
| 用户系统 | 四/五 | 背包和成就需要 `user_id`，当前 Life 域无用户概念，需对接 `backend/api/user/v1/` |
| 管理台 | 四 | 道具发放需 `moe-admin/` 新增管理页面 |
| Flutter 分享插件 | 五 | 分享功能依赖 `share_plus` 包 |
