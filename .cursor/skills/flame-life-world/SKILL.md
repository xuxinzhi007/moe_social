---
name: flame-life-world
description: >-
  Moe Social Flame 2D Life mini-world engine: architecture, camera pan/follow,
  DragCallbacks/TapCallbacks, GameWidget HUD shell, FeatureFlags.useFlameLifeWorld.
  Use whenever editing lib/game/life/**, LifeFlameGame, _ViewportPanLayer,
  LifeWorldPage Flame branch, syncEntities/syncRecentEvents, or the user mentions
  Flame, GameWidget, camera.follow, DragCallbacks, PanDetector, 小世界, TA的世界,
  拖地图, 镜头跟随, 2D地图, 世界渲染, flame引擎, 数字生命舞台.
---

# Flame Life World（2D 小世界引擎）

**改 Flame / TA 的世界舞台时：先读本文，再叠**  
[digital-life](../digital-life/SKILL.md) · [moe-flutter](../moe-flutter/SKILL.md) · [implementation-guardrails](../implementation-guardrails/SKILL.md)。

实验笔记：`docs/dev/flame-life-world-experiment.md`（非规范 SSOT；规范以本文为准）。

官方参考（实现以文档为准，勿臆造手势）：
- Gestures / Callbacks：https://docs.flame-engine.org/latest/flame/inputs/gesture_input.html  
- Camera / follow / viewport：https://docs.flame-engine.org/latest/flame/camera.html  

---

## Agent 工作流（必做）

```text
1. 读本文 §0–§3（边界 + 相机 + 输入）
2. 打开 lib/game/life/life_flame_game.dart 对照现实现
3. 改手势/相机前确认未触碰 §2「明确废弃」
4. 改完：热重启冒烟拖+点选；flutter analyze 相关文件
5. 大改坐标/缩放方案 → 先改本文再写代码
```

---

## 0. 产品定位（勿越界）

| 是 | 不是 |
|----|------|
| 「TA 的世界」**2D 舞台渲染** | 底栏主 Tab / 关系首页 |
| Life 居民可视化 + 轻照料入口 | 战斗、摇杆、排行、联机 |
| Companion **延伸** | 酒馆选卡 / 多会话大厅 |

决策：`docs/dev/ai-companion-formal-decisions.md`（决策 10/11）。  
地图点选 = Life 居民 ≠ Companion 多 bond。

---

## 1. 架构

```text
LifeProvider (状态 / WS tick)
    │ post-frame syncEntities / syncRecentEvents
    ▼
LifeFlameGame
    ├─ world: Ground + EntityMarker + EventBubble
    └─ camera.viewport: _ViewportPanLayer (DragCallbacks)
    │ onEntityTap / LongPress
    ▼
LifeWorldPage — GameWidget 全屏 + 薄 Sheet HUD
```

| 层 | 职责 | 禁止 |
|----|------|------|
| Game | 绘制、相机、命中、轻动画 | HTTP、业务校验、表单 |
| Page | Flag、照料/详情、Sheet | 每帧 `new LifeFlameGame` |
| Provider | 实体/事件 | import Flame 类型 |

**Flame = 视图，不是第二套业务引擎。**

---

## 2. 坐标与相机（锁定）

| 项 | 规范 |
|----|------|
| 世界 | **1280×720** 横屏逻辑坐标 |
| 实体 | `LifeEntity.x/y`，对齐旧 `LifeWorldCanvas` |
| zoom | 默认 **≈0.62**；竖屏 `onGameResize` 可抬高，保证宽高都有 ≥12% 可拖余量（否则 Y 被 clamp 成单点） |
| 拖拽层 | `camera.viewport` → `_ViewportPanLayer` + `DragCallbacks` |
| 平移公式 | `viewfinder.position += Vector2(-dx/zoom, -dy/zoom)` |
| 跟随 | `camera.follow(marker, maxSpeed: …)`；拖时 `camera.stop()` |
| 边界 | 按 viewport 尺寸 + zoom clamp |

### 明确废弃（回归即 BUG）

- ❌ Game 混用 `PanDetector`（或其它 Detector）+ 世界 `TapCallbacks` → **拖不动**
- ❌ Detector 体系（文档标将弃用）；新手势只用 **Callbacks**
- ❌ 「全图禁拖、放大才可拖」/ 拖一下自动放大解锁
- ❌ 惯性 + 软回弹 + 双指缩放一次上齐
- ❌ 每帧 `camera.moveBy` 堆 Effect（拖拽改 `viewfinder.position`）
- ❌ Page 上多 `AnimationController` 却用 `SingleTickerProviderStateMixin`

---

## 3. 输入（Callbacks only）

| 手势 | 实现 |
|------|------|
| 拖整屏 | viewport `_ViewportPanLayer.onDragUpdate` → `panByScreenDelta` + `stop` |
| 点居民 | marker `TapCallbacks` → `follow` + Page |
| 长按 | `LongPressCallbacks` → 详情 Page |
| Sheet | Flutter；勿让 Sheet 全屏抢 Game 手势（peek 以外应落到 GameWidget） |

viewport 层**不要**加 `TapCallbacks`（否则挡住世界点选）。

---

## 4. 同步与生命周期

1. `initState` 创建**一次** `LifeFlameGame`；随 Page dispose。
2. `addPostFrameCallback` → `syncEntities` + `syncRecentEvents(recentEvents.take(8))`。
3. follow 关闭时勿每 tick 强行 `follow`。
4. 禁止 `build` 里 `LifeFlameGame(...)`。
5. `useFlameLifeWorld == false` → `LifeWorldMap`，无红屏。

---

## 5. HUD 壳层

- `Stack`：`GameWidget` 铺底 + 薄 peek Sheet。
- 点选**不**自动抬高 Sheet。
- 照料/背包/关系网在 Flutter；Form 不进 Canvas。

---

## 6. 代码地图

| 路径 | 内容 |
|------|------|
| `lib/game/life/life_flame_game.dart` | `LifeFlameGame`、`_ViewportPanLayer`、Ground、Marker、气泡 |
| `lib/pages/life/life_world_page.dart` | Flag 分支、`GameWidget`、Sheet |
| `lib/constants/feature_flags.dart` | `useFlameLifeWorld` |
| `pubspec.yaml` | `flame`（可加官方生态小包；禁另引重型引擎） |

新文件放 `lib/game/life/`，命名 `life_*.dart`。

### 关键实现要点（对照源码）

```dart
// 平移（viewport DragCallbacks → screen delta）
final z = camera.viewfinder.zoom;
camera.viewfinder.position += Vector2(-dx / z, -dy / z);

// 跟随 / 停跟
camera.follow(marker, maxSpeed: 520);
camera.stop();
```

---

## 7. 编码规范

1. Game 类顶注释写清坐标与输入模型。  
2. `update(dt)` 只做动画；业务走 Page 回调。  
3. Marker `render` 保持轻；重效果独立 Component。  
4. 实验色可硬编码；收口再贴 `MoeTokens`。  
5. 改手势/相机后 **热重启** 冒烟（热重载不可靠）。  
6. `flutter analyze` 无 error。

---

## 8. 演进顺序

```text
P0 拖+点选+跟随+薄 HUD
P1 流畅表现（viewport 拖、follow、选中脉冲、地块、事件气泡）← 当前
P2 双指缩放（独立评审；用 ScaleCallbacks，勿混 PanDetector）
P3 更长世界/分区 —— 先改坐标 SSOT
```

未授权：摇杆、战斗、Flame 重写 Companion 聊天。

---

## 9. 验收

```text
- [ ] 已读本文 §0–§3；叠 digital-life
- [ ] 可拖地图、可点居民、follow/stop 正确
- [ ] 无 PanDetector+TapCallbacks 混用
- [ ] Flag false 回退 CustomPaint 正常
- [ ] 无每帧 new Game；无 Game HTTP
- [ ] analyze 通过；热重启冒烟
```
