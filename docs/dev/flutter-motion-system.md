# Flutter Motion System

## Goal

为 `Moe Social` 提供一套可复用、轻量、可渐进扩展的 Flutter 动效系统，优先解决以下场景：

1. `BottomSheet` / 抽屉 / 操作层的进入与退出
2. 按钮、卡片、操作块的按压反馈
3. 列表、卡片、信息块的轻量入场动效
4. 高频操作入口的统一交互节奏

这套方案的目标不是“堆特效”，而是统一产品的交互反馈，让页面更有产品感，但保持性能轻。

## Principles

1. 优先使用 Flutter 原生动画能力，不先引入重量级第三方库
2. 动效服务于反馈，不为了“炫”而动
3. 默认轻量，兼容移动端与 Flutter Web
4. 动效参数统一收敛到 `MoeTokens`
5. 先做基础组件，再逐步替换业务入口
6. 优先替换低风险、高频入口，避免一次性大面积改动

## Foundation

当前基础动效组件已经完成：

1. `lib/widgets/motion/moe_pressable.dart`
2. `lib/widgets/motion/moe_reveal.dart`
3. `lib/widgets/motion/moe_sheet.dart`
4. `lib/theme/moe_tokens.dart`

当前基础能力：

1. `MoePressable`
   - 轻微缩放
   - 透明度变化
   - 可选触觉反馈
2. `MoeReveal`
   - 淡入
   - 轻微上移
   - 极小 scale 变化
3. `MoeSheet`
   - 统一圆角和拖拽把手
   - 统一上滑进入
   - 支持普通底部弹层
   - 支持 `DraggableScrollableSheet`

## Motion Tokens

当前已在 `MoeTokens` 中落地的动效 token：

1. `motionFast = 160ms`
2. `motionMedium = 260ms`
3. `motionSlow = 420ms`
4. `motionPressScale = 0.97`
5. `motionPressScaleStrong = 0.94`
6. `motionSheetOffset = 24`

默认曲线策略：

1. 入场：`Curves.easeOutCubic`
2. 回弹：`Curves.easeOutCubic`
3. 需要强调时再使用更强曲线，但不作为默认

## Current Progress

### 已完成的基础能力

1. `lib/widgets/motion/moe_pressable.dart`
2. `lib/widgets/motion/moe_reveal.dart`
3. `lib/widgets/motion/moe_sheet.dart`
4. `lib/theme/moe_tokens.dart`

### 已完成接入的业务文件

当前已经完成接入或部分完成接入的文件：

1. `lib/widgets/compact_topic_selector.dart`
2. `lib/pages/profile/widgets/add_friend_bottom_sheet.dart`
3. `lib/pages/chat/message_center_page.dart`
4. `lib/pages/profile/friends_page.dart`
5. `lib/widgets/gift_selector.dart`
6. `lib/widgets/custom_button.dart`
7. `lib/widgets/moe_action_row.dart`
8. `lib/widgets/moe_menu_card.dart`
9. `lib/widgets/quick_actions_grid.dart`
10. `lib/widgets/ai/ai_sheet.dart`
11. `lib/pages/settings/modules/appearance_module.dart`
12. `lib/pages/settings/widgets/feishu_bind_sheet.dart`
13. `lib/widgets/floating_virtual_avatar_host.dart`

### 当前仍未完成替换的文件

以下文件仍保留旧的 `showModalBottomSheet` 或尚未完全迁移：

1. `lib/pages/ai/agent_editor_page.dart`
2. `lib/pages/ai/agent_list_page.dart`
3. `lib/pages/ai/chat_page.dart`
4. `lib/pages/ai/content_generation_page.dart`
5. `lib/pages/ai/game_hub_page.dart`
6. `lib/pages/ai/game_play_page.dart`
7. `lib/pages/autoglm/autoglm_task_page.dart`
8. `lib/pages/chat/direct_chat_page.dart`
9. `lib/pages/community/interest_groups_page.dart`
10. `lib/pages/feed/create_post_page.dart`
11. `lib/pages/feed/hand_draw_editor_page.dart`
12. `lib/pages/gallery/cloud_gallery_page.dart`
13. `lib/pages/profile/edit_profile_page.dart`
14. `lib/pages/profile/user_profile_page.dart`
15. `lib/pages/settings/modules/account_security_module.dart`
16. `lib/pages/settings/modules/device_storage_module.dart`
17. `lib/widgets/achievement/achievement_unlock_notification.dart`
18. `lib/widgets/post_card.dart`

说明：

1. `lib/widgets/motion/moe_sheet.dart` 是基础组件本身，不算待迁移业务文件
2. `lib/pages/profile/friends_page.dart` 已有部分入口完成迁移，但文件内仍有旧调用，后续可继续收口

## Why We Did Not Batch Replace Earlier

前一阶段没有直接大批量替换，主要是出于代码安全考虑：

1. 仓库内存在部分历史文件编码异常，直接做大面积补丁命中率不稳定
2. 部分弹层并不只是 UI 容器，内部还混有登录校验、路由跳转、接口调用和局部状态
3. 不同文件的弹层复杂度差异很大，有的只是选择器，有的是复杂业务面板
4. 先小范围试点可以验证这套动效组件是否真的稳定、是否影响现有体验

经过当前多轮替换与验证，已经确认：

1. `MoeSheet` 适合批量接管低风险 `showModalBottomSheet`
2. `MoeReveal` 适合用于标题、说明、按钮、列表块的轻入场
3. `MoePressable` 适合替换大多数轻交互入口
4. 这套方案对性能和维护成本都可控

## Batch Migration Strategy

接下来采用“分层批量替换”策略，而不是完全逐文件手工推进。

### Level A：低风险，优先批量

特征：

1. 弹层结构简单
2. 业务逻辑轻
3. 文件体量适中
4. 不依赖复杂嵌套状态
5. 编码问题较少

建议优先处理：

1. `lib/widgets/achievement/achievement_unlock_notification.dart`
2. `lib/pages/community/interest_groups_page.dart`
3. `lib/pages/chat/direct_chat_page.dart`
4. `lib/widgets/post_card.dart`
5. `lib/pages/feed/hand_draw_editor_page.dart`
6. `lib/pages/profile/edit_profile_page.dart`

替换策略：

1. 统一将 `showModalBottomSheet` 改为 `MoeSheet.show`
2. 标题、说明、按钮等局部加入 `MoeReveal`
3. 片段式可点击项改为 `MoePressable`
4. 尽量不改业务逻辑和接口调用顺序

### Level B：中风险，按批推进

特征：

1. 有局部复杂状态
2. 有多个入口或多个弹层
3. 可能混合路由、提交、选择器逻辑

建议第二批处理：

1. `lib/pages/ai/agent_editor_page.dart`
2. `lib/pages/ai/agent_list_page.dart`
3. `lib/pages/ai/content_generation_page.dart`
4. `lib/pages/ai/game_hub_page.dart`
5. `lib/pages/profile/user_profile_page.dart`
6. `lib/pages/settings/modules/account_security_module.dart`
7. `lib/pages/settings/modules/device_storage_module.dart`
8. `lib/pages/gallery/cloud_gallery_page.dart`

替换策略：

1. 优先替换弹层容器，不急着调整所有内部组件
2. 复杂文件只替换高频入口，不一次性清空所有旧实现
3. 每个文件改完立刻单独分析

### Level C：高风险，单点处理

特征：

1. 文件巨大
2. 多处历史编码问题
3. 一个弹层可能牵动多个业务分支
4. 改动容易引发回归

建议最后处理：

1. `lib/pages/ai/chat_page.dart`
2. `lib/pages/ai/game_play_page.dart`
3. `lib/pages/autoglm/autoglm_task_page.dart`
4. `lib/pages/feed/create_post_page.dart`

替换策略：

1. 不做大批量补丁
2. 逐入口处理
3. 必要时直接重写小型局部组件，而不是在旧块上硬补

## Batch Execution Plan

### Batch 1

目标：优先吃掉低风险文件，快速提升覆盖率

建议文件：

1. `lib/widgets/achievement/achievement_unlock_notification.dart`
2. `lib/pages/community/interest_groups_page.dart`
3. `lib/pages/chat/direct_chat_page.dart`
4. `lib/widgets/post_card.dart`

预期结果：

1. 再新增 4 个高频入口接入
2. 覆盖通知、社区、聊天、帖子四类场景
3. 风险相对可控，适合先让前端验收

### Batch 2

建议文件：

1. `lib/pages/feed/hand_draw_editor_page.dart`
2. `lib/pages/profile/edit_profile_page.dart`
3. `lib/pages/ai/agent_editor_page.dart`
4. `lib/pages/ai/agent_list_page.dart`

### Batch 3

建议文件：

1. `lib/pages/ai/content_generation_page.dart`
2. `lib/pages/ai/game_hub_page.dart`
3. `lib/pages/profile/user_profile_page.dart`
4. `lib/pages/settings/modules/account_security_module.dart`
5. `lib/pages/settings/modules/device_storage_module.dart`

### Batch 4

建议文件：

1. `lib/pages/gallery/cloud_gallery_page.dart`
2. `lib/pages/ai/chat_page.dart`
3. `lib/pages/ai/game_play_page.dart`
4. `lib/pages/autoglm/autoglm_task_page.dart`
5. `lib/pages/feed/create_post_page.dart`

## Verification Rules

为了加快推进，后续每一批替换后的验证统一按以下规则执行：

1. 对每一批改动文件执行 `flutter analyze`
2. 用户侧只验证对应入口，不要求一次全项目回归
3. 每完成一批，都输出“修改了哪些文件 + 从哪里进入验证”

每个文件至少验证：

1. 弹层能正常打开和关闭
2. 没有遮挡输入、滚动、点击失效问题
3. 没有明显掉帧
4. 业务动作和原来一致

## Performance Notes

当前方案对性能影响较小，原因如下：

1. `MoePressable` 只是局部 `scale + opacity`
2. `MoeReveal` 是一次性入场动画，不是持续动画
3. `MoeSheet` 仍然走 Flutter 标准 `showModalBottomSheet`
4. 没有引入全局 blur、shader、粒子、复杂多层动画

当前需要继续遵守的性能约束：

1. 不在长列表每个 item 上无脑叠复杂动效
2. 不给全屏页面统一加重 reveal
3. 不在低端机高频区域使用持续性 glow / pulse
4. 复杂页只给关键入口加动效，不追求全覆盖

## Acceptance Criteria

本轮批量替换完成时，至少满足：

1. 所有低风险 `BottomSheet` 入口完成迁移
2. 每批次改动都能通过 `flutter analyze`
3. 不影响现有业务逻辑
4. 用户可按批次快速验证
5. 保持“体验增强，但不重”的动效目标

## Next Step

建议从 `Batch 1` 开始直接执行，先完成以下 4 个文件：

1. `lib/widgets/achievement/achievement_unlock_notification.dart`
2. `lib/pages/community/interest_groups_page.dart`
3. `lib/pages/chat/direct_chat_page.dart`
4. `lib/widgets/post_card.dart`

如果这一批验证没有问题，就继续 `Batch 2`，不再回到小步试探式推进。
