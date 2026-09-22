# 设计研究记录

## sky_design_system 1.10.0

参考：[pub.dev sky_design_system 1.10.0](https://pub.dev/packages/sky_design_system/versions/1.10.0)

可迁移的理念是 atomic design（Atoms → Molecules → Organisms）、主题 token、响应式布局、
浮动胶囊底栏和克制的微动画。Moe Social 已有 `MoeTokens`、Moe widgets 与 Provider 架构，
因此只吸收这些决策，不直接引入该包或替换现有主题，避免依赖和视觉回归。

## Flutter GenUI

参考：[Flutter GenUI](https://docs.flutter.dev/ai/genui)

GenUI 是由 AI agent 通过 JSON 编排已有 Flutter widget catalog 的实验性 alpha 包。适合
动态表单、推荐卡片等 Companion 场景，不适合生成核心导航或静态社交首页。生产试验必须有
白名单组件、版本化 schema、状态回传和失败回退。

## 本项目落地结论

- 页面底色从冷灰调整为带蓝雾面的浅色，保留近白内容表面。
- 采用低饱和紫/蓝/薄荷主轴；语义红绿只做小面积状态反馈。
- 阴影使用品牌色低 alpha，普通卡片控制在 6–10 blur；浮层使用更大 blur。
- 动画统一 160/260/300ms 与 `Curves.easeInOut`，并尊重 reduced motion。
