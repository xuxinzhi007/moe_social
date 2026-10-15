# PRD — Moe Social / 当前功能全集（代码事实反推版）

- **生成时间**：2026-10-14
- **数据源**：代码事实（`lib/`、`backend/`，2026-10-14 工作树）+ 既有 SSOT（product-positioning / ai-companion-formal-decisions / aurora-arena-ssot / aurora-living-world-plan / ui-upgrade-iteration-2026-08-29）
- **生成方式**：Standalone 反推模式（无上游 brief/stories/flow 链路产出，以代码为事实源）
- **完整度**：moderate —— Goals & Metrics 缺真实业务数据支撑，标 thin

---

## Section 1 — Summary

Moe Social 是一款萌系心情社交 App：用户记录与分享日常、浏览动态、评论互动、建立关系，AI 用于增强互动而不是独立工具箱。产品服务想低压力社交、找同好、并希望有长期 AI 陪伴的二次元气质用户。之所以是现在，是因为功能面已完整（5 主 Tab + 24 个后端 proto 模块全量在线）、视觉基线已收束，下一阶段的增长押注在「星辉活世界」（已定稿未实施）——把卡牌养成与全服共享世界模拟合并，让英雄在玩家离线时继续生活。成功的样子：社交三条主路径（记录心情 / 浏览互动 / 建立关系）顺畅无断点，Companion 与 Arena 两条增强线各自有可验证的留存贡献。

---

## Section 2 — Background & Problem

- **问题（用户视角）**：想记录心情、找同好、轻松聊天，但大型社交平台压力太重（表演式社交、信息流噪音）；想有"懂自己的 TA"，但独立 AI 聊天工具没有社交关系沉淀，聊完就散。
- **当前 workaround**：用户在微博/小红书发日常（缺私密与低压力），在 Character.AI/星野类工具里聊天（缺真实社交关系链），两边都不完整。
- **为什么是现在**：① 产品功能面已完整，从"补功能"转入"验证留存"阶段；② AI 陪伴赛道（星野/猫箱/Talkie）验证了陪伴付费意愿，但它们普遍缺真实社交主路径；③ 活世界方案（2026-09-02 定稿）给出了差异化方向：共享世界 + 异步英雄社交，是竞品没有的形态。
- **本 PRD 不解决**：① 多人实时联机（明确暂缓）；② AI 酒馆式多卡选角工具箱（已退役）；③ AutoGLM 自动化的普通用户化（实验功能）。

---

## Section 3 — Personas & User Segments

**Primary persona**：

```
姓名：小莓
身份：22 岁，二次元爱好者，轻社交意愿
情境：通勤/睡前刷手机，想记录心情、看看同好动态、低压力互动
JTBD：当有心情想记录或想找人聊时，小莓想低压力地发出来并被同温层接住，从而获得情绪安放与关系感。
当前 workaround：发微博/朋友圈（怕熟人评判）+ 单独用 AI 聊天 App（没有真实关系）
痛点：大平台社交压力大；AI 工具聊完没有沉淀；社区找不到同好
```

**Secondary persona**：

```
姓名：阿星
身份：26 岁，陪伴需求型用户，愿意为爱付费
情境：长期与 AI 伙伴相处，希望 TA 记得自己、有生活感
JTBD：当孤独或想分享时，阿星想和一个记得共同经历的 TA 说话，从而获得持续陪伴感。
当前 workaround：Character.AI / 星野，但角色"没有自己的生活"，关掉 App 就停了
痛点：AI 没有持续世界与记忆；付费点单薄（只有订阅聊天）
```

**这个产品不为谁做**：硬核联机游戏玩家、把 AI 当纯生产力工具的用户、追求大而全信息流的大众社交用户。

---

## Section 4 — Goals & Success Metrics

- **产品目标**（outcome-framed）：让用户"愿意每天回来看看"——因为动态有回应、伙伴有生活、世界在往前走。
- **成功度量表**（⚠️ 目标值为建议值，缺真实基线数据，标 thin）：

| 指标 | 度量什么用户行为 | 目标值 | 时间窗 |
| --- | --- | --- | --- |
| 次日留存（primary） | 注册后第二天仍打开任一主路径 | ≥ 40% | 90 天 |
| 三条主路径周完成率 | 周内有发帖/评论/私信行为的用户占比 | ≥ 30% | 90 天 |
| Companion 周对话天数（secondary） | 每周与伙伴对话 ≥3 天的用户占比 | ≥ 25% | 90 天 |
| Arena 周活跃（Flag 用户） | 开启 arenaGamePrototype 用户的周爬塔/召唤行为 | ≥ 50% | 90 天 |
| 崩溃-free 会话率（health） | 无崩溃会话占比 | ≥ 99.5% | 持续 |

- **Anti-metrics（不优化什么）**：① 通知打开率/推送点击率——优化它会滑向骚扰，破坏"低压力"定位；② AI 聊天单会话时长——过长会话意味着沉迷风险与 token 成本双高，不做为正向指标；③ 发帖配额使用量——配额是护栏不是 KPI。
- **关键假设**：用户会因为"TA/英雄在我离线时也在生活"而显著提高回访动机——如果错了，活世界 M1/M2 的大额投入（共享世界 tick、per-hero 记忆、官方角色卡资产）将不成立，Arena 退回静态卡牌养成。

---

## Section 5 — Value Proposition

**对主用户**：

> 小莓终于可以低压力地记录心情并被同温层接住，而不必在大平台表演式社交，因为 Moe 把动态、同好社区和一个记得她的 AI 伙伴放在同一个家里。

**对陪伴型用户**：

> 阿星终于拥有一个"关掉 App 也在生活"的伙伴与世界，而不必面对聊完即停的静态聊天机器人，因为星辉活世界让英雄在全服共享营地里持续演化。

**竞争差异化**（详见竞品拆解文档）：
- 星野/猫箱/Talkie 做对了"角色扮演的沉浸感"，留下的空白是：角色没有持续世界、没有真实社交关系链、付费点单薄。Moe 填的空白 = **社交主路径 + 长期陪伴 + 共享世界**三位一体。
- 传统社交（Soul/微博）做对了关系链，留下的空白是低压力与陪伴感；Moe 用 AI 伙伴和萌系气质填这个空白。

---

## Section 6 — Solution & Feature Scope

> 本 PRD 为总纲。各域完整 Story 拆解（GWT 验收标准、设计触点、资产路径）见分域 PRD：
> - [prd-social-core.md](./prd-social-core.md) — 社交核心域（P0）
> - [prd-companion.md](./prd-companion.md) — AI 伙伴域（P1）
> - [prd-arena.md](./prd-arena.md) — 星辉远征域（P1，Flag 开启中）
> - [prd-commerce.md](./prd-commerce.md) — 商业化域（P2）

### 域总览与当前状态

| 域 | 层级 | 状态 | 关键资产（代码路径） |
| --- | --- | --- | --- |
| 社交核心 | P0 | ✅ 全量在线 | `lib/pages/feed/` `lib/pages/chat/` `lib/pages/community/` `lib/pages/profile/` |
| AI 伙伴 | P1 | ✅ 一期+Slice 1-6.1 落地；多 bond 未开工 | `lib/pages/ai/companion_hub_page.dart` `lib/pages/companion/` `backend/internal/biz/companion/` |
| 星辉远征 | P1 | ✅ Flag `arenaGamePrototype=true` 全量可玩；活世界 M1 未开工 | `lib/pages/arena/` `lib/game/arena/` `backend/internal/biz/arena/` |
| 商业化 | P2 | ✅ 结构完整，不做主视觉重心 | `lib/pages/commerce/` `backend/internal/biz/{vip,gift}/` |
| 数字生命 Life | 已收口 | 🗑️ 旧前端 UI 2026-10 删除；引擎由 Arena 营地页复用（`lib/game/life/`），不再独立演进 | `backend/internal/biz/life/` |
| AutoGLM | 实验 | 🔒 `showAutoGlm=false`，开发者自用 | `lib/pages/autoglm/` |
| 小游戏/旧抽卡/Pet 旧养成 | 已删除 | 🗑️ 2026-10 整批删除，无回滚入口；见 `docs/dev/cleanup-2026-10-15.md` | — |

### FeatureFlags 当前事实（`lib/constants/feature_flags.dart`）

| Flag | 当前值 | 含义 |
| --- | --- | --- |
| `arenaGamePrototype` | true | 星辉远征对全量用户开放 |
| `showExperimentalFeatures` | false | 实验功能关 |
| `showGameNetworkLab` | true | 联机网络实验室（仅网络层，不涉英雄记忆）；发布前需置 false |
| `showAutoGlm` | false | AutoGLM 仅设置→高级选项 |
| `companionVoicePresence` | true | Companion 语音 STT/TTS 开 |
| `useLottieGiftEffects` / `liveGiftPk` | true | 礼物特效 / 直播 PK 开 |
| `glassNavigation` / `chatGradientBubbles` / `chatBrandMotion` / `chatVoiceMessage` / `chatThemeSkins` | true | IM 视觉升级全量 |

> 已删除 flag（2026-10）：`showGameFeatures`、`showGachaFeatures`、`showLifeEngine`、`useFlameLifeWorld`（对应功能整批移除）。

### 后端能力事实（Kratos 单进程 :8888，24 个 proto 模块）

user / post / community / comment / chat / companion / arena / battle / game / life / llm / ai / platform / vip / gift / checkin / achievement / notify / media / content / moe / behavior / landing / admin。通知类型常量：2=评论回复、4=系统、6=私聊、7=公告、8=礼物、9=伙伴主动消息、10=评论@提及。

### 未列入本版的 Stories（备 Phase 2 引用）

- 星辉活世界 M1（单英雄 MVP：官方角色卡 + 全屏营地页 + per-hero 记忆 + 登录快进摘要）——方案已定稿，见 `docs/dev/aurora-living-world-plan.md`
- 星辉活世界 M2（全 roster + 世界事件/道具/importance 分级 + 小家内嵌世界视图）
- Companion 多 bond（二期-B，未开工，禁止提前上多 profile 架构）
- 兴趣 onboarding（P1 建议，见 IA 文档 §5.5）
- 推荐关注打通（P2 建议，关注 Tab 空态直接列可关注用户）

---

## Section 7 — Constraints & Risks

- **技术约束**：个人开发者维护；服务器资源有限（见部署约束记忆）；Flutter 单 codebase 多端；后端 Kratos 单进程；测试必须 `make test`（CGO_ENABLED=1，裸 `go test` 会静默跳过 DB 用例）。
- **设计约束**：MoeTokens 为唯一视觉属性来源；Airy Moe 气质（清透/柔和/轻萌不过度装饰）；空态/加载/错误态必须用既有 Moe 组件；支持 reduced motion；页面不直接发 HTTP（走 service/ViewModel）。
- **数据 & 隐私**：聊天记忆、私信、位置（定位功能）、语音数据为敏感数据；英雄记忆按 (user_id, hero_id) 二元组隔离，账号级记忆不进英雄（K1）；跨用户泄漏在结构上不成立，M1 需补单测锁死。
- **关键风险表**：

| 风险 | 可能性 | 影响 | 缓解措施 |
| --- | --- | --- | --- |
| 活世界核心假设不成立（用户不因"离线演化"多回访） | M | H | M1 单英雄最小验证：解锁聊天用户的送礼/训练频次变化 + 世界事件提及率，不达标不扩 M2 |
| LLM 成本失控（英雄数 × 长文 × 全服 tick） | H | H | K3 护栏：羁绊 ≥3 解锁聊天、回复 ≤300 字、低频 tick（5min）、登录快进摘要不逐 tick 补算 |
| 陪伴内容安全/越界（现实话题泄漏） | M | H | D1 护栏：英雄 AI 不出游戏边界；英雄不继承账号记忆；展示层只用官方英雄名 |
| 个人开发者维护带宽不足 | H | M | 小批量分批提交；每域单 SSOT；Flag 隔离实验功能 |
| 文档与代码再次漂移 | M | M | 本 PRD 标注"代码事实反推版"；后续功能落地时同步更新对应分域 PRD |

---

## Section 8 — Release Approach

- **当前状态即发布态**：社交核心全量、Arena Flag 已开、Companion 一期完整。本 PRD 描述的是"现在线上是什么"，不是待建清单。
- **推荐下一步顺序**（依据：关键假设优先验证）：
  1. **活世界 M1 单英雄 MVP** —— 直接验证 Section 4 关键假设，资产链：立绘 + 官方角色卡 + 行为偏好表 + 数值
  2. Companion 多 bond（二期-B）—— 依赖 M1 验证结论，且禁止复活酒馆大厅
  3. 兴趣 onboarding（P1）—— 冷启动体验，成本低收益直接
- **MVP 定义（针对下一阶段）**：M1 最小集 = 1 名旗舰英雄 + 全屏营地页 + 小家闲聊（≤300 字）+ per-hero 记忆 + 登录快进摘要。
- **上线考虑**：
  - M1 涉及清档重开（K5：life_worlds/entities/logs 重建），内测期可接受，需提前公告
  - 清档过渡期 Hub「TA 的日常」允许空态兜底（K6）
  - 上线后头 2 周监测：LLM 调用成本、聊天解锁率、世界事件提及率、moments 空态出现率

---

> ⚠️ **薄弱章节提示**：
> - **Section 4 Goals & Metrics（thin）**：目标值为建议值，无真实业务基线；建议接入 `behavior` 埋点域数据后回填。
> - **Section 3 Personas（moderate）**：基于产品定位推断，未做用户访谈；如需加强可走用户研究流程。
> - 本 PRD 为代码事实反推版，Section 6 的 Story 级 GWT 验收标准分散在四份分域 PRD 中。
