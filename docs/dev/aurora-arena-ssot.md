# 星辉远征（Arena）

## 产品边界

1. **星辉是唯一游戏壳**：大厅 / 小家 / 编队 / 爬塔 / 召唤 / 图鉴 / 角色 / 战斗，统一横屏 + `_ArenaColors`。
2. **换装 = 整卡皮肤**：角色立绘整张替换（类似皮肤），**不是**帽衣裤鞋部位换装，也不是旧 Pet LPC。
3. **旧 Pet Life Sim / 农场已删除**：不再维护 `lib/pages/pet/**`、`lib/game/pet/**`、`lib/game/farm/**`、`PetProvider`。
4. Companion 入口只走 `FeatureFlags.arenaGamePrototype` → `/game/arena`；`/pet/home` 深链兼容进 `ArenaPage.home()`。

## 皮肤模型

| 概念 | 说明 |
|------|------|
| `ArenaHeroSkin` | `id` / `name` / `imageAsset` / 可选 `tint` |
| 选择态 | ViewModel `_heroSkinIds[heroId]` |
| 持久化 | `owned_heroes_json[].skin_id` + SharedPreferences |
| API | `PUT /api/arena/skin` `{ hero_id, skin_id }` |
| UI | 小家「当前皮肤 / 更换皮肤」→ 角色页横向皮肤条 |

## 必存字段

| 数据 | 落点 | 写入时机 |
|------|------|----------|
| 星晶 | `star_crystals` | 召唤 / 送礼 / 通关 |
| 英雄碎片/羁绊/等级/星级/战力/好感/皮肤 | `owned_heroes_json` | 召唤 / 送礼 / 换肤 / hydrate |
| 阵容 | `formation_json` | 编队变更防抖自动保存 / 手动保存 |
| 塔层 | `tower_floor` | 通关胜利 |
| 牌组 | `deck_json` | 通关 / 保存编队 |
| 训练/送礼下场 buff | `progress_json` | 训练 / 送礼 / 开战清空 |
| 爬塔选中节点 | `progress_json` | 点选节点防抖保存 |
| 本地兜底 | SharedPreferences `arena_progress_v1` | 任意进度变更 |

## API

| Method | Path |
|--------|------|
| GET | `/api/arena/state` |
| PUT | `/api/arena/formation` |
| PUT | `/api/arena/deck` |
| PUT | `/api/arena/meta` |
| PUT | `/api/arena/skin` |
| POST | `/api/arena/summon` |
| POST | `/api/arena/home/gift` |
| POST | `/api/arena/home/train` |
| POST | `/api/arena/tower/clear` |

## 前端能力

| 能力 | 状态 | 说明 |
|------|------|------|
| 小家送礼 / 训练 / 出发 | ✅ | Arena 原生 + 下场 buff |
| 整卡皮肤 | ✅ | 角色页选择；大厅/编队/图鉴/战斗立绘跟随 |
| 编队 / 召唤 / 爬塔 / 战斗 | ✅ | |
| Pet LPC / 房间 Flame / 农场 | 🗑️ | 已删除，不回灌星辉 |
