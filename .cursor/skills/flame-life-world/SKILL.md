---
name: flame-life-world
description: >-
  Moe Social Flame 2D Life mini-world engine: TA yard v1, camera pan/hard-lock,
  DragCallbacks/TapCallbacks, GameWidget HUD shell, FeatureFlags.useFlameLifeWorld.
  Use whenever editing lib/game/life/**, LifeFlameGame, _ViewportPanLayer,
  LifeWorldPage Flame branch, syncEntities/syncRecentEvents, or the user mentions
  Flame, GameWidget, camera.follow, DragCallbacks, PanDetector, 小世界, TA的世界,
  拖地图, 镜头跟随, 2D地图, 世界渲染, flame引擎, 数字生命舞台, TA院子.
---

# Flame Life World（TA 的院子 · v1 成品竖切）

**改 Flame / TA 的世界舞台时：先读本文，再叠**  
[digital-life](../digital-life/SKILL.md) · [moe-flutter](../moe-flutter/SKILL.md) · [implementation-guardrails](../implementation-guardrails/SKILL.md)。

方案记录：`docs/dev/ta-world-yard-v1.md`  
状态笔记：`docs/dev/flame-life-world-experiment.md`（以本文为准）。

官方参考：
- Gestures：https://docs.flame-engine.org/latest/flame/inputs/gesture_input.html  
- Camera：https://docs.flame-engine.org/latest/flame/camera.html  

---

## Agent 工作流（必做）

```text
1. 读本文 §0–§7、§10（院子成品 + 相机 + 同步 + 照料）
2. 打开 life_flame_game.dart + life_world_page.dart 对照
3. 禁止触碰 §2 / §7 / §10「明确废弃」
4. 改完：热重启（拖 + 走 + 喂食）；dart analyze
5. 大改坐标/场景模型 → 先改本文再写代码
```

---

## 0. 产品定位（勿越界）

| 是 | 不是 |
|----|------|
| 绑定 TA 的**小院子舞台** | 游戏大厅 / 调试沙盘 |
| 院子构图 + 轻照料 | 刷地上物填空旷 |
| Companion **延伸** | 酒馆选卡 / 多会话 |

决策：`docs/dev/ai-companion-formal-decisions.md`（10/11）。  
一句话：**进世界 = 站在 TA 院子里喂/陪 TA**。

---

## 1. 架构（v1）

```text
LifeProvider
    │ addListener → Page._pushFlameSync
    ▼
LifeFlameGame
    ├─ world: YardGround + EntityMarker(+bound) + EventBubble
    └─ camera.viewport: _ViewportPanLayer
    ▼
LifeWorldPage — 全屏 Game + 手游 HUD
```

| 层 | 职责 | 禁止 |
|----|------|------|
| Game | 院子绘制、相机硬锁、命中、Marker 照料演出 | HTTP、刷临时物、业务校验 |
| Page | Flag、绑定 ID→Game、照料 API、HUD | `build` 里 sync；每帧 new Game |
| Provider | 实体/事件 | import Flame |

---

## 2. 坐标与相机（锁定）

| 项 | 规范 |
|----|------|
| 世界 | **1280×720** |
| 默认镜头 | 院子中景 `yardFocus ≈ (640, 430)` |
| zoom | ≈0.62；竖屏抬高，≥12% pan slack |
| 拖拽 | viewport `DragCallbacks`；`position += (-dx,-dy)/zoom` + clamp |
| 跟随 | **硬锁** `viewfinder = clamp(marker)`；`anchor ≈ (0.5, 0.34)` 角色偏上躲开底栏 |
| Marker 绘制 | 弱化用 `saveLayer` 时 rect **必须盖住台词气泡**（禁半径 80 小圆，会裁成线+三角） |
| 亚像素 | Δ&lt;0.05 不改 position |
| 角色移动 | 客户端匀速 ≈48 u/s；服务端 `npcStep` 小步 |

### 明确废弃

- ❌ `camera.follow(maxSpeed:)` → 移动整屏抖  
- ❌ 同目标反复重绑 / 每 tick follow  
- ❌ `PanDetector` + TapCallbacks  
- ❌ 用随机刷物 / emoji 铺地填空旷  

---

## 3. 输入

| 手势 | 实现 |
|------|------|
| 拖地图 | `_ViewportPanLayer` → 停跟 |
| 点居民 | `notifyTap`；已跟随时不脉冲、不重绑 |
| 长按 | 详情 |
| HUD | 底栏喂食/陪伴；半高 Modal |

viewport **勿**加 TapCallbacks。

---

## 4. 同步

1. `initState` 一次创建 Game。  
2. `LifeProvider.addListener(_pushFlameSync)` + 首帧一次；绑定加载后也 `_pushFlameSync`。  
3. `_pushFlameSync`：`setBoundEntityId` → `syncEntities` → `syncRecentEvents(take(8))`。  
4. ❌ 禁止 `build` / Selector 内 `addPostFrameCallback(sync…)`。

---

## 5. 院子场景（锁定）

`_LifeWorldGround` 固定构图（纯 Canvas）：

天空渐变 → 远丘 → 近草 → 弧形小路 → 宅前落脚垫 → 树丛/灌木 → 矮篱 → 小屋剪影 → 轻云  

- 禁止 emoji 地标、调试网格当主视觉、定时刷 LooseProp。  
- 空旷感用**构图**解决，不用玩法堆料。

---

## 6. 绑定 TA 视觉（锁定）

| | 绑定 TA | 其他居民 |
|--|---------|----------|
| 尺寸 | 正常 | ≈0.78 |
| 透明度 | 1.0 | ≈0.52 |
| 标识 | 名称后缀「· TA」+ 粉光晕 | 弱化；状态 chip 仅选中时 |
| priority | 28 | 18 |

`LifeFlameGame.setBoundEntityId` + Page 传入 `companion.lifeEntityId`。

---

## 7. 照料（锁定）

| API | 何时 |
|-----|------|
| `playCarePerformance` | 成功 → **仅 Marker** Canvas 飞入食物/爱心 + 台词 |
| `playBusyCareReply` | 忙/冷却 → 角色台词；禁止系统冷却 SnackBar |
| `isCareBusy` | 连点判断 |

### 明确废弃

- ❌ 喂食成功 `world.add` 地上 prop / 角色旁掉落色块  
- ❌ 照料事件再飘「你喂了…」（跳过 `user_feed`/`user_pet`）  
- ❌ 台词与状态 chip 同时显示  

---

## 8. 代码地图

| 路径 | 内容 |
|------|------|
| `lib/game/life/life_flame_game.dart` | Game、院子 Ground、Marker、气泡 |
| `lib/pages/life/life_world_page.dart` | HUD、`_pushFlameSync`、`setBoundEntityId` |
| `lib/constants/feature_flags.dart` | `useFlameLifeWorld` |
| `docs/dev/ta-world-yard-v1.md` | 本竖切方案 |

---

## 9. 编码规范

1. 顶注释写清院子 + 硬锁跟随。  
2. `update` 只动画/镜头；业务走 Page。  
3. 场景与照料 FX 用 Canvas 几何，慎用 emoji（角色头像 emoji 除外）。  
4. 改相机/场景后 **热重启**。  
5. `dart analyze` 无 error。

---

## 10. 踩坑清单（必读）

| 症状 | 根因 | 正确做法 |
|------|------|----------|
| 移动整屏抖 | `camera.follow(maxSpeed)` | 硬锁 viewfinder |
| tick 抖 | build 里叠 syncEntities | Provider listener |
| 再点震一下 | 重绑 + 选中脉冲 | 同目标跳过 |
| 喂食旁红点 | 喂食刷地上 prop | 只 Marker 演出 |
| 地上白块 X | emoji 缺字形 | Canvas 几何 / 固定院子 |
| 叠字 | 照料事件 + 台词 | 跳过 feed/pet 飘字 |
| 竖屏只能左右拖 | zoom 过小 Y clamp | 抬高 zoom + slack |
| 像半成品沙盘 | 刷物填空 | **院子构图 + 围着 TA** |
| 台词被底栏挡住 | 角色居中偏下 | `viewfinder.anchor` 偏上（约 0.34） |
| 气泡只剩线+三角 | `saveLayer` 小圆裁掉气泡 | saveLayer rect 覆盖台词区，或绑定 TA 不 dim |

---

## 11. 演进

```text
v1 院子竖切（构图 + 绑定主角 + 照料）← 当前
P2 双指缩放（独立评审）
P3 更长世界 —— 先改坐标 SSOT
```

未授权：摇杆、战斗、地上可捡物玩法、LooseProp 复活、Flame 重写 Companion 聊天。

---

## 12. 验收

```text
- [ ] 首屏是院子中景，不是空沙盘
- [ ] 绑定 TA 主角；其他居民弱化
- [ ] 喂食/陪伴仅 Marker 演出，无旁侧色块
- [ ] 镜头硬锁不抖；可拖停跟
- [ ] 无 LooseProp / 定时刷物
- [ ] 文档与实现对齐；analyze 通过
```
