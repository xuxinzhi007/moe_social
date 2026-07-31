# Flame 小世界实验

> **日期**：2026-07-31  
> **状态**：实验中（`FeatureFlags.useFlameLifeWorld = true`）  
> **Skill**：`.cursor/skills/flame-life-world/SKILL.md`

## 背景

「TA 的世界」需要可持续演进的小世界观感；CustomPaint 网格舞台偏调试感。引入 Flame 做全屏舞台实验，Flutter 面板仍负责照料 HUD。

## 方案

- 渲染：`LifeFlameGame`（1280×720，相机跟随选中居民）
- 壳层：仍 `LifeWorldPage` + 底部可拖拽面板（方案 2）
- 回滚：`useFlameLifeWorld = false` → `LifeWorldMap`

## 影响范围

- `pubspec.yaml`：`flame`
- `lib/game/life/`、`life_world_page.dart`、`feature_flags.dart`

## 回滚

Flag 关闭即可；可保留依赖供后续迭代。
