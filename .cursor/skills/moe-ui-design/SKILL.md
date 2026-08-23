---
name: moe-ui-design
description: >-
  Moe Social 的视觉设计规范与 Flutter UI 决策 Skill。用于新页面、页面重设计、组件
  调整和视觉审核；统一 Airy Moe 色彩、层级、阴影、动效与无障碍，不替换现有 MoeTokens
  或 Flutter 架构。
---

# Moe UI Design

这是 `moe-flutter` 的视觉补充 Skill。实现 Flutter UI 时先读现有 `MoeTokens`，再按本规范
选择颜色、层级和动效；不要引入第二套主题或为了视觉调整业务架构。

## 视觉方向

- **Airy Moe**：清透、低饱和、轻柔的萌系社交，不使用纯白页面背景。
- 页面背景使用带蓝色倾向的雾面浅色（目标接近 `#F5F8FC`）；卡片可用近白表面，必须
  与背景形成细微层次。
- 品牌紫、雾蓝、薄荷色作为主轴；红、绿、橙只用于语义状态或极少量强调，避免高饱和
  大色块和多色渐变争夺焦点。
- 页面先保证内容呼吸感，再添加装饰。卡片、Chip、底部导航保持同一圆角与间距阶梯。

## Token 规则

- 所有颜色、间距、圆角、字号、阴影和动画时长必须来自 `lib/theme/moe_tokens.dart`；
  新 token 先加到该文件，再使用，禁止在页面散落魔法色值。
- 页面背景优先 `pageBackground`/`surface0`，内容表面优先 `cardBackground`/`surface1`；
  `Colors.white` 仅可用于反色文字、图标或明确需要的高对比局部。
- 标准圆角：小控件 `radiusSm`/`radiusMd`，卡片 `radiusXl`，大面板 `radius2xl`，
  胶囊 `radiusFull`。间距遵循 4px 网格，页面水平留白通常为 `spaceLg`。
- 卡片阴影使用 `shadowSm`/`shadowMd` 或组件既有阴影；避免黑色高 alpha 阴影。普通卡片
  的 blur 约 6–10，浮层才使用更大的 blur，并保持低透明度。

## 微交互

- 可点击元素必须有按压、选中或加载反馈；优先复用 `MoePressable`、`MoeReveal`、
  `MoeStaggerReveal`，否则使用 `AnimatedContainer`。
- 默认曲线 `Curves.easeInOut`；快速反馈约 160ms，状态切换约 260ms，入场约 300ms，
  具体值使用 `MoeTokens.motion*`。
- 动画只表达状态变化，不延迟用户操作；支持 `MediaQuery.disableAnimations` 或项目
  reduced-motion 约定，关闭时直接呈现最终状态。

## 组件与布局

- 页面使用 `MoePageScaffold`/`AdaptivePageScaffold` 等现有骨架；禁止裸 Material `Card`、
  `ListTile` 或默认 `AppBar` 作为新设计的最终形态。
- 先建立标题、正文、辅助文字三级层级，再放图标和装饰。长文案、按钮组和 Tag 行必须
  可换行或横向滚动，窄屏不得溢出。
- 加载、空数据、错误和重试复用现有 Moe 三态组件；错误必须可见且可恢复。
- 同一能力只保留一个主入口；底栏已有入口不要再在首页卡片中重复。

## GenUI 边界

Flutter `genui` 目前是实验性 alpha。它只允许在 AI Companion 的受控实验中使用：通过
版本化 JSON schema 和白名单 widget catalog 生成动态内容，并提供解析失败回退。核心首页、
底部导航、登录和社交发帖流程禁止让模型生成任意 Widget 或改变导航结构。

## 交付检查

1. 说明 Audience、Job、Tone，并指出使用的 MoeTokens。
2. 检查纯白背景、高饱和色、重阴影、重复入口和裸 Material 组件。
3. 在窄手机与平板检查 overflow、键盘和 SafeArea；验证 reduced motion。
4. 对触及文件运行 `dart format`、`dart analyze`，必要时进行 Flutter 构建或截图冒烟。

详细 token 与 sky_design_system / GenUI 研究结论见 [references/design-research.md](references/design-research.md)。
