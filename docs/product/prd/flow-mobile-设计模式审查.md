# Flow-Mobile Review — Moe Social 移动端设计模式审查

- **生成时间**：2026-10-14 · **模式**：Review Mode（P1→P2→P3）
- **审查目标**：Flutter 客户端现有设计模式——导航骨架 / 主路径 / 状态设计 / TabBar——是否满足用户需求
- **对照标尺**：frame 机会点图谱 + bench takeaways（borrow/avoid）+ mobile-ui-review P1/P2/P3 规则
- **证据来源**：代码实读（main_shell / companion_hub / community_post_search 等）+ 前端全量调研 + 既有 SSOT 文档

---

## 总体结论（先给答案）

**现有设计模式对「已上线的核心需求」是满足的，且骨架质量高于同类个人项目平均水平**；对「frame 识别的未来需求」有 3 个明确不满足处。不需要推翻任何架构，需要的是：补冷启动、补关系可视化、补搜索默认态，以及收敛非主路径的硬编码颜色债务。

| 维度 | 结论 | 一句话依据 |
| --- | --- | --- |
| TabBar 导航骨架 | ✅ 健康 | 5 Tab ≤ 上限、职责边界有 SSOT、deferred 加载 + IndexedStack 保活 |
| 三条主路径 | ✅ 满足 | 发帖/浏览/私信闭环完整，媒体密度收口有测试锁定 |
| 状态设计（空/错/加载） | ✅ 基本满足 | 空态矩阵 P0 已落地，MoeErrorState 统一带重试 |
| Token/主题体系 | ⚠️ 主路径健康、长尾有债 | 主路径走 MoeTokens；39 文件 273 处硬编码颜色（Arena/Life 占大头） |
| 冷启动（新用户） | ❌ 不满足 | 无 onboarding、无推荐关注——frame 机会 #2（高优先级） |
| 陪伴关系可视化 | ❌ 不满足 | Hub 只有数值，无里程碑——frame 机会 #3 / bench takeaway-1 |
| Arena↔社交连接 | ❌ 不满足（有意约束下的缺口） | 无合规分享出口——frame 机会 #4 |

---

## P1 扫描（必须修复级）

| 规则 | 结果 | 证据 |
| --- | --- | --- |
| P1-1 SafeArea | ✅ 通过 | Scaffold + bottomNavigationBar 体系，主壳无裸奔（`lib/app/main_shell.dart`） |
| P1-2 触摸目标 ≥44 | ✅ 通过 | 主 CTA 高 46px（companion_hub_page.dart:604）；IconButton 默认 48 |
| P1-3 颜色硬编码 | ⚠️ **部分违反** | `lib/pages` 39 文件 273 处 `Color(0xFF...)`：arena_page 54（`_ArenaColors` 游戏壳，设计内例外）、life_world_page 50（转向期，不投入）、**companion_memories_page 11 / live_pk_room_page 11 / checkin_page 9 / cloud_gallery_page 8 / profile_page 7 / gacha_page 6**——这批在主路径或半主路径上，应收敛进 MoeTokens |
| P1-6 主 CTA 拇指区 | ✅ 基本通过 | Hub「开始聊天/回复 TA」在首屏关系卡内 46px 全宽按钮（companion_hub_page.dart:596-632）；发帖发布按钮在 AppBar 右上（编辑器惯例，可接受）；发帖**入口**在筛选栏右侧（UI 迭代已收束，可接受） |

**P1 处置建议**：仅 P1-3 需要行动——排期收敛 companion_memories / live_pk / checkin / gallery / profile / gacha 六页的硬编码颜色（Arena 与 Life 不动，前者是游戏壳例外、后者转向期不投入）。

## P2 扫描（建议修复级）

| 规则 | 结果 | 证据与说明 |
| --- | --- | --- |
| P2-1 长列表虚拟化 | ✅ 通过 | ListView.separated 等按需构建（community_post_search_page.dart:157） |
| P2-2 空状态无 CTA | ✅ 通过 | IA 文档 §5 空态矩阵 P0 已落地（关注空态双 CTA、好友空态双 CTA） |
| P2-3 表单 loading/disabled | ✅ 通过（抽查） | 发帖按钮随内容有无变形；流式失败重试（companion_chat L417） |
| P2-4 TabBar 高亮 | ✅ 通过 | NavigationDestination selectedIcon 双态（main_shell.dart:189-215） |
| P2-7 搜索页默认态 | ⚠️ **违反** | 社区动态搜索：空关键词只给 hint 图标页（community_post_search_page.dart:131-136），无搜索历史 / 热门话题 / 推荐——社区搜索是 9 月底刚上的新功能，默认态还没跟上；圈子搜索同样待查 |
| P2-8 错误可操作 | ✅ 通过 | MoeErrorState.fromError + onRetry（community_post_search_page.dart:141-148），错误态有恢复路径 |
| P2-9 同类交互一致 | ✅ 通过 | 未读统一 MoeBadgeDot、Sliver 头统一 MoePinnedHeaderDelegate、IM 视觉升级已全量（flag 全开） |
| P2-5/P2-6 字体/间距 | ✅ 通过（体系层） | MoeTokens 统一字号/间距节奏，UI 治理阶段 1-3 已收口；个别长尾页随 P1-3 一起收敛 |

## P3 清单（体验增强）

- ⬜ **P3-1 恢复购买入口**：VIP/内购页未见明确「恢复购买」（需真机核实 vip_center/vip_purchase）
- ✅ **P3-2 Paywall 可关闭**：VIP 为常规页面非强制弹窗
- ⬜ **P3-3 权限请求前说明页**：定位/通知/麦克风未见统一前置说明页（语音消息、定位功能涉及）
- ✅ **P3-4 资金二次确认**：充值/订单确认页存在（vip_order_confirm_page）
- ⬜ **P3-5 骨架屏**：加载用 MoeLoading（ spinner 型），Feed 首屏无骨架屏
- ✅ **P3-6 网络错误重试**：MoeErrorState 带重试
- ⚠️ **P3-7 Peak 情感反馈**：礼物有 Lottie 特效（峰值反馈好）；但**发帖成功、爬塔通关、羁绊升级**等核心成就时刻只有轻反馈——bench takeaway-2（抽卡动效仪式感）正好补这里
- ⚠️ **P3-8 Flow 终态设计**：发帖完成直接返回 Feed（落崖式）；爬塔通关有结算（好）
- ❌ **P3-9 分阶段体验**：**无新用户引导**——frame 机会 #2 的直接证据；回访用户有签到/快捷入口（好）
- ✅ **P3-10 行业视觉规范**：Airy Moe 清透调性与 bench 视觉 diverge 决策一致，且与赛道暗夜风形成区隔

## 与 frame / bench 的对照（设计模式是否满足用户需求）

| 用户需求（frame 机会点） | 当前设计模式满足度 | 差距在哪 |
| --- | --- | --- |
| #1 TA/英雄离线也生活 | 🔶 模式已备好 | 营地预览页 + 日常流 + moments 通道都在，等活世界 M1 内容填充——**模式不缺，缺内容** |
| #2 新用户找同好 | ❌ 不满足 | 无 onboarding 流程、无推荐关注、搜索无默认态——需要新增「兴趣 onboarding flow」（规则版即可，frame 已限定不上算法） |
| #3 关系可视化积累 | ❌ 不满足 | Hub 信息都在但全是"状态"没有"进度"——bench takeaway-1 给出解法：里程碑时间线（不做进度条防过度游戏化） |
| #4 游戏成就社交出口 | ❌ 不满足 | D1 护栏正确，但缺「分享到动态」的合规出口设计——需一次专门设计（成就要选得克制、不刷屏） |
| #5 内容被同温层看到 | 🔶 部分满足 | 话题筛选 + 社区搜索刚补；分发个性化无——frame 方向 B 范畴，规则版推荐关注可先行 |
| #8 功能可度量 | ❌ 不满足 | 设计模式层面没有"新功能必带空态/指标"的交付门禁——建议把 P3 清单并入新页面评审清单（UI 迭代文档 §5 UI-1C 已有此计划） |

## 行动清单（按优先级）

1. **兴趣 onboarding flow（新）**：解决 frame #2 + P3-9——首次登录一次性兴趣标签选择（IA 文档 §5.5 P1 已有方案雏形），规则版推荐关注接关注 Tab 空态。
2. **Companion 关系里程碑（新）**：解决 frame #3 + bench takeaway-1——Hub 增加里程碑时间线区块，叙事化呈现（首聊/首次送礼/记忆数达成等），不做数值排行。
3. **搜索默认态（补）**：社区动态搜索 + 圈子搜索空关键词时展示历史/热门（P2-7）——新功能标配补齐。
4. **Peak 反馈加强（补）**：发帖成功、爬塔通关、召唤出货三个时刻补情感反馈（bench takeaway-2，Lottie 基建已有）。
5. **硬编码颜色收敛（债）**：companion_memories / live_pk / checkin / gallery / profile / gacha 六页 → MoeTokens（P1-3）。
6. **成就分享出口（设计）**：frame #4——先出设计方案再实施，注意克制不刷屏。
7. **权限说明页 + 恢复购买 + Feed 骨架屏（P3 长尾）**：随下次相关页面改动顺带补齐。

## 明确不需要动的

- TabBar 5 入口骨架与命名——边界 SSOT 清晰，不改
- 媒体密度收口（200/320px）——与 anti-metric 一致，保持
- Companion 按需提醒 Sheet 模式——不打扰设计正确，保持
- Arena `_ArenaColors` 游戏壳例外、Life 转向期页面——不投入收敛

---

> **审查限制声明**：本次为静态代码 + 文档审查，未做真机逐页走查；P3-1/P3-3/P3-5 三项标注 ⬜ 的需真机核实。建议后续用模拟器 QA 流程对三条主路径做一次截图冒烟（UI 迭代文档 §5 UI-1C 亦欠此项）。
