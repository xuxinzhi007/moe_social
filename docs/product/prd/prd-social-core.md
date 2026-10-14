# PRD — 社交核心域（Feed / 私信 / 好友 / 社区）

- **生成时间**：2026-10-14 · **层级**：P0 · **数据源**：代码事实反推
- **上级文档**：[moe-social-prd.md](./moe-social-prd.md) · **定位 SSOT**：[../product-positioning.md](../product-positioning.md)

---

## 1. Summary

社交核心域是 Moe 的存在理由：动态流、发帖、评论互动、关注/好友、私信、社区圈子、个人页。三条冻结主路径——记录心情（CreatePostPage）、浏览互动（HomePage → 详情/评论）、建立关系（消息中心 → 私信/好友）——是本域不可妥协的体验优先级。

## 2. Background & Problem

- **问题**：用户要一个低压力记录与被同温层接住的地方。
- **workaround**：大平台发动态（压力大、噪音多）。
- **边界**：首页 = 关注/算法流；社区 = 兴趣/讨论广场；两者不互相伪装入口（话题标签只做筛选，不兼任社区导航）。
- **不解决**：公共热搜/广场式大流量分发、陌生人社交匹配（发现探索为二级入口，非主路径）。

## 3. Personas

主 persona：小莓（见总 PRD §3）。本域不为"追求 10w+ 曝光的内容创作者"做——没有流量分成与热搜机制。

## 4. Goals & Success Metrics

| 指标 | 行为 | 目标值（建议） | 时间窗 |
| --- | --- | --- | --- |
| 周发帖率 | 周活跃中发帖用户占比 | ≥ 15% | 90 天 |
| 互动率 | 动态获评论/点赞的比例 | ≥ 40% | 90 天 |
| 私信会话建立率 | 新好友 7 天内发起会话比例 | ≥ 50% | 90 天 |
| Feed 加载失败率（health） | 错误态出现占比 | < 1% | 持续 |

- **Anti-metric**：信息流停留时长——不为时长做无限下拉成瘾设计；媒体密度已主动收口（列表 200px / 详情 320px 上限）。
- **关键假设**：低压力氛围（萌系视觉 + 无曝光指标）能让用户更敢发日常。

## 5. Value Proposition

> 小莓终于敢把日常发出来，因为这里没有表演压力，只有同好的回应。

差异化：媒体密度主动收口（浏览效率优先）+ 社区 AI 身份可选（低压力表达）+ 话题只做筛选不做导航（IA 干净）。

## 6. Solution & Feature Scope

### Story 6.1 — 记录心情（发帖）· P0

**功能描述**：用户以单卡片表单发布动态：正文 + 图片附件 + 手绘卡片 + 话题（≤5，可搜索）+ 心情 chips + 可选社区 AI 身份 + 关联圈子。支持编辑模式与草稿自动恢复。

**In Scope**：正文/图片/手绘/话题/心情/AI 身份横幅/关联圈子/草稿恢复/编辑模式；发布按钮随内容有无变形。
**Out of Scope**：视频发布、定时发布、多图排版模板。

**验收标准（Given/When/Then）**：
- Given 用户无任何输入，When 打开发帖页，Then 顶部按钮为「保存」（草稿态）而非「发布」。
- Given 用户输入正文后杀进程重进，When 再开发帖页，Then 草稿自动恢复。
- Given 已选 5 个话题，When 再搜索添加，Then 不可超限并给出提示。
- 边缘情况：发布失败时保留表单内容并可重试；配额语义 0 = 不限额，超限给统一错误提示。
- 空状态：无附件时不显示附件条占位。

**设计触点**：`lib/pages/feed/create_post_page.dart`（双模式 L30、草稿 L257、正文卡 L569、手绘 L899-1055、话题 L728-842、心情 L879、AI 身份横幅 L508）· `create_post_viewmodel.dart`。
**关联后端**：`PostService.CreatePost` · 配额逻辑 `backend/pkg/moe/tools/post_handlers.go` + `biz/moe/runtime_admin.go`。

### Story 6.2 — 浏览互动（Feed + 评论）· P0

**功能描述**：首页提供热门/最新/关注 + 话题筛选的动态流；轻量文字分段；发帖入口固定筛选栏右侧。动态详情 + 两级楼中楼评论，支持回复分页展开、@提及、点赞、社区 AI 身份回复。

**In Scope**：三种 Feed 模式、话题筛选、Stories、媒体密度收口（列表单图 16:9 ≤200px、多图紧凑网格限高、详情 ≤320px）、评论两级、@提及（最多 5 人，通知类型 10）、点赞。
**Out of Scope**：转发、弹幕式互动、信息流广告。

**验收标准**：
- Given 关注 Tab 无动态，When 列表为空，Then 显示空态卡「去兴趣社区 / 去找同好」双 CTA 且可跳转。
- Given 单图动态，When 在列表渲染，Then 媒体高度 ≤200px，点按进全屏查看器。
- Given 评论中 @好友，When 提交，Then 被 @者收到类型 10 通知，且单条最多 @5 人。
- 边缘情况：Feed 加载失败显示错误态 + 重试；下拉刷新不丢筛选状态。
- 空状态：各模式空态文案按 IA 文档 §5.1 矩阵。

**设计触点**：`lib/pages/feed/home_page.dart` · `home_feed_viewmodel.dart` · `comments_page.dart`（楼中楼 L57/175、@提及、AI 身份回复 L505）· `topic_posts_page.dart`。
**关联后端**：`PostService.GetPosts/CreatePost/LikePost` · `CommentService.GetPostComments/CreateComment/LikeComment` · 提及逻辑 `backend/internal/biz/comment/mentions.go`。

### Story 6.3 — 私信与会话 · P0

**功能描述**：消息中心承载会话列表、好友入口、好友申请；单聊支持文本、图片、按住语音（含秒数/上滑取消）、语音通话、聊天皮肤；未读数以后端为准。

**In Scope**：会话列表（未读后端对齐）、文本/图片/语音消息、语音通话（Agora token）、聊天皮肤选择、会话搜索与隐藏、离线/失败态提示。
**Out of Scope**：礼物面板、位置共享、群聊（社区讨论区承担群组场景）。

**验收标准**：
- Given 会话列表，When 后端下发未读数，Then 角标与后端一致（不信本地缓存）。
- Given 按住录音上滑，When 松开，Then 取消发送且不残留本地文件。
- Given 消息发送失败，When 网络恢复，Then 可重试且不错序。
- 空状态：无会话时引导添加好友/去发现同好。

**设计触点**：`lib/pages/chat/message_center_page.dart` · `direct_chat_page.dart`（图片 L1257、语音 L65-72/1281、通话入口 L702）· `conversations_page.dart` · `voice_call_*.dart` · `chat_skin_picker_page.dart`。
**关联后端**：`PrivateMessageService` / `ChatPresenceService` / `PushNotificationService` · `biz/chat/delivery.go`（通知类型 6）。

### Story 6.4 — 好友与关系 · P0

**功能描述**：好友申请/接受、关注/粉丝、好友搜索、用户 QR、个人资料页与编辑。

**验收标准**：
- Given 无好友，When 打开好友列表，Then 空态卡含「添加好友」主 CTA +「去认识同好」次 CTA。
- Given 收到申请，When 接受，Then 双方好友列表即时更新且可发起会话。

**设计触点**：`lib/pages/profile/friends_page.dart` · `friend_search_page.dart` · `followers_page.dart` / `following_page.dart` · `user_qr_code_page.dart` · `user_profile_page.dart` · `edit_profile_page.dart`。
**关联后端**：`UserService.SendFriendRequest/AcceptFriendRequest/FollowUser/GetFollowers`。

### Story 6.5 — 社区圈子 · P0

**功能描述**：兴趣小组（创建/加入/成员/圈内帖）、讨论广场、圈子搜索、社区动态搜索。

**In Scope**：小组 CRUD 与成员、圈内帖流、圈子搜索（`interest_group_search_page`）、社区动态搜索（`community_post_search_page`）、社区 AI 身份发帖。
**Out of Scope**：圈子付费、圈子排行榜。

**验收标准**：
- Given 搜索关键词，When 在圈子搜索页提交，Then 返回匹配圈子列表且可直达详情。
- Given 社区动态搜索，When 提交关键词，Then 走 `MoeSearchPosts` 返回社区范围结果（与首页流不串）。

**设计触点**：`lib/pages/community/`（community_home_page / interest_groups_page / interest_group_detail_page / interest_group_search_page / community_post_search_page / community_search_chrome / community_discussions_tab / community_posts_feed / community_post_detail_page）。
**关联后端**：`Community` service · `biz/post/query.go`（MoeSearchPosts）· 社区 bot `service/companion/community_bot.go`。

### Story 6.6 — 通知中心 · P0

**功能描述**：统一通知收件箱，类型 2/4/6/7/8/9/10，未读计数、单条/全部已读。

**验收标准**：@提及、评论回复、礼物、伙伴主动消息均产生对应类型通知；ReadAll 后未读清零且多端一致。

**设计触点**：`lib/pages/notifications/` · 跨页面未读统一用 `MoeBadgeDot`。
**关联后端**：`NotifyService` · `biz/notify/`。

## 7. Constraints & Risks

- 约束：三条主路径优先 Moe UI 统一；页面不直发 HTTP；空态用既有 Moe 组件；媒体高度预算有 Widget 测试锁定。
- 风险：首页 `HomeFeedViewModel` 仍保留 Companion snapshot 等无消费者请求（已知债务，UI 迭代文档 §7）——确认无引用后移除。

## 8. Release Approach

本域全量在线。后续增量按序：① 兴趣 onboarding（P1）；② 推荐关注打通（P2）；③ 移除 Companion 残留请求（技术债）。
