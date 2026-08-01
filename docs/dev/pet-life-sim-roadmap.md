# Moe 完整养成（Pet Life Sim）路线图

> **日期**：2026-08-01  
> **状态**：P0 起实施 · Flag 域  
> **引擎**：Flutter + Flame（不拆 Godot/Unity）  
> **对标**：宠我一生能力面（分期交付）

## 1. 产品形态

| 项 | 结论 |
|----|------|
| 形态 | 嵌在 moe_social，**独立养成域** |
| Flag | `FeatureFlags.petLifeSim` |
| 主叙事 | 不替代 Feed / 私信 / Companion 关系首页 |
| 与 Companion | 同账号；聊天/人设走 Companion；养成外观独立 |
| 与 Life | **主路径 = 小家**；「TA 的世界」入口默认关（`showLifeEngine=false`），代码保留可回滚；不合并成双主界面 |

## 2. 完整可体验定义

1. 领养/捏脸 → 小家 → 喂食照料  
2. 装扮 + 布置家具  
3. 年龄 → 上学 → 打工  
4. 好友 / 结婚 / 同居（简化）  
5. 轻冒险（放置/回合）  
6. 软通货商店；内购/小组件为 P4  

## 3. 分期

| 期 | 内容 | 验收 |
|----|------|------|
| **P0** | Room 小家、喂食/陪伴、装扮/家具最低集 | 外人可试玩 10 分钟 |
| **P1** | 年龄、上学、打工（表驱动） | 能升级属性与赚钱 |
| **P2** | 好友拜访、结婚、宝宝简化 | 社交闭环可走通 |
| **P3** | Flame 轻冒险 | 有胜负与掉落 |
| **P4** | 内购校验占位、桌面小组件 | 可后置 |

## 4. 工程

- Flutter：`lib/pages/pet/`、`lib/game/pet/`、`lib/services/pet_service.dart`、`lib/providers/pet_provider.dart`
- 后端：`backend/api/pet/v1/`、`internal/{service,biz,data}/pet/`、表前缀 `pet_`
- Flame 禁止 HTTP；业务走 Page → PetService

## 5. 明确不做

- 刷地上物冒充主界面、可拖大地图当养成主路径  
- Godot/Unity 嵌入、硬核动作、xLua 热更  
- 养成替换主 Tab  

## 6. 美术

见路线图计划附录；资源目录 `assets/pet/`，缺图用 Canvas 占位。说明：`assets/pet/README.md`。

**装扮渲染（正式路线）**：**Moe Avatar Spec** — 管理台 Canvas 编辑器导出官方包；SSOT `moe-avatar/` · `docs/dev/moe-avatar-admin.md`。  
**LPC 短跑（过渡）**：`FeatureFlags.petLpcPrototype` → 验证走动 + compose；SSOT `docs/dev/pet-lpc-pipeline.md`。  
**装扮 A（回滚）**：PNG 分层 + 锚点；`docs/dev/pet-layered-avatar.md`。  
Spine（C）远期：`docs/dev/pet-spine-avatar.md` + `FeatureFlags.petSpineAvatar`。

## 7. P4 占位

内购校验与桌面小组件：`docs/dev/pet-iap-and-widget.md`。

## 8. 回滚

`FeatureFlags.petLifeSim = false` 隐藏入口；不影响社交与 Companion 主路径。

## 9. 实现落点（2026-08-01）

| 层 | 路径 |
|----|------|
| Flag | `FeatureFlags.petLifeSim` |
| Flutter | `lib/pages/pet/pet_home_page.dart`、`lib/game/pet/*`、`lib/providers/pet_provider.dart` |
| 入口 | Companion Hub「TA 的小家」→ `/pet/home` |
| Proto | `backend/api/pet/v1/pet.proto`（REST 现由 `protohttp/pet` 手写对齐） |
| 表 | `pet_profiles` / `pet_friendships` |
