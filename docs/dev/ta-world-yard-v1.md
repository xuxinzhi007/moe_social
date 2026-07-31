# TA 的世界 · 院子成品竖切（v1）

> **日期**：2026-08-01  
> **状态**：已落地（可演示）  
> **引擎规范 SSOT**：`.cursor/skills/flame-life-world/SKILL.md`  
> **产品决策**：`docs/dev/ai-companion-formal-decisions.md`（决策 10/11）

## 背景

Flame「TA 的世界」一度偏实验沙盘：调试网格、emoji 地标、定时刷临时物、`camera.follow` 追赶导致抖屏。  
用户要求按**成品方向**做一小片竖切，而不是继续堆半成品系统。

## 方案

一句话：**进世界 = 站在绑定 TA 的小院子里喂/陪 TA**。

| 做 | 不做 |
|----|------|
| 固定 Canvas 院子构图 | 定时刷 LooseProp / 地上可捡玩法 |
| 绑定 TA 视觉主角，其他居民弱化 | 新 PNG/Spine/Live2D 流水线 |
| Marker 内照料演出 + 硬锁镜头 | `camera.follow(maxSpeed)`、build 内 sync |
| Provider listener → `_pushFlameSync` | HUD 大改版 / 战斗摇杆 |

## 影响范围

- `lib/game/life/life_flame_game.dart`
- `lib/pages/life/life_world_page.dart`
- `.cursor/skills/flame-life-world/SKILL.md`
- `docs/dev/flame-life-world-experiment.md`

## 迁移 / 使用

1. `FeatureFlags.useFlameLifeWorld == true`（默认实验 Flag 仍可关）。  
2. 热重启进入「TA 的世界」。  
3. 已绑定伙伴时应对焦 TA，名称带「· TA」。

## 回滚

- Flag 关闭 → `LifeWorldMap` CustomPaint。  
- 场景/镜头大改前先改 skill，再改代码。

## 验收

见 skill §12。
