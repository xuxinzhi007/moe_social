# PRD — 星辉远征域（Arena 卡牌养成）

- **生成时间**：2026-10-14 · **层级**：P1 增强（Flag `arenaGamePrototype=true` 全量可玩） · **数据源**：代码事实反推
- **上级文档**：[moe-social-prd.md](./moe-social-prd.md) · **SSOT**：[../../dev/aurora-arena-ssot.md](../../dev/aurora-arena-ssot.md) · **下一阶段**：[../../dev/aurora-living-world-plan.md](../../dev/aurora-living-world-plan.md)

---

## 1. Summary

星辉远征是嵌在 Moe 内的横屏卡牌 PvE 养成壳，是当前**唯一游戏壳**（旧 Pet Life Sim/农场已删除）：大厅 / 小家 / 编队 / 爬塔·星砂回廊 / 召唤 / 图鉴 / 角色 / 战斗，统一横屏 + `_ArenaColors`。入口在 Companion Hub「星辉远征」，无新主 Tab，不替代 Feed/私信/Companion 关系首页。

## 2. Background & Problem

- **问题**：陪伴需要"一起做事"的载体——纯聊天关系会疲劳，养成玩法给关系一个共同投入的出口。
- **workaround**：独立卡牌游戏（与社交/陪伴完全割裂）。
- **边界**：完整养成只走 Arena；不与 Life 沙盘混用；英雄 AI 不出游戏边界（D1）。
- **不解决**：实时联机 PvP、多人协作（明确暂缓）。

## 3. Personas

主 persona：阿星（陪伴+养成双需求）。本域不为硬核数值策划玩家做——没有 PvP 天梯与竞技排行。

## 4. Goals & Success Metrics

| 指标 | 行为 | 目标值（建议） | 时间窗 |
| --- | --- | --- | --- |
| Arena 周活跃 | 周爬塔/召唤/送礼任一行为 | ≥ 50%（全体用户） | 90 天 |
| 爬塔留存 | 通关 ≥1 层用户的次日回访 | ≥ 60% | 60 天 |
| 召唤转化 | 星晶消耗中召唤占比 | ≥ 40% | 90 天 |
| VIP 每日结晶领取触达 | VIP 用户进入 Arena 触发每日到账 | ≥ 70% | 60 天 |

- **Anti-metric**：单日爬塔层数/肝度——不鼓励爆肝；训练/送礼下场 buff 开战清空的设计就是控节奏。
- **关键假设**（总 PRD 已述）：活世界化能显著提升回访——M1 验证前，Arena 按静态养成持续迭代。

## 5. Value Proposition

> 阿星终于可以和 TA 们一起"做点事"——编队、爬塔、收集、打扮，而不只是聊天，因为星辉把养成与陪伴放进了同一个家。

## 6. Solution & Feature Scope

### Story 6.1 — 大厅与小家养成 · P0

**功能描述**：大厅总览；小家内对英雄送礼 / 训练（产出下场 buff，开战清空）/ 出发；整卡皮肤（非部位换装）：`ArenaHeroSkin`，皮肤条选择，全场景立绘跟随。

**验收标准**：
- Given 小家送礼，When 完成，Then 好感与下场 buff 写入 `progress_json`，且开战后 buff 清空。
- Given 更换皮肤，When 保存（`PUT /api/arena/skin`），Then 大厅/编队/图鉴/战斗立绘同步。
- 持久化：皮肤写 `owned_heroes_json[].skin_id` + SharedPreferences 兜底。

**设计触点**：`lib/pages/arena/arena_page.dart` · 皮肤模型见 SSOT。
**关联后端**：`Arena.HomeGift/HomeTrain` · `PUT /api/arena/skin`。

### Story 6.2 — 编队 / 召唤 / 战斗 · P0

**功能描述**：编队（防抖自动保存 + 手动保存）；召唤消耗星晶（默认持有 6280，单次成本 = `SingleSummonCost`）；卡牌战斗含元素/特质字段与组合技结算。

**验收标准**：
- Given 编队变更，When 停止操作，Then 防抖自动保存 `formation_json`。
- Given 星晶不足，When 召唤，Then 明确提示且不扣减。
- Given 满足元素组合条件，When 战斗结算，Then 组合技正确触发（`biz/arena/usecase.go` 结算逻辑）。

**关联后端**：`Arena.SetFormation/SaveDeck/Summon` · `biz/arena/usecase.go`。

### Story 6.3 — 爬塔·星砂回廊 + 星晶经济 · P0

**功能描述**：重构后的爬塔：节点选择（最多同时选中 5 个 `MaxSelectedTowerNodes`）、通关奖励 `TowerClearReward`、塔层持久化 `tower_floor`；星晶贯穿养成/召唤/通关，VIP 每日到账（上海日补发，进 Arena 触发）。

**验收标准**：
- Given 通关胜利，When 结算，Then `tower_floor` 推进、星晶与奖励入账。
- Given 选中节点变化，When 停止操作，Then 防抖保存 `progress_json`。
- Given VIP 用户当日未发放，When 进入 Arena 拉取 state，Then 自动补发当日星辉结晶（非手动按钮）。

**设计触点**：`lib/pages/arena/arena_page.dart`（爬塔 L940、星晶 L722/1315/1709/1770）· `lib/pages/commerce/vip_benefit_catalog.dart`（L22-42/103）。
**关联后端**：`Arena.GetState/ClearTower` · `VipDailyCrystals` / `VipCrystalDay`（`biz/arena/usecase.go`）。

### Story 6.4 — 图鉴（英雄/卡牌双 Tab）· P0

**功能描述**：图鉴含英雄与卡牌双 Tab，卡牌含元素/特质信息；未获得项的展示规则统一 sanitize。

**验收标准**：图鉴数据经后端 sanitize（`biz/arena/usecase.go`），不泄漏未公开卡牌数值细节。

**设计触点**：`lib/game/arena/arena_card_catalog.dart` · `arena_combos.dart` · `arena_page.dart` L1299-1404。

### Story 6.5 — 营地预览（活世界 M1a）· P1 已落地

**功能描述**：小家「营地预览」入口，读取 Life 共享世界快照用 Flame 展示、点选居民与镜头对焦；仅验证导航/加载/渲染链路，不做英雄映射。

**验收标准**：Arena → 营地 → 返回链路稳定；不把旧居民伪装为英雄。

**设计触点**：`lib/pages/arena/arena_camp_preview_page.dart` · Flame 渲染引擎 `lib/game/life/`。

### 未列入本版（活世界 M1/M2，方案已定稿）

- M1 单英雄 MVP：旗舰英雄（立绘 + 官方角色卡 + 行为偏好表）+ 全屏营地页 + 小家闲聊（沉浸长文 ≤300 字，羁绊 ≥3 解锁）+ per-hero 记忆（(user_id, hero_id) 命名空间）+ 登录快进摘要。
- M2 全 roster：性格→行为偏好全表、世界事件/道具/importance 分级、小家内嵌世界视图、共享世界容量治理（营地分区）。
- 数据流闭环：life_event_logs 唯一事实源 → Hub 日常 / 聊天注入 / per-hero 记忆三处消费。

## 7. Constraints & Risks

- 约束：Flutter 原生 + 横屏，不拆 Godot/Unity；`biz/life` 保持独立包，Arena 接口消费（K7）；官方卡版本化，记忆不可变（K8）。
- 风险：① LLM 成本（K3 护栏：羁绊门槛 + ≤300 字 + 低频 tick）；② 共享世界人口（K4：MaxEntities + 营地分区预案）；③ 清档重开的用户感知（K5：内测期执行 + 公告）。

## 8. Release Approach

当前全量可玩。下一步严格按活世界 M1 范围执行（最小验证集），验证指标：解锁聊天用户送礼/训练频次变化、世界事件提及率。M1 不达标不启 M2。
