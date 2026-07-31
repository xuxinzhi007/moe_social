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
1. 读本文 §0–§5（边界 + 相机 + 同步 + 照料 + 临时物）
2. 打开 lib/game/life/life_flame_game.dart + life_world_page.dart 对照现实现
3. 改手势/相机/同步前确认未触碰 §2 / §10「明确废弃」
4. 改完：热重启冒烟（拖地图 + 点选 + 喂食/陪伴）；dart analyze 相关文件
5. 大改坐标/缩放/相机模型 → 先改本文再写代码
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

## 1. 架构（当前）

```text
LifeProvider (状态 / WS tick)
    │ addListener → Page._pushFlameSync
    ▼
LifeFlameGame
    ├─ world: Ground + EntityMarker + LooseProp + EventBubble
    └─ camera.viewport: _ViewportPanLayer (DragCallbacks)
    │ onEntityTap / LongPress
    ▼
LifeWorldPage — GameWidget 全屏 + 手游 HUD（底栏 + FAB + 半高 Modal）
```

| 层 | 职责 | 禁止 |
|----|------|------|
| Game | 绘制、相机、命中、轻动画、临时物表现 | HTTP、业务校验、表单 |
| Page | Flag、照料 API、HUD/弹窗、**把 Provider 推给 Game** | 每帧 `new LifeFlameGame`；可拖满屏 Sheet 挡地图；在 `build` 里 sync |
| Provider | 实体/事件 | import Flame 类型 |

**Flame = 视图，不是第二套业务引擎。**

---

## 2. 坐标与相机（锁定）

| 项 | 规范 |
|----|------|
| 世界 | **1280×720** 横屏逻辑坐标 |
| 实体 | `LifeEntity.x/y`，对齐旧 `LifeWorldCanvas` |
| zoom | 默认 **≈0.62**；竖屏 `onGameResize` 抬高，保证宽高都有 ≥12% 可拖余量 |
| 拖拽层 | `camera.viewport` → `_ViewportPanLayer` + `DragCallbacks` |
| 平移公式 | `viewfinder.position += Vector2(-dx/zoom, -dy/zoom)` 再 clamp |
| 跟随 | **硬锁**：`update` 里角色移动之后 `viewfinder.position = clamp(marker.position)` |
| 亚像素 | 位移 &lt; 0.05 世界单位时不改 `viewfinder.position` |
| 拖时 | `_followSelected = false`；`_followedEntityId = null` |
| 角色移动 | 客户端**匀速**追服务端坐标（≈48 u/s）；服务端 `npcStep` 小步定向 |

### 关键实现要点

```dart
// 平移（viewport DragCallbacks → screen delta）
final z = camera.viewfinder.zoom;
camera.viewfinder.position = clamp(
  camera.viewfinder.position + Vector2(-dx / z, -dy / z),
);

// 跟随（硬锁；在 super.update 之后）
void _syncFollowCamera() {
  if (!_followSelected || _isPanning) return;
  final marker = _markers[_followedEntityId];
  if (marker == null) return;
  final next = _clampCamera(marker.position);
  // 亚像素忽略…
  camera.viewfinder.position = next;
}
```

### 明确废弃（回归即 BUG）

- ❌ `camera.follow(marker, maxSpeed: …)` 追赶 → **移动时整屏抖**
- ❌ 同一目标反复重绑 follow / 每 tick `camera.follow`
- ❌ Game 混用 `PanDetector` + 世界 `TapCallbacks` → **拖不动**
- ❌ Detector 体系；新手势只用 **Callbacks**
- ❌ 「全图禁拖、放大才可拖」/ 拖一下自动放大解锁
- ❌ 惯性 + 软回弹 + 双指缩放一次上齐
- ❌ 每帧 `camera.moveBy` 堆 Effect（拖拽只改 `viewfinder.position`）
- ❌ Page 上多 `AnimationController` 却用 `SingleTickerProviderStateMixin`

---

## 3. 输入（Callbacks only）

| 手势 | 实现 |
|------|------|
| 拖整屏 | viewport `_ViewportPanLayer.onDragUpdate` → `panByScreenDelta` |
| 点居民 | marker `TapCallbacks` → `notifyTap`（已跟随时**不**重绑镜头、**不**选中脉冲） |
| 长按 | `LongPressCallbacks` → 详情 Page |
| HUD | Flutter 固定底栏 + 侧 FAB；**点按钮**才出半高弹窗 |

viewport 层**不要**加 `TapCallbacks`（否则挡住世界点选）。

---

## 4. 同步与生命周期（锁定）

1. `initState` 创建**一次** `LifeFlameGame`；随 Page dispose。
2. **同步入口**：`LifeProvider.addListener(Page._pushFlameSync)` + 首帧一次 post-frame；选中变化时也可立刻 `_pushFlameSync`。
3. `_pushFlameSync` → `syncEntities` + `syncRecentEvents(take(8))`。
4. 禁止 `build` 里 `LifeFlameGame(...)`。
5. `useFlameLifeWorld == false` → `LifeWorldMap`，无红屏。

### 明确废弃

- ❌ 在 `Selector`/`build` 里 `addPostFrameCallback(syncEntities)`  
  → Provider 每 tick 重建会**叠回调**，和镜头一起抖。
- ❌ `syncEntities` 里每帧重绑镜头跟随。

---

## 5. HUD 壳层（手游式，锁定）

```text
Stack
├─ GameWidget / LifeWorldMap   ← 全屏舞台（主角）
├─ 顶栏：半透明玻璃（仅标题 + 联机点）
├─ 顶：轻量动态 Chip（点开弹窗）
├─ 左：FAB 背包 / 关系网络
├─ 右：FAB 居民(角标) / 动态 / 照料(低状态红点)
├─ 飘字：照料成功短提示（IgnorePointer）
└─ 底：Care HUD（迷你饱/精条 · 喂食 · 陪伴 · 更多）
```

- **禁止** `DraggableScrollableSheet` 常驻挡地图（竖滑与拖镜头冲突）。
- 点选居民只更新底栏选中态，**不**自动弹窗。
- 绑定 / 属性 / 心声 / 事件列表 → 半高 Modal（约 ≤58% 屏高），用完即关。
- Form 不进 Canvas；系统菜单（背包/关系）放侧栏 FAB。

---

## 6. 照料演出（锁定）

| 方法 | 何时 |
|---|---|
| `playCarePerformance(id, feed\|pet, line:)` | API 成功 → Marker 上画飞入食物/爱心 + 台词气泡 |
| `playBusyCareReply(id, action)` | 本地演出中再点 / 服务端冷却 → 角色台词，**禁止**系统冷却 SnackBar |
| `isCareBusy(id)` | 是否仍在吃/享受 |

### 喂食视觉规则

- 食物/爱心**只画在 Marker `render` 里**（飞入嘴边、爱心上浮）。
- ❌ **禁止**喂食成功时再 `world.add` 地上 prop / 角色旁掉落物  
  → 用户会看到「点一下喂食旁边多一个红点」，观感像 BUG。
- 有台词气泡时**不要**同时画状态 chip（避免叠字）。
- `syncRecentEvents`：**跳过** `user_feed` / `user_pet`；角色 `isCareBusy` / `hasSpeech` 时也不再飘世界气泡（避免「你喂了…」叠台词）。

---

## 7. 临时物 LooseProp（锁定）

用途：减轻世界空旷；纯客户端表现，**不走 HTTP**。

| 项 | 规范 |
|----|------|
| 生成 | 开局撒一批；之后定时生成，上限约 14 |
| 消失 | 寿命到期淡出；被捡起飞向角色后移除 |
| 交互 | 居民靠近：food→捡吃演出；shiny→夸一句；decor→拨弄淡出 |
| 绘制 | **Canvas 几何图形**（圆/星/蘑菇/石头） |

### 明确废弃

- ❌ 用 emoji `TextPainter` 画地上物 → 模拟器/部分 Android **缺字形变白块 X**
- ❌ 把「用户点喂食」和「地上刷食物」绑在一起（见 §6）

---

## 8. 代码地图

| 路径 | 内容 |
|------|------|
| `lib/game/life/life_flame_game.dart` | `LifeFlameGame`、`_ViewportPanLayer`、Ground、Marker、LooseProp、气泡 |
| `lib/pages/life/life_world_page.dart` | Flag、`GameWidget`、HUD、`_pushFlameSync` |
| `lib/constants/feature_flags.dart` | `useFlameLifeWorld` |
| `pubspec.yaml` | `flame`（可加官方生态小包；禁另引重型引擎） |

新文件放 `lib/game/life/`，命名 `life_*.dart`。

---

## 9. 编码规范

1. Game 类顶注释写清坐标与输入/跟随模型。  
2. `update(dt)` 只做动画与镜头硬锁；业务走 Page 回调。  
3. Marker `render` 保持轻；重效果独立 Component。  
4. 实验色可硬编码；收口再贴 `MoeTokens`。  
5. 改手势/相机后 **热重启** 冒烟（热重载不可靠）。  
6. `dart analyze` / `flutter analyze` 无 error。

---

## 10. 踩坑清单（必读，勿重复）

| 症状 | 根因 | 正确做法 |
|------|------|----------|
| 角色移动时整屏抖 | `camera.follow(maxSpeed:)` 追赶滞后 | 硬锁 `viewfinder.position` |
| 点选/tick 时抖 | `build` 里 post-frame `syncEntities` 叠回调 | Provider `addListener` → `_pushFlameSync` |
| 已选中再点「震一下」 | 重绑 follow + 选中脉冲 | 同目标不重绑、不播脉冲 |
| 喂食旁多红点/色块 | 喂食成功又 `spawnCareFoodNear` | 只做 Marker 飞入演出 |
| 地上物白块带 X | emoji 字体缺失 | Canvas 几何绘制 |
| 「你喂了…」叠台词 | 照料事件再飘世界气泡 | 跳过 `user_feed`/`user_pet`；有 speech 不飘 |
| 竖屏只能左右拖 | zoom 过小导致 Y clamp 成单点 | 竖屏抬高 zoom，留 ≥12% pan slack |

---

## 11. 演进顺序

```text
P0 拖+点选+跟随+薄 HUD
P1 流畅表现 + 手游 HUD + 照料演出 + 临时物 ← 当前
P2 双指缩放（独立评审；用 ScaleCallbacks，勿混 PanDetector）
P3 更长世界/分区 —— 先改坐标 SSOT
```

未授权：摇杆、战斗、Flame 重写 Companion 聊天。

---

## 12. 验收

```text
- [ ] 已读本文 §0–§7、§10；叠 digital-life
- [ ] 可拖地图、可点居民；跟随硬锁无抖
- [ ] 无 camera.follow(maxSpeed)；无 build 内 syncEntities
- [ ] 喂食只有 Marker 演出，角色旁不刷地上 prop
- [ ] 临时物 Canvas 绘制，无 emoji 白块
- [ ] Flag false 回退 CustomPaint 正常
- [ ] 无每帧 new Game；无 Game HTTP
- [ ] analyze 通过；热重启冒烟（拖+走+喂食）
```
