# Moe Social 设计系统规范

> 本文档是萌社交（Moe Social）视觉与交互的唯一事实来源（SSOT），覆盖 CSS 设计稿、Flutter Token 及组件使用规范。

---

## 1. 设计 Token 映射表

### 1.1 色彩系统

#### 品牌色

| Token 名 | CSS 变量 | Flutter 常量 | 色值 | 用途 |
|---------|---------|-------------|------|------|
| primary | `--color-primary` | `MoeTokens.primary` | `#7F7FD5` | 品牌主色，按钮/链接/高亮 |
| primary-hover | `--color-primary-hover` | — | `#6E6EC4` | 主色悬停态 |
| primary-light | `--color-primary-light` | — | `#9B9FE3` | 主色浅阶，标签底色 |
| primary-lighter | `--color-primary-lighter` | — | `#B7BAF0` | 主色更浅，浅背景 |
| primary-lightest | `--color-primary-lightest` | — | `#D4D5F6` | 主色最浅，极浅底色 |
| primary-dark | `--color-primary-dark` | — | `#5F5FBB` | 主色深阶，按压态 |
| primary-darker | `--color-primary-darker` | — | `#3F3FA1` | 主色最深，强调 |
| secondary | `--color-secondary` | `MoeTokens.secondary` | `#86A8E7` | 辅助色，渐变终点 |
| secondary-light | `--color-secondary-light` | — | `#A0BFEF` | 辅助色浅阶 |
| secondary-lighter | `--color-secondary-lighter` | — | `#BBD5F6` | 辅助色更浅 |
| secondary-darker | `--color-secondary-darker` | — | `#5E88C8` | 辅助色深阶 |
| accent | `--color-accent` | `MoeTokens.accent` | `#91EAE4` | 点缀色（薄荷绿），三段渐变终点 |
| pastel-orange | `--color-pastel-orange` | `MoeTokens.pastelOrange` | `#FFB347` | 暖色点缀，通知/徽章 |

#### 功能色

| Token 名 | CSS 变量 | 色值 | 用途 |
|---------|---------|------|------|
| vip-gold | `--color-vip-gold` | `#FFD66B` | VIP 会员金色 |
| vip-gold-dark | `--color-vip-gold-dark` | `#FFA94D` | VIP 金色深阶 |
| gacha-pink | `--color-gacha-pink` | `#FFB7C5` | 扭蛋粉色 |
| gacha-pink-dark | `--color-gacha-pink-dark` | `#FFA5B5` | 扭蛋粉色深阶 |
| like-red | `--color-like-red` / `--color-like` | `#FF4757` | 点赞红心 |

#### 语义色

| Token 名 | CSS 变量 | 色值 | 用途 |
|---------|---------|------|------|
| success | `--color-success` | `#34C759` | 成功/在线 |
| error | `--color-error` | `#FF4757` | 错误/危险 |
| warning | `--color-warning` | `#E6A700` | 警告 |
| info | `--color-info` | `#2563EB` | 信息 |
| success-bg | `--state-success-bg` | `#F0FDF4` | 成功背景 |
| error-bg | `--state-error-bg` | `#FEF2F2` | 错误背景 |
| info-bg | `--state-info-bg` | `#EFF6FF` | 信息背景 |
| warning-bg | `--state-warning-bg` | `#FFFBEB` | 警告背景 |

#### 中性色

| Token 名 | CSS 变量 | Flutter 常量 | 色值 | 用途 |
|---------|---------|-------------|------|------|
| page-bg | `--color-page-bg` | `MoeTokens.pageBackground` | `#F5F7FA` | 页面背景 |
| card-bg | `--color-card-bg` | `MoeTokens.cardBackground` | `#FFFFFF` | 卡片/弹窗背景 |
| input-bg | `--color-input-bg` | — | `#FFFFFF` | 输入框背景 |
| input-fill | `--color-input-fill` | — | `#F9F9F9` | 输入框填充 |
| search-bg | `--color-search-bg` | — | `#F5F5F5` | 搜索栏背景 |
| bg-sunken | `--color-bg-sunken` | — | `#EEEEF2` | 下沉区域 |
| title | `--color-title` | `MoeTokens.titleText` | `#333333` | 标题文字 |
| body | `--color-body` | `MoeTokens.bodyText` | `#212121` | 正文文字 |
| body-secondary | `--color-body-secondary` | — | `rgba(0,0,0,0.6)` | 次要文字 |
| hint | `--color-hint` | `MoeTokens.hintText` | `#9E9E9E` | 提示文字 |
| placeholder | `--color-placeholder` | — | `#BDBDBD` | 占位符/禁用 |
| text-inverse | `--color-text-inverse` | — | `#FFFFFF` | 反色文字（按钮上） |

#### 渐变色

| Token 名 | CSS 变量 | Flutter 常量 | 定义 | 用途 |
|---------|---------|-------------|------|------|
| gradient-primary | `--gradient-primary` | `MoeTokens.primaryGradient` | `135deg, #7F7FD5 → #86A8E7` | 品牌双色渐变 |
| gradient-hero | `--gradient-hero` | `MoeTokens.heroGradient` | `135deg, #7F7FD5 → #86A8E7 → #91EAE4` | 三段英雄渐变 |
| gradient-aurora | `--gradient-aurora` | — | `135deg, #E0C3FC → #8EC5FC → #91EAE4` | 极光渐变 |
| gradient-ai-bubble | `--gradient-ai-bubble` | — | `135deg, #8A2387 → #E94057` | AI 气泡渐变 |
| gradient-personalized | `--gradient-personalized` | — | `135deg, #667eea → #764ba2 → #f093fb` | 个性化渐变 |
| gradient-vip | `--gradient-vip` | — | `135deg, #FFD66B → #FFA94D` | VIP 金色渐变 |
| gradient-gacha | `--gradient-gacha` | — | `135deg, #FFB7C5 → #FFA5B5` | 扭蛋粉色渐变 |

#### 头像边框环

| Token 名 | CSS 变量 | 定义 |
|---------|---------|------|
| ring-purple | `--ring-purple` | `135deg, #7F7FD5 → #f093fb` |
| ring-red-orange | `--ring-red-orange` | `135deg, #FF6B6B → #FFB347` |
| ring-teal | `--ring-teal` | `135deg, #4ECDC4 → #44A08D` |
| ring-blue-purple | `--ring-blue-purple` | `135deg, #86A8E7 → #7F7FD5` |
| ring-yellow | `--ring-yellow` | `135deg, #FFCA28 → #FF8F00` |
| ring-deep-purple | `--ring-deep-purple` | `135deg, #AB47BC → #7B1FA2` |

---

### 1.2 间距系统

| Token 名 | CSS 变量（v2） | CSS 别名（v1） | Flutter 参考 | 值 | 用途 |
|---------|--------------|---------------|-------------|---|------|
| space-1 | `--space-1` | `--space-xs` | — | `4px` | 极小间距，图标与文字间 |
| space-2 | `--space-2` | `--space-sm` | — | `8px` | 小间距，列表项内间距 |
| space-3 | `--space-3` | `--space-md` | — | `12px` | 中间距，区块内间距 |
| space-4 | `--space-4` | `--space-lg` | `--page-padding` | `16px` | 页面水平内边距 |
| space-5 | `--space-5` | `--space-xl` | `--card-padding` | `20px` | 卡片内边距 |
| space-6 | `--space-6` | `--space-2xl` | — | `24px` | 区块间距 |
| space-8 | `--space-8` | `--space-3xl` | — | `32px` | 大区块间距 |
| space-10 | `--space-10` | `--space-4xl` | — | `40px` | 页面顶底大间距 |

---

### 1.3 圆角系统

| Token 名 | CSS 变量 | Flutter 常量 | 值 | 用途 |
|---------|---------|-------------|---|------|
| radius-sm | `--radius-sm` | — | `8px` | 小组件（标签、角标） |
| radius-md | `--radius-md` | `MoeTokens.radiusMd` | `12px` | 图标背景、小卡片 |
| radius-lg | `--radius-lg` | — | `16px` | 中型卡片 |
| radius-xl | `--radius-xl` | `MoeTokens.radiusCard` | `20px` | 标准卡片（AdaptiveSectionCard） |
| radius-2xl | `--radius-2xl` | `MoeTokens.radiusCardLarge` | `24px` | 大卡片、弹窗 |
| radius-3xl | `--radius-3xl` | — | `28px` | 超大圆角面板 |
| radius-pill | `--radius-pill` | — | `9999px` | 胶囊形（药丸） |
| radius-button | `--radius-button` | `MoeTokens.radiusButton` | `25px` | 按钮圆角 |
| radius-input | `--radius-input` | — | `15px` | 输入框圆角 |
| bottom-bar-radius | `--bottom-bar-radius` | — | `32px` | 底部导航栏圆角 |

---

### 1.4 字号系统

| Token 名 | CSS 变量 | 值 | 用途 |
|---------|---------|---|------|
| text-xs | `--text-xs` | `11px` | 超小文字（角标数字） |
| text-sm | `--text-sm` | `12px` | 小辅助文字 |
| text-base | `--text-base` | `14px` | 基准字号（正文） |
| text-md | `--text-md` | `15px` | 稍大正文 |
| text-lg | `--text-lg` | `18px` | 小标题 |
| text-xl | `--text-xl` | `20px` | 副标题 |
| text-2xl | `--text-2xl` | `24px` | 中等标题 |
| text-3xl | `--text-3xl` | `28px` | 大标题 |
| text-4xl | `--text-4xl` | `26px` | 超大标题 |
| text-5xl | `--text-5xl` | `28px` | 显示级标题 |

**字体族**：`'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`

**行高**：`--leading-tight: 1.1` · `--leading-snug: 1.3` · `--leading-normal: 1.5` · `--leading-relaxed: 1.6`

**字重**：`--weight-normal: 400` · `--weight-medium: 500` · `--weight-semibold: 600` · `--weight-bold: 700`

---

### 1.5 阴影系统

| Token 名 | CSS 变量 | 定义 | 用途 |
|---------|---------|------|------|
| shadow-card | `--shadow-card` | `0 8px 24px rgba(127,127,213,0.08)` | 卡片默认阴影 |
| shadow-card-lg | `--shadow-card-lg` | `0 10px 24px rgba(127,127,213,0.08)` | 大卡片阴影 |
| shadow-card-hover | `--shadow-card-hover` | `0 12px 32px rgba(127,127,213,0.12)` | 卡片悬停阴影 |
| shadow-button | `--shadow-button` | `0 4px 16px rgba(127,127,213,0.3)` | 按钮彩色投影 |
| shadow-float | `--shadow-float` | `0 8px 32px rgba(0,0,0,0.12)` | 浮层/弹窗 |
| shadow-nav | `--shadow-nav` | `0 -2px 16px rgba(0,0,0,0.05)` | 导航栏向上投影 |
| shadow-bottom-bar | `--shadow-bottom-bar` | `0 -5px 20px rgba(0,0,0,0.05), 0 4px 12px rgba(127,127,213,0.1)` | 底部胶囊导航 |
| shadow-compact | `--shadow-compact` | `0 5px 10px rgba(127,127,213,0.08)` | 紧凑型卡片 |
| shadow-glow-primary | `--shadow-glow-primary` | `0 0 20px rgba(127,127,213,0.25)` | 主色发光 |

Flutter 对应：`MoeTokens.cardShadow(blur: 16)` → `BoxShadow(color: primary.withAlpha(0x14), blurRadius: 16, offset: Offset(0, 8))`

---

## 2. 组件使用规范

### 2.1 按钮 — MoeBouncingButton

| 属性 | 值 | 说明 |
|------|---|------|
| 高度 | `50px` | 标准主按钮高度 |
| 圆角 | `25px`（`--radius-button`） | 全圆角胶囊形 |
| 背景 | `--color-primary` 或 `--gradient-primary` | 纯色或渐变 |
| 阴影 | `--shadow-button` | 品牌色投影 |
| 按压反馈 | `scaleFactor: 0.9`，`duration: 150ms` | 缩小弹性反馈 |
| 字号 | `15px`，`weight: 600` | 按钮内文字 |
| 动画曲线 | `--ease-elastic` | 弹性回弹 |

```dart
// 正确使用
MoeBouncingButton(
  onTap: () {},
  child: Container(
    height: 50,
    decoration: BoxDecoration(
      gradient: MoeTokens.primaryGradient,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Center(child: Text('确认', style: ...)),
  ),
)
```

### 2.2 输入框 — MoeInputField

| 属性 | 值 | 说明 |
|------|---|------|
| 圆角 | `15px`（`--radius-input`） | 柔和圆角 |
| 背景 | `--color-input-fill`（`#F9F9F9`） | 浅灰底色 |
| 边框 | 默认透明，聚焦时 `--color-primary` | 2px 描边 |
| 内边距 | `16px 20px` | 舒适打字体验 |
| 字号 | `15px` | 输入文字大小 |
| 图标 | 左侧前缀图标 | 必填项 |
| 密码切换 | `isPassword: true` 启用眼睛图标 | 自动切换 obscure |

### 2.3 底部导航 — MoeBottomBar

| 属性 | 值 | 说明 |
|------|---|------|
| 形态 | 浮动胶囊形 | 不贴底，有呼吸感 |
| 圆角 | `32px`（`--bottom-bar-radius`） | 大圆角胶囊 |
| 内边距 | `8px 20px`（紧凑屏 `6px 8px`） | 自适应宽度 |
| 阴影 | `--shadow-bottom-bar` | 双层柔和投影 |
| 选中指示 | 品牌色圆角背景 | 带弹性动画 |
| 标签字号 | `12px`（紧凑 `11px`，超紧凑 `10px`） | 响应式 |
| 宽度阈值 | `<360px` 紧凑，`<330px` 超紧凑 | 自适应布局 |

### 2.4 卡片 — AdaptiveSectionCard

| 属性 | 值 | 说明 |
|------|---|------|
| 圆角 | `20px`（`--radius-xl` / `MoeTokens.radiusCard`） | 标准卡片圆角 |
| 大圆角 | `24px`（`--radius-2xl` / `MoeTokens.radiusCardLarge`） | 突出卡片 |
| 内边距 | `20px`（`--card-padding`） | 标准内容间距 |
| 阴影 | `--shadow-card` | 品牌色柔和投影 |
| 悬停阴影 | `--shadow-card-hover` | 加深投影提供层次 |
| 背景 | `--color-card-bg`（白色/暗色 `#1E1E1E`） | 跟随主题 |

### 2.5 空状态 — MoeEmptyState

| 属性 | 值 | 说明 |
|------|---|------|
| 图标 | 默认 `Icons.inbox_rounded` | 可自定义 |
| 标题 | 必填 | 空状态说明文案 |
| 副标题 | 可选 | 补充引导文案 |
| 主操作 | `MoeEmptyStateAction` | 主要 CTA 按钮 |
| 次操作 | `MoeEmptyStateAction` | 次要操作（可选） |
| 紧凑模式 | `compact: true` | 减少纵向空间 |

### 2.6 其他组件

| 组件 | 文件 | 说明 |
|------|------|------|
| MoeActionRow | `moe_action_row.dart` | 列表设置行（图标+标题+箭头） |
| MoeSearchBar | `moe_search_bar.dart` | 搜索栏（`--color-search-bg`） |
| MoeMenuCard | `moe_menu_card.dart` | 宫格菜单卡片 |
| MoeLoading | `moe_loading.dart` | 加载动画（品牌色） |
| MoeErrorState | `moe_error_state.dart` | 错误状态（重试 CTA） |
| MoeToast | `moe_toast.dart` | 轻量提示 |
| MoeNotificationPopup | `moe_notification_popup.dart` | 通知弹窗 |

---

## 3. 页面模板规范

### 3.1 列表页模板

```
┌─────────────────────────┐
│  AppBar (渐变/纯色)       │
├─────────────────────────┤
│  [下拉刷新指示器]         │
│  ┌───────────────────┐  │
│  │ 列表项卡片         │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ 列表项卡片         │  │
│  └───────────────────┘  │
│  ...                    │
│  [MoeEmptyState 空态]   │
└─────────────────────────┘
```

- AppBar 使用 `--gradient-primary` 或纯色 `--color-primary`
- 列表项间距：`--space-3`（12px）
- 空态使用 `MoeEmptyState`
- 支持下拉刷新

**适用页面**：首页（home）、消息中心（messages）、探索（discover）、社区（community）

### 3.2 详情页模板

```
┌─────────────────────────┐
│  SliverAppBar (可折叠)   │
│  [渐变/图片头部]          │
├─────────────────────────┤
│  内容区域                │
│  ┌───────────────────┐  │
│  │ 内容卡片           │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

- SliverAppBar 支持展开/折叠
- 头部可放置渐变背景或用户头像
- 内容区使用卡片布局

**适用页面**：个人主页（profile）、VIP 中心（vip-center）

### 3.3 表单页模板

```
┌─────────────────────────┐
│  AppBar (返回 + 标题)    │
├─────────────────────────┤
│  MoeInputField × N      │
│  ...                    │
│                         │
│  [MoeBouncingButton]    │
│  提交/确认               │
└─────────────────────────┘
```

- 输入框间距：`--space-5`（20px）
- 底部按钮固定在底部或跟随内容
- 表单验证使用 `validator` 参数

**适用页面**：登录（login）、注册（register）、编辑资料（edit-profile）、发布动态（create-post）

### 3.4 全屏模板

```
┌─────────────────────────┐
│                         │
│   自定义全屏布局          │
│   （渐变背景/动画）       │
│                         │
│   [居中的 CTA 按钮]      │
│                         │
└─────────────────────────┘
```

- 无 AppBar，完全自定义
- 常用于引导页、启动页

**适用页面**：启动页（splash）

### 3.5 聊天页模板

```
┌─────────────────────────┐
│  AppBar (返回 + 对方名称) │
├─────────────────────────┤
│  消息气泡列表（反转）     │
│  [对方消息 ← ]           │
│  [ → 我的消息]           │
├─────────────────────────┤
│  输入栏 + 发送按钮        │
└─────────────────────────┘
```

**适用页面**：AI 聊天（ai-chat）、私信聊天（direct-chat）

---

## 4. 动效规范

### 4.1 时长分级

| 分级 | CSS 变量 | 值 | 适用场景 |
|------|---------|---|---------|
| 快动效 | `--duration-fast` | `150ms` | 按钮按压反馈、状态切换 |
| 普通 | `--duration-normal` | `300ms` | 页面转场、列表入场、弹窗 |
| 慢动效 | `--duration-slow` | `600ms` | 大面积过渡、背景变化 |
| 呼吸 | `--duration-breath` | `1200ms` | 循环呼吸动画（loading） |

### 4.2 缓动曲线

| 名称 | CSS 变量 | 定义 | 适用场景 |
|------|---------|------|---------|
| elastic | `--ease-elastic` | `cubic-bezier(0.68, -0.55, 0.265, 1.55)` | 弹性回弹（按钮、Tab 指示器） |
| out-back | `--ease-out-back` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | 弹出效果（弹窗、菜单） |
| smooth | `--ease-smooth` | `cubic-bezier(0.4, 0, 0.2, 1)` | 平滑过渡（通用） |

### 4.3 入场动效 — FadeInUp

列表项和内容卡片的标准入场动效：

| 属性 | 值 | 说明 |
|------|---|------|
| 偏移 | `30px`（`MoeTokens.motionFadeOffset`） | 从下方 30px 开始 |
| 时长 | `300ms`（`MoeTokens.motionFadeDuration`） | 对应 `--duration-normal` |
| 交错 | `60ms`（`MoeTokens.motionStaggerStep`） | 列表项逐个延迟 |
| 曲线 | `--ease-smooth` | 平滑缓动 |

```css
/* CSS 动画 */
.fade-in-up {
  animation: fadeInUp var(--duration-normal) var(--ease-smooth) both;
}
```

```dart
// Flutter 实现参考
static const Duration motionFadeDuration = Duration(milliseconds: 300);
static const Duration motionStaggerStep = Duration(milliseconds: 60);
static const double motionFadeOffset = 30;
```

### 4.4 循环动效

| 名称 | 用途 | 关键帧 |
|------|------|-------|
| breathe | 加载占位/心跳 | `scale(0.85)→scale(1.0)`，`1200ms` |
| pulse-glow | 发光提示 | `box-shadow 8px→20px`，`1200ms` |

---

## 5. 暗色模式规范

### 5.1 暗色 Token 覆盖

| 属性 | 亮色值 | 暗色值 | CSS 变量 |
|------|-------|-------|---------|
| 页面背景 | `#F5F7FA` | `#121212` | `--color-page-bg` |
| 卡片背景 | `#FFFFFF` | `#1E1E1E` | `--color-card-bg` |
| 输入框背景 | `#FFFFFF` | `#2C2C2C` | `--color-input-bg` |
| 输入框填充 | `#F9F9F9` | `#252525` | `--color-input-fill` |
| 搜索栏背景 | `#F5F5F5` | `#2C2C2C` | `--color-search-bg` |
| 下沉区域 | `#EEEEF2` | `#1A1A1A` | `--color-bg-sunken` |
| 标题文字 | `#333333` | `#E0E0E0` | `--color-title` |
| 正文文字 | `#212121` | `#EEEEEE` | `--color-body` |
| 次要文字 | `rgba(0,0,0,0.6)` | `rgba(255,255,255,0.7)` | `--color-body-secondary` |
| 提示文字 | `#9E9E9E` | `#757575` | `--color-hint` |
| 占位符 | `#BDBDBD` | `#616161` | `--color-placeholder` |
| 卡片阴影 | `rgba(127,127,213,0.08)` | `rgba(0,0,0,0.24)` | `--shadow-card` |
| 导航阴影 | `rgba(0,0,0,0.05)` | `rgba(0,0,0,0.2)` | `--shadow-nav` |

### 5.2 Flutter 暗色主题

```dart
// MoeTheme.dark() 关键色值
pageBackground: Color(0xFF121212)
cardBackground: Color(0xFF1E1E1E)
```

### 5.3 暗色模式原则

1. **品牌色不变**：`--color-primary`、`--color-secondary`、`--color-accent` 在暗色模式下保持不变
2. **渐变不变**：所有渐变定义在暗色模式下保持一致
3. **阴影加深**：暗色模式阴影改用纯黑 `rgba(0,0,0,...)` 而非品牌色
4. **对比度**：文字与背景对比度需满足 WCAG AA 标准（4.5:1）
5. **CSS 选择器**：使用 `html.dark` 切换暗色模式（非 `prefers-color-scheme` 媒体查询）
6. **Flutter**：通过 `MoeTheme.dark()` 工厂方法切换，支持 `ThemeExtension` 的 `lerp` 过渡

---

## 6. 页面清单

合并后 v2 设计稿（`moe-social-ui-design/`）包含以下 19 个页面：

| 页面 | 文件 | 来源 | 说明 |
|------|------|------|------|
| 启动页 | `splash.html` | v1 | 品牌展示 + 进入按钮 |
| 登录页 | `login.html` | v2 | 手机号/密码登录 |
| 注册页 | `register.html` | v1 | 新用户注册 |
| 首页 | `home.html` | v2 | 动态 Feed 流 |
| 消息中心 | `messages.html` | v2 | 通知 + 私信列表 |
| AI 酒馆 | `ai-tavern.html` | v2 | AI 角色列表 |
| 个人主页 | `profile.html` | v2 | 用户主页 |
| 个人中心（紧凑版） | `profile-compact.html` | v1 | 紧凑布局变体 |
| 个人中心 V2 | `profile-v2.html` | v1 | 增强版变体 |
| 发布动态 | `create-post.html` | v2 | 发帖表单 |
| AI 聊天 | `ai-chat.html` | v2 | AI 对话界面 |
| 探索页 | `discover.html` | v2 | 发现内容 |
| VIP 会员中心 | `vip-center.html` | v2 | 会员订阅 |
| 心情扭蛋机 | `gacha.html` | v2 | 扭蛋抽奖 |
| 兴趣社区 | `community.html` | v2 | 社区板块 |
| 设置页 | `settings.html` | v2 | 应用设置 |
| 编辑资料 | `edit-profile.html` | v2 | 编辑个人信息 |
| 评论区 | `comments.html` | v2 | 帖子评论 |
| 私信聊天 | `direct-chat.html` | v2 | 一对一聊天 |
