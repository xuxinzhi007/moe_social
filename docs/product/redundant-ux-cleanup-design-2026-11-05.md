# 冗余 UX 收口设计（2026-11-05）

> 状态：**已拍板、仅文档**。本轮不写业务代码。  
> 集群盘点来源：内部扫描 memo（10 处冗余）；执行策略来源：分阶段优化调研。  
> 与路径 B 桌宠的关系：Phase 1 权限三态 chip **以后**作为 [PR #6](https://github.com/xuxinzhi007/moe_social/pull/6) 小尾巴落地，**不**并进本提交。  
> 相关： [reply-assist-screen-read-2026-11-05.md](./reply-assist-screen-read-2026-11-05.md) · [reply-assist-pet-overlay-ux-2026-11-05.md](./reply-assist-pet-overlay-ux-2026-11-05.md) · [../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md](../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md)

## 1. 目标

1. 用**手术式 PR 波次**收口全部 **10** 处冗余集群，降低「设置多余 / 权限不智能 / 双悬浮混淆」。
2. 对外**一个伙伴表面**：微信旁是贴纸桌宠救场（路径 B 只复制）；App 内是 Companion 陪聊。旧 App「AI 助手」社区浮标是桌宠的**前身**，不是长期并存的第二套悬浮。
3. 权限漏斗：**缺啥亮啥、回前台自动刷新**；隐私「特殊权限」不再空壳。
4. `showExperimentalFeatures=false` 时不泄漏 AutoGLM / 回复参谋 / GameLab，且 **`liveGiftPk` 不得单独露脸**。
5. 每波可独立验收、可回滚。

## 2. 已拍板决策

| # | 决策 | 含义 |
|---|------|------|
| D1 | **手术式 PR 波次** | 覆盖全部 10 集群。不做 mega PR，也不先重写整棵设置 IA。 |
| D2 | **Phase 1 挂 PR #6 尾巴** | 权限三态 chip 后续作为小 diff 挂在同一 PR；**本文件提交仍只文档**。 |
| D3 | **桌宠是后继表面** | 旧 App「AI 助手」社区浮标 = 前身；叙事是 **deprecate / replace**，不长期双悬浮。 |
| D4 | **`liveGiftPk` 跟实验总开关** | `showExperimentalFeatures` 关 → 礼物 PK **不得**出现在高级区或其它入口。 |
| D5 | 作者与元数据 | 提交 / PR：**无**外部工具品牌页脚；作者保持仓库既有身份。 |

产品记忆（不变）：社交主壳收口；外救场 ≠ 内陪聊；路径 B 只复制不代发；`replyAssistPrototype` 默认关。

## 3. 非目标（Non-goals）

- 不重写整棵设置 IA；不把设置大改当起步。
- 不合并 Companion chat API 与 Suggest。
- 不启用 AutoGLM 手势 / 代发 / 不把 `AutoGLMService` 注册进 Manifest。
- 不做空树截图 OCR、前台保活 FGS、电池优化引导。
- 不改路径 B 产品边界（只复制、不代点）。
- 本轮不实现权限 chip 或其它代码。

## 4. 为何是手术式波次

| 打法 | 结论 |
|------|------|
| 手术式小 PR（D1） | **采用**。风险低、可回滚；#1 才允许挂 PR #6 尾巴。 |
| 一个 mega PR 清 10 处 | **否决**。与桌宠 MVP 验收缠死。 |
| 先做设置 IA 大改再填权限 | **否决为起步**。当前痛点是权限不智能；IA 最多作为 P3/P5 局部收口。 |

## 5. 阶段 P0–P5

| Phase | 覆盖集群 | PR 策略 | 成功标准 |
|-------|----------|---------|----------|
| **P0 冻结** | 文档 | 本文件（已完成） | 10 个 ID 冻结；拍板写入 §2 |
| **P1 权限漏斗** | **#1**（#9 侧写） | **以后** PR #6 小尾巴；**本提交不做** | 三态 chip；缺权只跳缺的；回前台自动刷新 |
| **P2 藏死孤儿** | **#3 #6**（#7 副标题） | 新 chore PR，勿塞进桌宠验收 | Flag 关无 AutoGLM 副标题；孤儿 xml/死 strings 删除或改只读 |
| **P3 入口分条 + 浮标退役叙事** | **#4 #5**（#7 入口） | 新 chore PR | 词表分条；社区浮标标成旧入口/将下线；桌宠才是系统级后继 |
| **P4 隐私中枢** | **#2 #9** | 新 chore PR | 「特殊权限」有无障碍/悬浮窗状态；一键≠特殊权限 |
| **P5 配置面与壳** | **#8 #10**（残余 #7） | 新 chore PR | 模型主路径一条；`liveGiftPk` 跟实验总开关；搜索死链处理 |

```
#1 → P1（#6 尾巴，未实施）
#2 → P4
#3 → P2
#4 → P3（deprecate 社区浮标 / 桌宠后继）
#5 → P3
#6 → P2
#7 → P2 文案 + P3 入口 + P5 liveGiftPk
#8 → P5
#9 → P4（+ P1 侧写）
#10 → P5
```

## 6. 逐集群：keep / merge / hide / delete

| # | 集群 | 处置 | 目标一行 |
|---|------|------|----------|
| **1** | 回复参谋权限漏斗 | **keep 页 + merge 状态模型** | 三枚 chip：无障碍 / 悬浮窗 / 桌宠；缺→点亮→只跳对应系统页→回前台刷新 |
| **2** | 隐私特殊权限空壳 + 一键全开 | **keep 隐私页 + merge 特殊权限；改一键语义** | 列出无障碍+悬浮窗（状态+去设置）；一键=仅 runtime 未授权，不含特殊权限 |
| **3** | AutoGLM 孤儿引导 | **hide 入口**（flag 外不可达）；**keep 源码**暂不删大文件 | 高级区无 AutoGLM 菜单/副标题；深链打开则标明「服务未注册」 |
| **4** | 双重悬浮表面 | **deprecate 社区「AI 助手」浮标 + replace 为贴纸桌宠** | 桌宠是后继系统表面；不长期双悬浮。P3 先改叙事与入口，再 hide/delete 浮标实现 |
| **5** | AI 命名分裂 | **merge 词表** | 社区 AI（旧/将下线）· AI 伙伴 · 伙伴·回复参谋；（开发者）AutoGLM 实验。废弃「悬浮助手」混指 |
| **6** | 孤儿 a11y XML + 死文案 | **delete 未引用资源；rewrite 仍引用的 description** | 只留 `reply_assist_accessibility_service_config.xml`；删自动化/「弹出悬浮球」死 strings |
| **7** | Flag 关仍泄漏 | **hide 文案与入口** | 实验总开关关：不提 AutoGLM/回复参谋/GameLab；**`liveGiftPk` 同样不得露面** |
| **8** | 三套模型配置面 | **merge 主入口；hide AutoGLM 配置** | 主路径：设置→高级→AI 模型；伙伴 provider 降为高级或链回同一页 |
| **9** | 权限散点 vs 隐私中枢 | **merge 到隐私展示；keep 场景按需申请** | 隐私=总览+特殊权限；评估去掉未用 `ACCESS_BACKGROUND_LOCATION` |
| **10** | 设置壳 / 搜索死链 | **delete 或 demote 空壳；fix 索引** | 「即将上线」不可点或隐藏；搜索「模型记忆线」指向真模块或删词 |

### 关键路径（举证）

- #1 `lib/pages/reply_assist/reply_assist_page.dart`；`MainActivity.kt`（`canDrawOverlays` / `toggleOverlay`）
- #2 `lib/pages/settings/privacy_settings_page.dart`
- #3 `AutoGLMService.kt`；`lib/pages/autoglm/*`；`settings_advanced_section.dart`（Manifest **未**注册该 Service）
- #4 `floating_virtual_avatar_host.dart` + `virtual_avatar_settings_page.dart`（前身）；`ReplyAssistPetOverlay.kt`（后继）
- #6 `res/xml/accessibility_service_config.xml`（Manifest 未引用）；现用 `reply_assist_accessibility_service_config.xml`
- #7 `lib/constants/feature_flags.dart`（`liveGiftPk` 须改为跟随 `showExperimentalFeatures`）
- #8 `llm_model_config_page.dart` / `ai_provider_profiles_page.dart` / `autoglm_config_page.dart`

## 7. Phase 1 目标 UX（设计冻结，本轮不实现）

现状：`_AndroidControls` 只有无障碍文案 + 桌宠显隐；无「悬浮窗是否已授权」；`toggleOverlay` 缺权时静默跳系统页；回 App 靠手点刷新。

目标：

```
[ 无障碍 ●/○ ]  [ 悬浮窗 ●/○ ]  [ 桌宠 开/关 ]
     ↑ 缺则主色描边 + 「去开启」
```

1. 三态：`a11yEnabled`（已有）· `overlayPermissionGranted`（**新查询**，与是否显示桌宠分离）· `overlayVisible`
2. 缺无障碍 / 缺悬浮窗：只跳对应系统页，并短说「只读聊天、不代操作」或「贴纸层」
3. 点桌宠：两权都绿才 `toggleOverlay`；否则聚焦第一枚缺权 chip，不连跳两个系统页
4. `AppLifecycle` `resumed` → 自动刷新；手动「刷新」降为兜底
5. 首次开启（SharedPreferences 一次）：伙伴·回复参谋 = 读屏建议 + 自己粘贴
6. **不做**：不在 P1 填满隐私页；不申请通知/电池/截图

验收（实施 PR 时）：冷启动两权皆红；只开无障碍则悬浮窗仍红；从系统返回无需手点即变绿；Flag 关整页不可见；文案不与旧「悬浮助手」混用。

## 8. 集群 #4 叙事（覆盖调研里的「先分条再看数据」）

调研曾建议社区浮标先分条、物理删除另议。 **已改：不长期双悬浮。**

| 表面 | 角色 |
|------|------|
| 旧 App「AI 助手」社区浮标（`floating_virtual_avatar_host`） | **前身**。P3 起 deprecate 文案；后续 hide/delete，不作为第二长期入口 |
| 贴纸桌宠（`ReplyAssistPetOverlay`，路径 B） | **后继**。微信旁救场；只复制 |
| Companion Hub / 聊天 | App **内**陪聊，不是第三套悬浮 |

P3 允许短暂「旧入口可见但标明将下线」，那是过渡，不是产品终态。

## 9. 暂不触碰

OCR / 截图识图、FGS / 划掉 App 保活、启用 AutoGLM、合并 chat+Suggest、本轮物理删除 `AutoGLMService.kt`、iOS 对等桌宠、上架权限声明大修。

## 10. 实施顺序（一句话）

**P0 本文 → P1 三态权限（#6 尾巴，另提交）→ P2 藏 AutoGLM/死 a11y → P3 命名分条并退役社区浮标叙事 → P4 隐私特殊权限 → P5 模型入口、壳/搜索、`liveGiftPk` 跟实验开关。**
