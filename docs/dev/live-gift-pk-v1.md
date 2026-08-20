# 礼物 PK 对战 V1 方案

## 背景

Moe Social 已有礼物目录、库存/余额扣减、礼物记录，以及 Flutter 的礼物跑道和全屏动效；但这些能力目前面向一对一赠礼，无法表达直播间中的双人 PK 房间、阵营、倒计时、实时分数和结算。

V1 的目标是交付一个可验证的“双人礼物 PK”闭环：观众选择任一阵营送礼，服务端原子扣款并增加对应阵营积分，所有房间成员实时看到同一份比分和礼物事件，倒计时结束后由服务端结算胜负。

不以客户端本地计时或本地累计分数作为事实来源；Flutter 只做即时反馈和状态展示。

## 范围

### V1 包含

- 两名参赛者、两支阵营、固定 120 秒的 PK 房间；
- 创建、查询、加入/订阅、开始和结束房间；
- 观众向左/右阵营赠送现有礼物；
- 服务端事务内扣除库存或余额、写礼物记录、写 PK 事件、更新分数；
- WebSocket 实时推送房间快照、送礼事件和最终结果；
- Flutter 双方分数条、服务端倒计时、礼物跑道、全屏动效和断线重连；
- 管理台只提供 V1 房间审计入口或查询接口，不承载直播间 UI。

### V1 不包含

- Agora 双人音视频画面接入。现有 Agora 语音能力可在 V2 接入，PK 协议不依赖它；
- 多人团战、匹配、榜单、惩罚、回放、礼物特效编辑器；
- 付费内购、主播提现或分成；
- 客户端离线结算、前端改分或用礼物动画回调驱动积分。

## 领域边界

新增 `battle` 域，不修改普通赠礼 `gift.SendGift` 的业务语义。

```text
Flutter LivePkRoomPage
  -> BattleService REST: 查询/送 PK 礼物/恢复快照
  <- /ws/battle?room_id=...: snapshot / gift_sent / finished

Battle service -> Battle biz -> Battle data
                           -> Gift transaction port
```

礼物库存、余额、交易流水和 `gift_records` 仍由礼物域负责。Battle 域只负责校验房间和阵营、计算积分、持久化对战事件及广播。两者必须在同一数据库事务中提交；提交成功后才广播 WebSocket。

## 数据模型

新增迁移和 GORM model，表名使用 `battle_` 前缀：

| 表 | 关键字段 | 作用 |
|---|---|---|
| `battle_rooms` | `id`, `left_user_id`, `right_user_id`, `status`, `started_at`, `ends_at`, `winner_side`, `event_seq` | 房间状态和服务端时钟锚点 |
| `battle_scores` | `room_id`, `side`, `score`, `gift_value`, `updated_at` | 两个阵营的聚合分数，唯一键 `(room_id, side)` |
| `battle_gift_events` | `id`, `room_id`, `event_seq`, `sender_user_id`, `side`, `gift_record_id`, `gift_id`, `quantity`, `score_delta`, `created_at` | 可审计、可重放的送礼事实，唯一键 `(room_id, event_seq)` |
| `battle_idempotency_keys` | `room_id`, `sender_user_id`, `request_id`, `event_id` | 防止网络重试重复扣费，唯一键 `(room_id, sender_user_id, request_id)` |

`score_delta = gift.price * quantity` 是 V1 的唯一积分规则。后续活动倍率必须成为服务端房间配置快照，不允许由 Flutter 传入。

## API 契约

新增 `backend/api/battle/v1/battle.proto`，HTTP 与 gRPC 由 proto 生成。

| RPC | HTTP | 用途 |
|---|---|---|
| `CreateRoom` | `POST /api/battles` | 创建草稿房间，仅参赛者或运营可执行 |
| `StartRoom` | `POST /api/battles/{room_id}/start` | 服务端写入 `started_at/ends_at`，幂等 |
| `GetRoom` | `GET /api/battles/{room_id}` | 返回当前快照，用于首屏和重连 |
| `SendBattleGift` | `POST /api/battles/{room_id}/gifts` | 向指定阵营送礼，必带 `request_id` |
| `FinishRoom` | `POST /api/battles/{room_id}/finish` | 到期结算；仅服务端任务或运营调用 |

`SendBattleGiftRequest` 的最小字段：`room_id`、`side`、`gift_id`、`quantity`、`request_id`。送礼人从 JWT context 读取，不能由请求体指定；参赛者身份、房间状态和结束时间由服务端校验。

所有响应都返回 `BattleRoomSnapshot`：房间状态、服务端当前时间、结束时间、双方展示信息、双方分数、`last_event_seq`。这使客户端无需根据本地递增逻辑猜测比分。

## WebSocket 协议

新增认证路由：`GET /ws/battle?room_id={id}`。鉴权方式与已存在的 `/ws/companion` 一致，从 JWT context 获取当前用户；允许观众只读订阅，房间不存在或无权限时拒绝。

服务端消息统一包含 `type`、`room_id`、`seq`、`server_time`、`payload`：

| 类型 | Payload | 客户端处理 |
|---|---|---|
| `snapshot` | 完整 `BattleRoomSnapshot` | 初次连接、重连、发现序号缺口时直接覆盖状态 |
| `gift_sent` | 送礼人、阵营、礼物、数量、`score_delta`、最新双方分数 | 播放跑道和礼物动效，更新比分 |
| `room_started` | 快照 | 根据 `ends_at` 显示倒计时 |
| `room_finished` | 快照、胜方或平局 | 停止送礼、显示结果 |

`seq` 只在单个房间内单调递增。Flutter 发现 `seq != lastSeq + 1` 时不补猜事件，而是调用 `GetRoom` 获取快照；重复事件按 `seq` 丢弃。

## 后端事务与结算

`SendBattleGift` 的顺序固定为：

1. 校验 JWT 送礼人、`request_id`、房间状态、阵营和时间窗口；
2. 对 `battle_rooms`、对应 `battle_scores` 和送礼人礼物余额/库存加锁；
3. 若幂等键已存在，返回其对应事件和当前快照，不再扣费；
4. 使用现有 Gift 域事务能力扣库存或余额、创建 `gift_records` 与交易流水；
5. 创建 `battle_gift_events`，递增 `event_seq`，累加阵营分数；
6. 提交事务后由 Battle Hub 广播 `gift_sent`；
7. 广播失败不回滚已完成交易，重连快照和事件表负责恢复事实。

房间结束由后端定时器或显式 `FinishRoom` 以数据库时间判断。并发结束和送礼竞争时，以锁定后的 `ends_at` 判断是否接受本次礼物；结束后状态不可回到进行中。

## Flutter 结构

新增但不替换现有礼物组件：

| 路径 | 职责 |
|---|---|
| `lib/pages/battle/live_pk_room_page.dart` | 双方舞台、分数条、倒计时、结果层和礼物入口 |
| `lib/providers/battle_room_provider.dart` | 快照、事件序号、连接状态、倒计时与乐观送礼状态 |
| `lib/services/battle_service.dart` | REST 查询/送礼与重连快照 |
| `lib/services/battle_ws_service.dart` | WebSocket 连接、认证、退避重连、事件解析 |
| `lib/models/battle_room.dart` | 房间、阵营、快照和事件 DTO |
| `lib/widgets/battle/battle_scoreboard.dart` | 红蓝或主题化分数条 |
| `lib/widgets/battle/battle_gift_selector.dart` | 复用礼物目录，增加阵营选择与 `request_id` |

`LiveGiftEffect`、`GiftRunway` 和 Lottie 资源继续复用。需要把 `GiftAnimationManager` 的连送聚合键由仅 `gift.id` 扩展为 `room_id + side + sender_id + gift.id`，避免两边送同一礼物被错误合并。PK 分数使用正常 Flutter Widget + `AnimatedBuilder/CustomPainter`；V1 不引入 Flame，避免把业务连接与 UI 引擎耦合。

## 交互流程

```text
进入房间 -> GET 快照 -> 连接 WS -> 收到 snapshot
  -> 用户选择左/右阵营并送礼
  -> POST SendBattleGift(request_id)
  -> 成功：等待或确认 WS gift_sent，播放对应阵营动效
  -> 断线：指数退避重连 -> snapshot 覆盖状态
  -> 服务端结束 -> room_finished -> 显示胜负并禁止再送
```

送礼按钮可短暂显示“发送中”，但不得在 REST 返回前永久累计分数。REST 成功且 WS 延迟时，可展示待确认礼物动效；最终分数以 WS 或重拉快照为准。

## 实施分期与验收

### P0：契约与事实层

1. 定义 `battle.proto`、GORM model 和迁移；
2. 实现 room/snapshot、幂等送礼事务、结束结算；
3. 覆盖单元测试：余额/库存、重复请求、并发送礼、截止时间、平局与重试。

验收：两个并发请求不会重复扣款，重放同一 `request_id` 返回同一个事件；分数、礼物记录和交易流水一致。

### P1：实时通道

1. 实现 Battle Hub 和 `/ws/battle`；
2. 连接即下发快照，成功送礼后广播事件；
3. 增加断线重连、序号缺口重拉快照的集成测试。

验收：两个客户端在 300ms 级别内收到一致比分；断线后恢复到服务端真实状态。

### P2：Flutter 房间

1. 实现 `BattleRoomProvider` 与房间页；
2. 复用礼物选择器、跑道和全屏动效，动效按阵营定位；
3. 完成发送中、失败回滚、结束态、弱网重连和无障碍降级。

验收：双账号在真机上完成一次 PK，双方看到一致倒计时、分数、送礼动效和结果；关闭重开 App 后可恢复进行中房间。

## 影响范围

- 后端：新增 `backend/api/battle/`、`internal/{service,biz,data}/battle/`、WebSocket 路由和数据库迁移；
- Flutter：新增 battle 页面、Provider、Service、Model、Widget；调整礼物动效的合并键；
- 管理台：V1 仅在已有礼物/交易审计中保留关联信息，PK 运营面板不作为首要交付；
- 既有普通送礼、聊天和 Voice/Agora 通话不改变接口语义。

## 风险与回滚

- 金额和库存风险最高：先实现幂等键、事务锁和服务端结算，再做视觉效果；
- WebSocket 是通知层而非账本，任何丢包都必须通过快照恢复；
- 动效队列要限流，低端设备按现有 `MoeVfxProfile` 降级，避免连送掉帧；
- 发布通过 `FeatureFlags.liveGiftPk` 控制入口。关闭 Flag 后隐藏入口并断开客户端订阅，已建房间和礼物/积分事实保留以便审计；新增表向后兼容，不做破坏性回滚。

## 后续演进

V2 再接入 Agora 双人视频、房间主持权限、活动倍率快照与赛后榜单；V3 才考虑多人团战、观众榜和直播回放。任何扩展都复用同一房间快照、事件序号和服务端结算模型。
