# PRD — 商业化域（VIP / 钱包 / 礼物 / 签到成就 / 装扮）

- **生成时间**：2026-10-14 · **层级**：P2（结构保留，不做主视觉重心） · **数据源**：代码事实反推
- **上级文档**：[moe-social-prd.md](./moe-social-prd.md)

---

## 1. Summary

商业化域为产品提供收入结构：VIP 会员（套餐/订单/自动续费/每日星辉结晶）、钱包（充值/流水）、礼物（购买/赠送/Lottie 特效/直播 PK）、签到成就（经验/等级）、装扮消费（头像框/表情包）。定位是支撑而非驱动——不抢占社交主路径的视觉与入口资源。

## 2. Background & Problem

- **问题**：个人开发者需要可持续收入覆盖服务器与 LLM 成本；用户需要为爱付费的出口。
- **workaround**：无（自有体系）。
- **不解决**：电商、广告变现、付费流量分发。

## 3. Personas

付费 persona：阿星（愿意为爱付费的陪伴型用户）。本域不为"薅羊毛用户"做反向设计——签到/成就奖励是留存钩子不是经济漏洞。

## 4. Goals & Success Metrics

| 指标 | 行为 | 目标值（建议） | 时间窗 |
| --- | --- | --- | --- |
| VIP 付费率 | 月活中 VIP 占比 | ≥ 5% | 180 天 |
| VIP 续费率 | 到期用户续费比例 | ≥ 60% | 180 天 |
| 礼物周使用率 | 周送礼用户占比 | ≥ 10% | 90 天 |
| 签到留存（health） | 周签到 ≥5 天用户占比 | ≥ 20% | 90 天 |

- **Anti-metric**：ARPU 最大化——不做诱导性付费弹窗与大R专属特权；付费点必须服务陪伴/表达，不卖数值碾压。
- **关键假设**：VIP 权益（每日星辉结晶等）能把陪伴付费意愿转化为订阅，而非一次性打赏。

## 5. Value Proposition

> 阿星为喜欢的东西付费时，得到的是关系与表达的增强（结晶、礼物、装扮），而不是数值特权。

## 6. Solution & Feature Scope

### Story 6.1 — VIP 会员 · P1

**功能描述**：套餐列表、下单、订单中心、自动续费管理、权益目录页；权益含每日星辉结晶（进 Arena 自动到账）等。

**验收标准**：
- Given VIP 用户进权益目录，When 查看，Then 权益项与实际生效逻辑一致（每日结晶由 `GetState` 触发，按上海日补发）。
- Given 关闭自动续费，When 到期，Then 权益正确终止且不重复扣费。

**设计触点**：`lib/pages/commerce/vip_center` / `vip_purchase` / `vip_orders` / `vip_history` / `vip_order_confirm` / `vip_benefit_catalog.dart`。
**关联后端**：`VipService/VipPlans` · `biz/vip/` · 账号侧 `biz/user/vip_orders.go` / `vip_status.go`。

### Story 6.2 — 钱包 · P1

**功能描述**：充值、交易流水；余额是所有消费（礼物/装扮/表情包）的统一扣减源。

**验收标准**：充值到账与流水一致；消费扣减失败不产生负余额。

**设计触点**：`lib/pages/commerce/wallet` / `recharge` / `order_center`。
**关联后端**：`UserService.Recharge/GetTransactions` · `biz/user/wallet.go`。

### Story 6.3 — 礼物 · P1

**功能描述**：礼物列表、购买、赠送、记录；Lottie 特效（`useLottieGiftEffects=true`）；直播 PK 场景送礼（`liveGiftPk=true`，BattleService 房间）。

**验收标准**：
- Given 送礼成功，When 对方在线，Then 收到类型 8 通知与特效展示。
- Given PK 房间送礼，When 结算，Then 礼物计入对战结果且余额正确扣减。

**设计触点**：`lib/pages/battle/`（直播 PK 两页）· 礼物入口（聊天/资料场景）。
**关联后端**：`GiftService.GetGifts/PurchaseGift/SendGift/GetGiftRecords` · `BattleService.CreateRoom/StartRoom/SendBattleGift/FinishRoom`。

### Story 6.4 — 签到 / 经验 / 等级 / 成就 · P2

**功能描述**：每日签到、经验日志、等级；成就列表与解锁；管理员可 bootstrap 成就与配置。

**验收标准**：重复签到不重复发经验；成就解锁即时可见。

**设计触点**：`lib/pages/checkin/`（签到/等级两页）· `lib/pages/achievements/`。
**关联后端**：`Checkin.CheckIn/GetUserLevel/GetExpLogs/ClaimDailyExp` · `Achievement.GetUserAchievements`。

### Story 6.5 — 装扮与表情包 · P2

**功能描述**：头像装扮购买、表情包购买；头像框与奖池配置走管理后台运营流程。

**验收标准**：购买后资产即时可用；头像框配置改动经后台审计。

**设计触点**：`lib/pages/settings/virtual_avatar`。
**关联后端**：`UserService.PurchaseAvatarOutfit/PurchaseEmojiPack` · `biz/user/avatar_outfits.go` / `avatar_pack.go` · 运营流程 `../头像框与奖池配置操作流程.md`。

## 7. Constraints & Risks

- 约束：商业化入口不抢主 Tab 与首屏；支付合规（iOS/Android 内购通道）按平台规则。
- 风险：① 星晶经济通胀（每日结晶 + 通关奖励 + 召唤消耗需定期对账）；② 充值纠纷——流水必须可查可对。

## 8. Release Approach

全量在线。后续：① 充值系统规划落地（`../../planning/充值系统实现计划.md`）；② 星晶经济月度对账机制；③ VIP 权益扩展跟随活世界节奏（如 M1 后加英雄相关权益）。
