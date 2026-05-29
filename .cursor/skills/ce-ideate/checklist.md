# ce-ideate 前端审计清单

按域抽样 + 横向扫描。每项记录：通过 / 问题 / 待验证。

## A. 设计系统（Moe UI）

- [ ] 页面背景为 `Color(0xFFF5F7FA)`，非纯白/纯黑
- [ ] 主渐变 `0xFF7F7FD5 → 0xFF86A8E7` 用于强调 CTA/品牌区
- [ ] 卡片：白底、`BorderRadius.circular(20|24)`、薰衣草色柔和阴影
- [ ] 按钮：`StadiumBorder` 或 `circular(30)`，elevation 0
- [ ] 输入：胶囊浮层风格，无硬边框
- [ ] 图标：`Icons.*_rounded` 为主
- [ ] 列表/卡片入场：`FadeInUp` 或项目等价动效

## B. 组件与复用

- [ ] 设置/菜单类列表使用 `MoeMenuCard`，非裸 `ListTile`
- [ ] 头像使用 `NetworkAvatarImage`
- [ ] 无大段复制粘贴的卡片/按钮样式（应抽 widget）
- [ ] `lib/widgets/` 与页面职责清晰，build 内无重逻辑

## C. 交互与状态

- [ ] 异步前/后检查 `mounted`
- [ ] 加载：统一 `CircularProgressIndicator(color: 0xFF7F7FD5)` 或骨架
- [ ] 错误：`SnackBar` 用户可读文案，非 stack trace
- [ ] 空列表/空搜索有引导，非空白页
- [ ] 可点击区域有 `InkWell` 且 `clipBehavior` 匹配圆角
- [ ] 表单：提交中禁用、校验即时反馈

## D. 导航与信息架构

- [ ] `main_shell` Tab 与深层页面返回行为一致
- [ ] `app_routes` 命名路由与页面实际入口对齐
- [ ] 重页面 `deferred import` 有合理 loading（非长时间白屏）
- [ ] 跨 Tab 跳转后状态可预期（不丢表单/列表位置除非有意）

## E. 性能与感知

- [ ] 长列表 `ListView.builder` / 分页，非一次性 build 全量
- [ ] 图片有占位与失败回退
- [ ] Web：Rive/重资源按启动指南降级
- [ ] 避免 `Transform.scale` 在 Row/Column 内无约束

## F. 一致性与域内模式

抽样对比同域 2–3 页（如 commerce、auth、feed）：

- [ ] AppBar / 标题字号一致
- [ ] 页面水平 padding 一致
- [ ] 主次按钮层级一致（渐变主按钮 vs 文字次按钮）

## G. 代码气味（影响 UI 稳定）

```bash
# 在仓库根目录
rg "ListTile\(" lib/pages --glob "*.dart" | head
rg "BorderRadius\.zero" lib/
rg "setState\(" lib/pages -A2 | rg -v mounted
rg "!\." lib/pages --glob "*.dart"  # bang operator
```

- [ ] `flutter analyze` 无 error（warning 记入附录）

## H. moe-admin（仅当范围包含）

- [ ] 遵循 `moe-admin-theme.css` 与 admin design system
- [ ] 与 Flutter App 品牌色/语义一致（不要求像素级相同）
- [ ] 表格/表单/弹窗交互符合管理台惯例

## 抽样建议（默认一轮）

| 优先级 | 页面域 | 原因 |
|--------|--------|------|
| 高 | auth、main_shell、feed/home | 首启与留存 |
| 高 | commerce/vip、profile | 商业化与身份 |
| 中 | chat、discover、settings | 高频工具 |
| 低 | game、demo、test | 边缘路径 |

用户指定域时以用户为准。
