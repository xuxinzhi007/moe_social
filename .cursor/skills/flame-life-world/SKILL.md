---
name: flame-life-world
description: >-
  Flame-based Life mini-world rendering for Moe Social. Use when editing
  lib/game/life/, FeatureFlags.useFlameLifeWorld, LifeWorldPage Flame path,
  or when the user asks for Flame / 小世界引擎 / 全屏地图玩法演进.
---

# Flame Life World（实验）

叠用：[digital-life](../digital-life/SKILL.md) · [moe-flutter](../moe-flutter/SKILL.md) · [implementation-guardrails](../implementation-guardrails/SKILL.md)。

## 产品边界

- 底栏「AI伙伴」仍是**关系首页**；Flame 只渲染「TA 的世界」内舞台。
- 不做战斗/摇杆/排行；相机保持早期横屏手感：固定 zoom≈0.62、地面拖拽、点选跟随。
- 多 Companion 会话仍属 Companion 域；地图点选 = Life 居民，勿混成酒馆选卡。

## Flag

- `FeatureFlags.useFlameLifeWorld`：`true` → `GameWidget` + `LifeFlameGame`；`false` → `LifeWorldMap`（CustomPaint）。
- 回滚：把 Flag 设 `false`，无需删依赖。

## 代码位置

| 路径 | 职责 |
|------|------|
| `lib/game/life/life_flame_game.dart` | `LifeFlameGame` + 地面 + 实体 marker |
| `lib/pages/life/life_world_page.dart` | Flag 切换渲染；底部 `DraggableScrollableSheet` |
| `lib/constants/feature_flags.dart` | `useFlameLifeWorld` |

世界坐标：**1280×720**，与后端实体 `x/y`、旧 `LifeWorldCanvas` 对齐。

## 实现规则

1. **状态仍在 `LifeProvider`** — Flame 只可视化；禁止在 Game 里直接 HTTP。
2. **同步**：Flutter 侧 `syncEntities(entities, selectedId:)`；勿每帧 new `FlameGame`。
3. **相机**：固定缩放；`DragCallbacks` 在地面；拖后停跟随，点居民再跟随。
4. **HUD**：用 Flutter `Stack` 叠面板；不要把完整 Form 画进 Canvas。
5. **Ticker**：Flame 自带 game loop；Page 上若另有 `AnimationController`，仍遵守 moe-flutter §1.1。
6. **依赖**：只加 `flame`（或官方生态小包）；不为视觉再引重型引擎。

## 验收（改 Flame 路径必做）

```text
- [ ] Flag true：可拖地图、可点居民、点选后镜头跟随；拖后不强制拽回
- [ ] Flag false：回退 CustomPaint 地图，无红屏
- [ ] flutter analyze（touched）无 error
- [ ] 未把 Flame 挂进底栏主 Tab
```

## 不做（当前）

- 虚拟摇杆、战斗、房间切换 RPG
- 用 Flame 重写 Companion 聊天
- 无 Flag 的强切（破坏回滚）
