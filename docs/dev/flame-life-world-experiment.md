# Flame 小世界（TA 院子 v1）

> **日期**：2026-08-01  
> **状态**：**v1 院子竖切（可用演示）**（`FeatureFlags.useFlameLifeWorld = true`）  
> **引擎设计 / 开发规范 SSOT**：`.cursor/skills/flame-life-world/SKILL.md`  
> **竖切方案**：`docs/dev/ta-world-yard-v1.md`

## 背景

「TA 的世界」需要可持续演进的小世界观感；CustomPaint 舞台偏调试感。引入 Flame 做全屏 2D 舞台；Flutter 负责薄 HUD 照料。  
v1 收口为**绑定 TA 的小院子**成品竖切，停止用刷物/emoji 堆半成品。

## 当前方案（手感锁定）

| 项 | 取值 |
|----|------|
| 世界 | 1280×720 横屏逻辑坐标 |
| 场景 | Canvas 院子（丘/路/落脚垫/树丛/篱/小屋），无 LooseProp |
| 相机 | 默认院子中景；竖屏抬高 zoom；**硬锁**跟随；拖后停跟 |
| 角色 | 绑定 TA 主角；其他居民缩小+降透明 |
| 壳层 | 全屏 Game + 手游 HUD：玻璃顶栏、FAB、底栏照料 |
| 同步 | `LifeProvider.addListener` → `_pushFlameSync`（禁 build 内 sync） |
| 照料 | 仅 Marker Canvas 演出；禁喂食刷地上物 |
| 回滚 | `useFlameLifeWorld = false` → `LifeWorldMap` |

## 明确不做（已踩坑）

- `PanDetector` 混 `TapCallbacks`；`camera.follow(maxSpeed)` 追赶抖屏  
- build 里叠 `syncEntities`；定时刷地上物填空旷；emoji 地标缺字白块  
- 详见 skill §10。

## 影响范围

- `pubspec.yaml`：`flame`
- `lib/game/life/`、`life_world_page.dart`、`feature_flags.dart`

## 回滚

Flag 关闭即可；可保留依赖。变更相机/场景前先改 skill，再改代码。
