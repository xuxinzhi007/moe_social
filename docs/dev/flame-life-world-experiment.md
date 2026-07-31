# Flame 小世界实验

> **日期**：2026-07-31  
> **状态**：实验中（`FeatureFlags.useFlameLifeWorld = true`）  
> **引擎设计 / 开发规范 SSOT**：`.cursor/skills/flame-life-world/SKILL.md`

## 背景

「TA 的世界」需要可持续演进的小世界观感；CustomPaint 舞台偏调试感。引入 Flame 做全屏 2D 舞台；Flutter 负责薄 HUD 照料。

## 当前方案（手感锁定）

| 项 | 取值 |
|----|------|
| 世界 | 1280×720 横屏逻辑坐标 |
| 相机 | 默认 zoom≈0.62，竖屏按 viewport 抬高 zoom 保留上下可拖；`viewport` + `DragCallbacks`；点选 `follow`；拖后 `stop` |
| 壳层 | `LifeWorldPage` 全屏 Game + 底部薄 Sheet（方案 2） |
| 状态 | `LifeProvider` → `syncEntities`；Game 不 HTTP |
| 回滚 | `useFlameLifeWorld = false` → `LifeWorldMap` |

## 明确不做（已踩坑）

- `PanDetector` 混 `TapCallbacks`（拖不动）；全图禁拖 + 放大才可拖；惯性/软回弹一把梭——详见 skill §2。

## 影响范围

- `pubspec.yaml`：`flame`
- `lib/game/life/`、`life_world_page.dart`、`feature_flags.dart`

## 回滚

Flag 关闭即可；可保留依赖。变更相机/手势前先改 skill，再改代码。
