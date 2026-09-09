# UI 精致化改造规划（2026-09-09）

> **状态**：待实施规划 · **本轮只出方案，未改任何代码**
> **起因**：需求方判断当前 UI「太 AI 风格，看着别扭，不是精品」
> **参考物**：`adaptive_platform_ui` · `cupertino_liquid_glass` · `liquid_glass_widgets`（三者均为 iOS 26 Liquid Glass 实现）+ 原神类游戏 UI（方案 2「精致的华丽」）
> **反例**：当前 app 自身
> **数据基线**：`bec11b26`（2026-09-09）· 所有计数均为实测，命令见附录

---

## 0. 核心结论：不是缺规则，是规则只管住了 8–25% 的代码

设计系统在纸面上是对的，甚至比参考包写得更早。`lib/widgets/moe_glass_surface.dart:8-10` 的文档注释：

> 统一毛玻璃容器 … **仅用于固定位置元素（导航栏/底栏/浮层），不用于滚动列表项。**

`liquid_glass_widgets` 的 Design Philosophy：

> In iOS 26, **glass is reserved for the navigation and control layer** — the floating UI that sits above your app's content. Content areas (lists, cards, article tiles) stay opaque.

**同一条法则。** 我们早就写下来了，而且已实现 reduceMotion 降级路径。问题是覆盖率：

| 已存在的资产 / 规则 | 实测覆盖率 |
|---|---|
| `MoePageScaffold` / `AdaptivePageScaffold`（`SKILL.md:45` 明令禁止裸 `AppBar`） | `AdaptivePageScaffold(` 仅 **8 处**；裸 `Scaffold(` **107** 处、裸 `AppBar(` **64** 处（共 106 个页面文件）。另有 **31 处**走了局部封装（`AiScaffold` 6 / `panelScaffold` 5 / `build*Scaffold` 12 / `AdaptivePageScaffold` 8），AppBar 侧另有 **27 处**局部封装 → **统一骨架采用率 8/138 ≈ 6%，但「有某种抽象」为 31/138 ≈ 22%** |
| `MoeGlassSurface`（正确分层法则 + 降级） | 玻璃用法共 **9 处**：**4 处**走组件（`about_module:276` `direct_chat_page:615` `conversations_page:251` `moe_bottom_bar:181`），**5 处**手写 `BackdropFilter` 绕过（`login:521` `register:244` `user_profile:376` `profile:720` `gift_selector:232`）→ **绕过率 56%** |
| `MoeTokens.radius*` 圆角阶梯 | token **356 处** vs 硬编码字面量 **554 处** → **39% 采用率**（`BorderRadius.circular` 总计 921，其中 301 传的已是 token） |
| DESIGN_SYSTEM 把「毛玻璃卡片」列为核心原则 | 玻璃 **9 处** vs `LinearGradient` **151 处 / 64 个文件** + `RadialGradient` **14 处** |

所以「AI 味」不是审美能力问题，是**治理问题**：78% 的页面没走任何统一骨架，61% 的圆角是硬编码字面量，玻璃法则写在注释里但 56% 的调用点绕过它。

**这决定了包的取舍逻辑**：装一个包不会提高覆盖率 —— `MoeGlassSurface` 已被绕过 5/9 次，外来组件同样会被绕过。

---

## 1. 本轮纠正的 5 个错误结论

全部是未验证就断言，记录在此避免复发（与配置治理文档 §15.5 的教训同类）。

| 曾断言 | 实测 |
|---|---|
| 「登录/注册的全屏背景用了玻璃，正好是参考物的 ❌ 列」 | **错。** 玻璃在 `_buildFormCard()`（`login_page.dart:518-535`、`register_page.dart:242-256`）—— 表单卡片用玻璃**合法**。全屏那层不是玻璃，是**动画渐变光斑**（见 §4） |
| 「`blurLight/Medium/Heavy` 直接引用 0 处」 | **错。** 有 5 处：`blurHeavy` @ `about_module.dart:277`、`blurMedium` @ `login:523-524` + `register:246-247`、`blurLight` @ `moe_bottom_bar.dart:182` 及 `MoeGlassSurface:21` 默认值。真正的野值是**另外 3 个 sigma：12（`user_profile_page.dart:377`）、14（`profile_page.dart:721`）、18（`gift_selector.dart:233`）** |
| 「圆角 token 300 处 vs 硬编码 920 处 → 25%」 | **错，且错法与配置文档 §12.1 同类 —— 分母把分子算进去了。** `BorderRadius.circular` 全仓 **921** 处，其中 **301 处传的就是 `MoeTokens.radius*`**，只有 **554 处是硬编码字面量**。正确口径：token **356** 处 vs 硬编码字面量 **554** 处 → **39% 采用率**，不是 25% |
| 「裸 `Scaffold(` 134、裸 `AppBar(` 89」 | **错，raw grep 把带前缀的变体也算进去了。** 精确口径（前面不是字母）：裸 `Scaffold(` **107**、裸 `AppBar(` **64**。且仓内**已存在局部骨架封装**：`AdaptivePageScaffold(` 8 + `AiScaffold(` 6 + `panelScaffold(` 5 + `build*Scaffold(` 12 = **31 处走了某种抽象**；AppBar 侧 `SliverAppBar(` 5 + `build*AppBar(`/`contactsAppBar(` 22 = **27 处** |
| 「`LinearGradient` 159 处、`withValues(alpha:)` 1076 处、105 个页面」 | **轻微漂移。** 实测 `LinearGradient` **151**、`RadialGradient` **14**、`withValues(alpha:)` **1065**、`lib/pages/**/*.dart` **106**（`lib` 全量 **432**） |

> **口径纪律**：凡写「X 处 vs Y 处 → Z%」，必须确认 X 与 Y 互斥。本轮两次踩的都是同一坑 —— 一次分母含分子（圆角），一次模式匹配到了带前缀的同名构造（Scaffold/AppBar）。

---

## 2. 参考物规则逆推

### 2.1 三个包的定位

| 包 | 版本 / 发布 | 30 天下载 / 赞 | 环境要求 | 实现方式 |
|---|---|---|---|---|
| `adaptive_platform_ui` | 0.1.111 / 2026-07-25 | 10,299 / 386 | sdk ^3.9.2 | **Flutter plugin**（`is:swiftpm-plugin`，带原生 Swift + Podfile）；整体换壳 |
| `cupertino_liquid_glass` | 0.7.1 / 2026-09-05 | 464 / 10 | sdk ^3.11.3 | 自述「**A visual approximation — not a native UIKit bridge**」，BackdropFilter |
| `liquid_glass_widgets` | 1.4.1 / 2026-09-08 | 56,213 / 261 | **flutter >=3.41.0** | **自定义 fragment shader**（真实折射 + 高光 + 色散 + squircle） |

本仓：Flutter 3.41.6 / Dart 3.11.4 / iOS deployment target 13.0（`project.pbxproj:349,475,526`）→ 三个都能装。但 `liquid_glass_widgets` 只剩 **0.0.6** 版本余量，且 **163 个版本**、最新发布距今 1 天 → churn 极高。

### 2.2 从 `liquid_glass_widgets` 逆推的 4 条法则

**法则 A —— 玻璃只属于漂浮的控制层**

| ✅ 用玻璃 | ❌ 必须不透明 |
|---|---|
| 导航栏、Tab 栏、工具栏 | 列表 cell、表格行 |
| 浮动按钮 | **全屏背景** |
| Sheet、Popover、Menu | 可滚动内容卡片 |
| Switch、Slider、SegmentedControl | 文章 tile、媒体播放器 |

屏幕正确构成：`GlassAppBar`（玻璃）→ **不透明内容区** → `GlassTabBar`（玻璃）。

**法则 B —— 玻璃是托盘，不是包装纸**

`GlassCard`/`GlassContainer` 是内容**底下的承托面**，不是给别的玻璃控件用的样式外壳。
- ✅ 内放：`Text` `Icon` `ListTile` `GlassDivider` 标准表单控件
- ❌ 内放：`GlassSegmentedControl` `GlassSlider` `GlassSwitch` `GlassButton` `GlassChip` 等任何折射玻璃

技术原因：子控件需 `avoidsRefraction: true`，`useOwnLayer: true` 会裁掉果冻物理过冲。**视觉上即：玻璃不能套玻璃。**

**法则 C —— 效果必须有降级阶梯（三档）**

| 档 | 条件 | 表现 |
|---|---|---|
| Premium | 仅 Impeller | 完整 shader |
| Standard | 默认 | 标准 shader |
| Minimal | 无 shader 能力 | BackdropFilter + Rec.709 饱和度矩阵 + 高光描边 |

我们已有 reduceMotion 分支，但**没有「设备能力」分支**。

**法则 D —— 形状语言用真实 squircle（连续曲率），不是圆弧**

`BorderRadius.circular` 是圆弧，视觉上更平、更廉价。这是「看着别扭」里最微妙但真实的一部分。

### 2.3 从原神类游戏 UI 逆推（方案 2：精致的华丽）

关键：**原神不是「华丽」，是「每种效果只承担一个角色」。**

| 维度 | 游戏 UI 的做法 | 为什么显得精致 |
|---|---|---|
| 色板档数 | 1 主色 + 1 金属色 + 2–3 中性 + 极少语义色 | 有视觉重心 |
| 层级来源 | **材质差**（纸底 / 金属框 / 宝石点缀），不是透明度差 | 每层「摸起来」不一样 |
| 装饰的角色绑定 | 金描边=可交互；纹样=区域归属；发光=当前选中 | 装饰在**传递信息** |
| 圆角 | 克制，形状语言统一 | 同类元素尺寸一致 |
| 动效 | 短、有阻尼，只在状态变化时出现 | 页面不「表演」 |

**「AI 味」的技术成因，对照上表：**

1. **用透明度做层级** —— `withValues(alpha:)` **1065 处 / 169 个文件**，所有层看起来一样「薄」
2. **渐变换色不换材质** —— `LinearGradient` **151 处 / 64 个文件** + `RadialGradient` **14 处**，每个卡片都像壁纸
3. **色板并列无主次** —— 8 个 pastel 平级，没有重心
4. **装饰没有角色** —— 发光/渐变/圆角背景到处出现，但不代表任何状态
5. **入场动画到处都是** —— 每个页面都在动，反而没有重点

---

## 3. 与当前 `MoeTokens` 的逐项差异

`lib/theme/moe_tokens.dart`：331 行，29 个 `static const Color`。

### 3.1 实测引用数（决定改造成本的关键数据）

```
primary         289 refs / 67 files      titleText      140 / 51
hintText        124 / 47                 cardBackground  67 / 30
surfaceBorder    57 / 29                 secondary       52 / 32
pageBackground   52 / 41                 bodyText        52 / 21
surface1         47 / 23                 danger          38 / 16
inkMuted         29 /  5                 warning         23 / 12
accent           19 / 15                 success         17 / 11
surface0         15 /  7                 softChipBg      13 /  8
pastelTeal       13 /  8                 pastelOrange    12 /  6
pastelPink        9 /  3                 caption          7 /  7
lineSoft          6 /  3                 softLavenderBg   6 /  5
pastelBlue        5 /  2                 inkDark          5 /  3
gamePageBackground 3 / 1                 surface2         2 /  2
surface3          2 /  2                 mintSoft         1 /  1
greyDisabled      1 /  1
```

**两个决定性结论：**

**① 高引用 token 绝不能改名，但可以改值 —— 改值成本是 0。**
`primary`(289/67) `titleText`(140/51) `hintText`(124/47) `cardBackground`(67/30) 改名等于动几十个文件；改值只需动 `moe_tokens.dart` 一处。

**② 冗余的那批几乎是死的，删掉不要钱。**
`mintSoft`(1) `greyDisabled`(1) `surface2`(2) `surface3`(2) `gamePageBackground`(3) = **合计 10 refs / 7 文件**，5 个 token 可近乎零成本收掉。

### 3.2 色板问题（29 → 目标 ~16，分 4 档）

**问题 1：7 个近乎白色的表面色，彼此只差 1–3 个色阶**

| token | 值 |
|---|---|
| `pageBackground` / `surface0` | `#F5F8FC` |
| `softLavenderBg` | `#FAF8FF` |
| `cardBackground` / `surface1` | `#FBFCFE` |
| `gamePageBackground` | `#FFFBF5` |
| `surface2` | `#FCFDFF` |
| `surface3` | `#FEFFFF` |
| `softChipBg` | `#F2F4FB` |

`surface1`→`surface2`→`surface3` = `#FBFCFE`→`#FCFDFF`→`#FEFFFF`。**真机上是同一个颜色**，却在代码里制造「有层级」的假象。参考物用材质差分层，我们用看不见的色差分层 → 层级丢失。

**问题 2：8 个并列 pastel，无主次，且内部重复**

```
#4ECDC4 pastelTeal ┐
#91EAE4 accent     ├─ 同一青绿家族（合计 33 refs）
#A8EDEA mintSoft   ┘
#74B9FF pastelBlue ┐
#86A8E7 secondary  ├─ 同一蓝家族（合计 57 refs）
#7F7FD5 primary    ┘
#FFB347 pastelOrange (12)   #FD79A8 pastelPink (9)
```

6 个颜色其实是 2 个家族。**没有任何规则说明何时用 `accent` 何时用 `pastelTeal`** —— 这是「AI 味」最直接的来源：模型每次生成都随机挑一个。

**问题 3：文档自我矛盾（硬伤）**

`.cursor/skills/moe-ui-design/SKILL.md:19-20`：

> 品牌紫、雾蓝、薄荷色作为主轴；**红、绿、橙只用于语义状态或极少量强调**

但 `moe_tokens.dart` 里 `pastelOrange` `pastelPink` `pastelTeal` `pastelBlue` `mintSoft` 全是**品牌级 token**，与语义色 `success #2E7D32` / `danger #E53935` / `warning #FF6F00` 平级共存。**规范禁止的事，token 表在鼓励。**

**问题 4：6 个灰来自 3 个色相家族**

```
#2D3436 inkDark(偏冷绿)   #333333 titleText(纯中性)   Colors.black87 bodyText
#3D3D50 caption(偏蓝紫)   #636E72 inkMuted            #9E9E9E hintText   #B2BEC3 greyDisabled
```
**同一屏正文会有三种色温。**

**问题 5：跨端品牌色不一致**
Flutter `primary #7F7FD5` vs 管理台 `tokens/colors.css --brand-violet #6b5fc1` —— 同一品牌紫，两个值。

**目标色板（4 档，每档职责明确）**

| 档 | 数量 | 职责 | 收敛来源 |
|---|---|---|---|
| **主色** | 1（+深/浅各 1 态） | 品牌识别、主行动点 | `primary #7F7FD5` 保留，**管理台对齐同值** |
| **金属/点缀** | 1 | 精致感来源：描边、选中发光、纹样 | 新增（金或铜），**接管 4 个并列 pastel 的装饰职能** |
| **中性** | 3 表面 + 4 文字 + 1 线 | 层级**只靠这 3 个表面** | 7 近白 → 3；6 灰 → 4 且统一色温 |
| **语义** | 4 | 只表达状态 | 保留，**pastel 系彻底移出本档** |

### 3.3 圆角：阶梯对，执行漏

12 档：`radiusSm 8` `radiusMd 12` `radiusLg 16` `radiusXl 20` `radius2xl 24` `radiusButton 25` `radiusInput 15` `radiusFull 9999` `radiusCard=radiusXl` `radiusCardLarge=radius2xl` `radiusIconBg 14`。

- **`radiusInput 15` `radiusIconBg 14` `radiusButton 25` 是野值** —— 不在 4px 网格（`SKILL.md:30` 明确要求）。其中 `radiusInput` 已被用 9 次、`radiusButton` 23 次，**野值已经在扩散**
- 9 个语义名 + 3 个别名，实际只有 6 个不同数值
- 真问题是 **554 处硬编码数字字面量**（`BorderRadius.circular` 总计 921，其中 **301 处传的已是 token**）→ 采用率 39%
- 已走 token 的分布：`radiusLg` 74 · `radiusFull` 51 · `radiusMd` 47 · `radiusXl` 44 · `radius2xl` 25 · `radiusButton` 23 · `radiusSm` 16 · `radiusInput` 9 · `radiusCard` 8 · `radiusCardLarge` 4
- 另有第二套圆角体系在并行：`AiTheme.radiusAiCard`（4 + 3 处）—— **AI 模块自带一套 token，未与 `MoeTokens` 合流**

### 3.4 阴影：已自标 legacy 但未清

`shadowSm()` blur 6 · `shadowMd()` 10 · `shadowLg()` 40 · `shadowButton()` 12 · `shadowCard()` 4 · `cardShadow({tint, blur=10})` **已标「Legacy — 使用 shadowMd 替代」**仍存在。
`shadowLg` blur 40 与 `SKILL.md:32`「普通卡片 blur 约 6–10，浮层才用更大 blur」冲突 —— 需确认调用点是否全在浮层。

### 3.5 玻璃：token 齐、组件对，就是没人用

| 项 | 状态 |
|---|---|
| `blurLight 8` / `blurMedium 16` / `blurHeavy 24` | 5 处引用（见 §1 纠正） |
| 绕过 `MoeGlassSurface` 的 5 处 | `login:521` `register:244` `user_profile:376` `profile:720` `gift_selector:232` |
| 其中用了野 sigma 的 3 处 | 12 / 14 / 18 —— **三档 token 之外** |
| reduceMotion 降级 | ✅ 已有（`moe_glass_surface.dart:34-45`） |
| 设备能力三档降级 | ❌ 无 |
| squircle 连续曲率 | ❌ 无，用 `ClipRRect` 圆弧 |
| 玻璃嵌套防护 | ❌ 无，无法阻止 Glass 套 Glass |
| `Colors.white` 当玻璃 tint | ⚠️ `login:530` `register:253` 用 `Colors.white.withValues(alpha: 0.72)`，违反 `SKILL.md:28` |

`login` / `register` 把 `MoeGlassSurface` 的完整结构（`ClipRRect` + `BackdropFilter` + `Container(alpha tint + surfaceBorder + shadowCard)`）**逐行手写了一遍** —— 是 5 个绕过点里最容易收的 2 个。

### 3.6 骨架：最大的洞，而且已经裂成多套

**裸 `Scaffold(` 107 处、裸 `AppBar(` 64 处**（106 个页面文件 / `lib` 全量 432 个 dart 文件）。

但更麻烦的是**仓内已经长出了多套互相竞争的局部骨架**：

```
Scaffold 侧：AdaptivePageScaffold( 8   AiScaffold( 6   panelScaffold( 5
             buildScaffold( 2  buildLoggedOutScaffold( 2  buildListScaffold( 2
             buildFullscreenScaffold( 2  buildFormScaffold( 2  buildDetailScaffold( 2
AppBar 侧：  buildSliverAppBar( 6  buildAppBar( 6  contactsAppBar( 5
             buildStandardAppBar( 3  buildChatAppBar( 2  SliverAppBar( 5
```

`SKILL.md:45` 要求「页面使用 `MoePageScaffold`/`AdaptivePageScaffold` 等现有骨架」，但**统一骨架只有 8 处采用，另外 23 处走的是 8 个各自为政的局部封装**。这比「全都裸写」更难收 —— 现在不是 1 套规范 vs 0 套实现，而是 **1 套规范 vs 13 套局部实现**。

> **口径更正（2026-09-09）**：本节与 §5 原先写的「**9 套**」不是任何一个一致的口径 —— 既不是类名数也不是文件数，看起来是「Scaffold 侧 8 个局部封装 + 1 套统一骨架」相加得来的，但那样就把「规范」自己算进了「实现」，而且完全漏掉了 AppBar 侧。按「**去掉框架自带（`Scaffold`/`AppBar`/`SliverAppBar`）与统一骨架（`AdaptivePageScaffold`）后，仓内自定义的局部封装名**」这个口径实测：

| 侧 | 局部封装名 | 个数 | 调用点 |
|---|---|---|---|
| Scaffold | `AiScaffold` `panelScaffold` `buildScaffold` `buildLoggedOutScaffold` `buildListScaffold` `buildFullscreenScaffold` `buildFormScaffold` `buildDetailScaffold` | **8** | 23 |
| AppBar | `buildSliverAppBar` `buildAppBar` `contactsAppBar` `buildStandardAppBar` `buildChatAppBar` | **5** | 22 |
| 合计 | | **13** | **45** |

上面代码块里逐个列的名字与调用点数已复核，**全部准确**；错的只是把它们汇总成「9」这一步。

`lib/theme/moe_page_scaffold.dart` 全文 6 行，只是 `typedef MoePageScaffold = AdaptivePageScaffold;` —— **这层抽象目前是纯装饰性的，既无强制力也几乎无采用率。**

### 3.7 加载与骨架屏：比 §3.6 健康得多，但仍有 6 处便宜的收口

> 本节是 2026-09-09 补测的。之前口头把它描述成「骨架屏碎成 19 个互相竞争的包装器」—— **那个说法是错的**，「互相竞争」不成立，19 也不是包装器数。**19 这个数是真实存在的，但它属于另一件事**：`LoadingKeys` 声明了 27 个操作键、只有 8 个被引用，**死键正好 19 个**（见下表 f 项）。把「死键数」当成「竞争包装器数」，正是配置治理文档 §15.5 那个教训的 UI 版（数字本身可能是真的，挂错了对象就成了假结论；§13.3「命中不等于消费」同理）。

**三层结构，前两层是收敛的：**

| 层 | 实现 | 实测 | 判定 |
|---|---|---|---|
| 状态源 | `LoadingProvider`（`ChangeNotifier`，`providers/loading_provider.dart:7`）+ `LoadingKeys`（`:183`） | `LoadingProvider` **28 行 / 9 文件**（含定义与 `main.dart:296` 装配）；`LoadingKeys` **24 行 / 7 文件**；并集 52 行 / 9 文件 | ✅ **单一真源**，无竞争实现（但见 f） |
| 微光基底 | `MoeShimmer`（`widgets/motion/moe_shimmer.dart`） | 3 处调用（`skeleton_loading.dart:9` `ai_loading_skeleton.dart:31` `network_image.dart:65`） | ✅ 两套骨架屏**共用同一个**，没有各写一份动画 |
| 骨架屏原语 | `_SkeletonBase`（`skeleton_loading.dart:7`，`abstract final class`，提供 `.shimmer/.circle/.line/.rect`） | 仅 `skeleton_loading.dart` 内部使用 | ✅ 设计良好，全程走 `MoeTokens.*` |

**问题都在第三层，而且都很小：**

| # | 问题 | 位置 | 实测 | 成本 |
|---|---|---|---|---|
| a | `UserListSkeleton` **零调用点** | `skeleton_loading.dart:125` | 只有构造声明，无任何 `UserListSkeleton(` | 纯删 |
| b | `MoeShimmerBlock` **零调用点** | `moe_shimmer.dart:41` | 同上 | 纯删 |
| c | `AiLoadingSkeleton` **不复用 `_SkeletonBase`**，自带私有 `_SkeletonCard`，圆角走 `AiTheme.radiusAiCard`(=18，阶梯外) | `ai_loading_skeleton.dart:6,26,36`（全文仅 41 行） | 1 处调用（`ai_provider_profiles_page.dart:1501`） | 低：把 `_SkeletonBase` 提为公开原语后重写这 41 行 |
| d | `OperationLoadingWidget` 与 `LoadingButton` **是同一个模式的两次实现** —— 都是 `Consumer<LoadingProvider>` + `operationKey` | `app_message_widget.dart:60,116`（同文件 `:24` 的 `AppMessageWidget` 是第三个） | `OperationLoadingWidget` 2 处（都在 `login_page.dart:450,453`，且**互相嵌套**）；`LoadingButton` 4 处 / 4 文件 | 中：`OperationLoadingWidget` 可被 `LoadingButton` 覆盖 |
| e | `_buildPlaceholder` 有 **2 份定义** | `avatar_image.dart:65` + `avatar_preview.dart:207` | 两个头像组件各手写一份占位 | 低 |
| f | `LoadingKeys` 声明 **27** 个操作键，只有 **8** 个被引用 → **19 个死键（70%）** | `providers/loading_provider.dart:183-211` | 在用：`updateProfile` 5 / `saveAgent` 4 / `wechatLogin` 3 / `recharge` 3 / `login` 2 / `feishuLogin` 2 / `register` 2 / `createPost` 2。未用：`uploadImage` `getPosts` `getComments` `likePost` `likeComment` `followUser` `unfollowUser` `createVipOrder` `updatePassword` `resetPassword` `sendResetCode` `verifyResetCode` `deleteUser` `updateAvatar` `purchaseEmojiPack` `purchaseAvatarOutfit` `llmChat` `syncVipStatus` `addComment` | 纯删 19 行 |

对比 §3.6：那里是「1 套规范 vs 13 套实现、107 处裸写」，这里**没有规范缺位**，只有 2 个死类、19 个死键、1 个不复用的骨架、1 组重复模式、2 份重复占位。**a/b/e/f 四项是零风险纯删除**，可以和后端第五批（配置治理文档 §17）一样当卫生项直接做；c/d 属于本规划「明确不做」之外的小额改动，但也应该排在 §5 的第 1–5 步之后 —— 它们的视觉收益接近 0。

> f 项值得单独说一句：这 19 个死键**不是遗留垃圾，而是「先把所有操作都登记一遍」的前瞻式声明**。它们让 `LoadingKeys` 看起来像是全局加载状态的完整清单，实际只覆盖 8 个操作 —— 于是「某页转圈没有走 `LoadingProvider`」这件事在代码里查不出来，只能靠人记得。删掉死键之后，`LoadingKeys` 的成员数才等于事实上的覆盖面。

---

## 4. 最高优先级单点：`lib/widgets/auth_background.dart`

**197 行，只被 2 个页面使用（`login_page.dart:431` + `register_page.dart:212`）—— 但它是全仓「AI 味」浓度最高的文件，且在每个用户看到的第一屏。**

```
:27-30   AnimationController(duration: 12s)..repeat()   ← 永不停止，两个最高频页面常驻 GPU
:47-50   4 个魔法色 Color(0xFFE0C3FC / 0xFF8EC5FC / 0xFF91EAE4 / 粉)  ← 不在 MoeTokens 里
:100-150 4 个 Lissajous 曲线漂移的渐变光斑（380/300/340/260 px）
:61,:85  2 层 LinearGradient
:190     1 个 RadialGradient
```

叠加登录页自身：渐变 Logo 容器 + 呼吸光晕 + 渐变文字 + 毛玻璃表单卡片 + 渐变分隔线 + 渐变文字 + 3 个 `MoeReveal` 入场动画（`login_page.dart:431-470` 注释逐条写明）。

**一屏之内：6 层渐变 + 4 个乱飘彩色光斑 + 1 个永久动画 + 3 段入场动画。**「紫蓝青粉四个柔光球在磨砂玻璃卡片后面飘」是 AI 生成落地页最标志性的图案。

违反 3 条既有规范：
- `SKILL.md:26`「禁止在页面散落魔法色值」→ 4 个 `Color(0xFF...)`
- `SKILL.md:38`「动画只表达状态变化」→ 12s `repeat()` 不表达任何状态
- `SKILL.md:20`「避免多色渐变争夺焦点」→ 4 色光斑

### 三个处置方案

| 方案 | 做法 | 结果 |
|---|---|---|
| (a) 全删 | 换成 `MoeTokens.surface0` 纸底 + 极轻单色纹理 | 最干净，最贴近法则 A；萌系氛围会掉 |
| **(b) 静化 + 收口（推荐）** | 删 `AnimationController` 与 Lissajous；4 光斑 → **1 个静态柔光**；4 魔法色进 `MoeTokens`；保留 `reduceMotion`(:41) 与 `compact`(:44-45) 分支 | 保留氛围、去掉噪音。**符合方案 2 核心：一片静态柔光=氛围，4 个乱飘彩球=争夺焦点** |
| (c) 最小改 | 只把 4 个魔法色收进 token，动画保留 | 修了规范违规，没修「AI 味」 |

**未定岔路**：(a) 与 (b) 的差别是萌系氛围保留多少，需需求方拍板。当前推荐 (b)。

---

## 5. 改造方案（5 步）+ 影响面

**总原则：先立法与收口，再谈精致。** 顺序不能反 —— 在 8% 覆盖率的地基上加华丽效果，只会让「AI 味」变成「AI 味 + 更多效果」。方案 2 是第 4 步，不是第 1 步。

### 优先级排序（收益/成本）

| 候选改动 | 触点 | 视觉收益 | 评级 |
|---|---|---|---|
| **`auth_background.dart`** | **1 文件 + 2 页** | **极高**（第一屏印象） | ★★★ |
| `moe_tokens.dart` **改值不改名** | **1 文件，0 调用点** | 中（全局一致性） | ★★★ |
| CI/lint 断言 | 0 页面 | 防回退（非变好看） | ★★★ |
| 3 个野 sigma 归位 | 3 处 | 低-中 | ★★ |
| 5 个近死 token 删除 | 10 refs / 7 文件 | 0（纯卫生） | ★★ |
| §3.7 a/b/e：`UserListSkeleton` + `MoeShimmerBlock` 零调用点、`_buildPlaceholder` 两份定义 | 2 类 + 2 方法 / 4 文件 | 0（纯卫生） | ★★ |
| 青绿家族 3→1 | 33 refs | 中 | ★ |
| 蓝家族 2→1 | 57 refs | 中 | ★ |
| 151 处 `LinearGradient` + 14 处 `RadialGradient` | 64 文件 | 高 | ★ |
| 107 裸 `Scaffold` + 64 裸 `AppBar` + 收编 13 套局部骨架（§3.6 口径更正） | 106 页 | 高 | ✗ 最贵 |
| 554 处硬编码圆角字面量 | 161 文件 | 中 | ✗ 最贵 |

### 第 0 步 · 存基线截图（改任何东西之前）

登录页 + 注册页各存一组。**这是唯一验收手段** —— 纯视觉改动 `flutter analyze` / `flutter test` 全绿也发现不了变丑。

### 第 1 步 · `auth_background.dart`（197 → 约 60 行）

按 §4 方案 (b)。

### 第 2 步 · 登录/注册玻璃收口（2 处）

`login_page.dart:518-535` `_buildFormCard()` 与 `register_page.dart:242-256` 改调 `MoeGlassSurface`，去掉 `Colors.white.withValues(alpha: 0.72)`。收完覆盖率 4/9 → 6/9。

> **第 1+2 步做完即截图对比一次。** 若「AI 味」确实来自这里，第 3–5 步才有意义。

### 第 3 步 · `moe_tokens.dart`（改值不改名）

- 删 5 个近死 token：`surface2` `surface3` `mintSoft` `greyDisabled` `gamePageBackground` = 10 refs / 7 文件
- **改值不改名**：7 近白 → 3 档表面；6 灰统一色温；青绿三兄弟与蓝两兄弟各指向单一值
- `radiusInput 15` / `radiusIconBg 14` / `radiusButton 25` 归 4px 网格
- 删已标 legacy 的 `cardShadow()`
- **绝不动名**：`primary`(289/67) `titleText`(140/51) `hintText`(124/47) `cardBackground`(67/30)
- 兼容做法：旧名保留为 `@Deprecated` 别名指向新值，**一次改值、分批改引用**

### 第 4 步 · 3 个野 sigma 归位

`user_profile_page.dart:377`(12) · `profile_page.dart:721`(14) · `gift_selector.dart:233`(18) → `blurMedium`/`blurHeavy`

### 第 5 步 · CI 断言（防回退，0 页面）

禁止 `lib/pages/**` 出现裸 `Scaffold(` / `AppBar(`、`BorderRadius.circular(<字面量>)`、`MoeGlassSurface` 之外的 `ImageFilter.blur(`。**先设 warning 跑一轮，看清违规基数再转 error。**

> 没有这一步，前面几步都会在下一个 PR 被回退。**当前 8%/25% 的覆盖率就是「只有文档规范、没有机械约束」的直接结果。**

### 后续（本规划不含）

- **材质三层建模**（方案 2 本体）：纸（不透明暖白，承载所有滚动内容）/ 玻璃（仅导航栏、底栏、Sheet、FAB）/ 金属（描边+微光，绑定「可交互」「选中」「区域归属」）。每种效果只承担一个角色。
- `MoeGlassSurface` 补三件事：设备能力三档降级（法则 C）、debug 模式嵌套断言（法则 B）、squircle（法则 D）。
- 106 页骨架迁移，且**必须先收编 13 套局部封装**（Scaffold 侧 8 个：`AiScaffold` / `panelScaffold` / `build*Scaffold`；AppBar 侧 5 个：`build*AppBar` / `contactsAppBar`，明细见 §3.6 更正表），否则只是把「1 套规范 vs 13 套实现」变成「1 套规范 vs 14 套实现」。分 4 批：底栏 4 主页+登录注册 ~6 → 会话聊天链路 ~15 → 设置资料 ~20 → 长尾 ~65。
- 建议单页试点 `lib/pages/chat/conversations_page.dart`（已用 `MoeGlassSurface`，同时有裸 `Scaffold`、硬编码圆角、渐变，四种问题齐全），实测「每页改造成本」后再启动 106 页。

### 明确不做

- ❌ 106 页骨架迁移与 13 套局部封装收编（太贵，等 CI 断言立住再分批）
- ❌ §3.7 的 c/d（`AiLoadingSkeleton` 改用 `_SkeletonBase`、`OperationLoadingWidget` 并入 `LoadingButton`）—— 视觉收益接近 0，本轮只做 a/b/e 三项纯删除
- ❌ 554 处硬编码圆角字面量、151 处 `LinearGradient` 的全量清理
- ❌ 装任何包
- ❌ 金属层精致化（必须在覆盖率上来之后）
- ❌ 管理台 `--brand-violet` 与 Flutter `primary` 对齐（跨端，另开一轮）
- ❌ `AiTheme` 与 `MoeTokens` 两套 token 体系合流（需单独立项）

---

## 6. 包的取舍裁决

| 包 | 裁决 | 理由 |
|---|---|---|
| `adaptive_platform_ui` | ❌ **不采用** | ① 要求整体换壳（`AdaptiveApp`/`AdaptiveScaffold`/`AdaptiveAppBar`/`AdaptiveBottomNavigationBar`），我们要动的是 134 个裸 Scaffold，等于全仓重写；② **命名冲突** —— 已有 `AdaptivePageScaffold`；③ 是 Swift plugin，会给只有 25 行 Swift 的仓库引入原生 Podfile 依赖；④ **目标相反** —— 它追求「像平台原生」，我们要有品牌识别的萌系；⑤ 还需额外挂 3 个 localization delegate |
| `cupertino_liquid_glass` | ❌ **不采用** | 三个里最不成熟（464 下载 / 10 赞 / 9 版本），自述是 "visual approximation" —— 与现有 BackdropFilter 同档次，装了不解决问题 |
| `liquid_glass_widgets` | ⏸ **暂不装，作为后续候选** | 唯一有真 shader（折射/高光/色散/squircle），三档降级设计值得直接抄。**但** flutter >=3.41.0 而本仓 3.41.6，仅 0.0.6 余量；163 版本、昨天刚发新版，churn 极高；引入 `.frag` 资产与构建步骤。**先把它的设计法则与降级阶梯吸收进自有 `MoeGlassSurface`，等第 0–5 步落地后再评估接它的 Premium 模式。** |

**可零依赖直接吸收的 4 样**：法则 A 玻璃/内容分工、法则 B 托盘非包装纸 + 嵌套断言、法则 C 三档质量降级、法则 D squircle 曲率。

---

## 7. 风险

1. **纯视觉回归测试抓不到** —— 色板合并、圆角归网格这类改动，analyze/test 全绿但界面可能变丑。唯一手段是截图对比，故第 0 步必须先做。
2. **squircle 与 `ClipRRect` 的性能差** —— 连续曲率路径比圆弧贵，长列表内不能用（正好呼应法则 A）。
3. **第 3 步改值会影响已截图的页面** —— 必须在第 1+2 步截图对比之后再改值，并再截一轮。
4. **105 页迁移必须分批** —— 每批独立可回滚，否则一个 PR 无法 review。

---

## 附录：复核命令

> ⚠️ **三个必须避开的口径陷阱**（本文 §1 的第 3、4 条踩了前两个，§3.7 踩了第三个）：
> ① `grep "Scaffold("` 会把 `AdaptivePageScaffold(` `AiScaffold(` 一并算进去，必须用「前面不是字母」的模式；
> ② `BorderRadius.circular` 的总数里**包含**传 token 的那 301 处，拿它当「硬编码数」会让分母含分子；
> ③ `grep "Xxx("` **会把构造声明行 `const Xxx({super.key});` 也算成一次调用**，每个类都虚高 1。判「零调用点」必须先看命中行是不是 `const Xxx(`，否则会漏掉死类 —— `UserListSkeleton` / `MoeShimmerBlock` 的 raw 计数都是 1，真实调用点是 **0**。

```bash
# 玻璃站点与 sigma
grep -rn "BackdropFilter" lib --include='*.dart'
grep -rn "ImageFilter.blur" lib --include='*.dart'
grep -rn "MoeGlassSurface(" lib --include='*.dart'
grep -rn "blurLight\|blurMedium\|blurHeavy" lib --include='*.dart'

# 骨架覆盖率（注意 ^|[^A-Za-z] 前缀断言）
grep -rEn "(^|[^A-Za-z])Scaffold\(" lib --include='*.dart' | wc -l   # → 107
grep -rEn "(^|[^A-Za-z])AppBar\("   lib --include='*.dart' | wc -l   # → 64
grep -rEoh "[A-Za-z]*Scaffold\(" lib --include='*.dart' | sort | uniq -c | sort -rn
grep -rEoh "[A-Za-z]*AppBar\("   lib --include='*.dart' | sort | uniq -c | sort -rn
grep -rn "AdaptivePageScaffold(" lib --include='*.dart' | wc -l      # → 8

# §3.6 局部封装名清点：上面两条 uniq -c 的输出里，
# 去掉 Scaffold( / AppBar( / SliverAppBar( / AdaptivePageScaffold( 后剩 13 个名字（8 + 5）

# §3.7 加载与骨架屏三层
grep -rEoh "class [A-Za-z_]*(Skeleton|Shimmer)[A-Za-z_]*" lib --include='*.dart' | sort -u
grep -rEln "class [A-Za-z_]*(Skeleton|Shimmer)[A-Za-z_]*" lib --include='*.dart' | sort   # → 3 文件
for c in PostSkeleton MessageSkeleton UserListSkeleton AiLoadingSkeleton \
         MoeShimmer MoeShimmerBlock MoeLoading MoeSmallLoading \
         OperationLoadingWidget LoadingButton; do
  echo "$c:"; grep -rEn "(^|[^A-Za-z_])$c\(" lib --include='*.dart'   # 逐条看，别只数行数
done
grep -rn "_buildPlaceholder\|_buildTopicPlaceholder" lib --include='*.dart'   # → 2 份定义
grep -rn "LoadingProvider\|LoadingKeys" lib --include='*.dart' | wc -l        # 状态源引用数

# 圆角：必须分「总数 / 硬编码字面量 / 传 token」三个口径
grep -rn  "BorderRadius\.circular"        lib --include='*.dart' | wc -l   # → 921 总数
grep -rEn "BorderRadius\.circular\([0-9]" lib --include='*.dart' | wc -l   # → 554 硬编码字面量
grep -rn  "MoeTokens\.radius"             lib --include='*.dart' | wc -l   # → 356 token
grep -rEoh "BorderRadius\.circular\([^)]*\)" lib --include='*.dart' | sort | uniq -c | sort -rn

# 渐变与透明度分层
grep -rn "LinearGradient"     lib --include='*.dart' | wc -l   # → 151 / 64 文件
grep -rn "RadialGradient"     lib --include='*.dart' | wc -l   # → 14
grep -rn "withValues(alpha:"  lib --include='*.dart' | wc -l   # → 1065 / 169 文件

# token 引用数（逐 token，注意结尾断言防止 primary 匹配到 primaryXxx）
grep -rEo "MoeTokens\.NAME([^A-Za-z0-9_]|\$)" lib --include='*.dart' | wc -l

# 规模
find lib/pages -name '*.dart' | wc -l   # → 106
find lib       -name '*.dart' | wc -l   # → 432
```

## 相关文档

- 视觉规范 SSOT：`.cursor/skills/moe-ui-design/SKILL.md`
- 现有设计系统：`docs/product/design-system.md` · `docs/product/UI设计规范.md`
- 上一轮视觉迭代：`docs/dev/ui-upgrade-iteration-2026-08-29.md`
- 动效系统：`docs/dev/flutter-motion-system.md`
