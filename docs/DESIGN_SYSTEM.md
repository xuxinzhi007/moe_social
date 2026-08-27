# Moe Social 设计系统

> **"现代渐变 + 萌系可爱"融合风格** — 所有视觉参数统一引用 `lib/theme/moe_tokens.dart`（SSOT）。

---

## 1. 设计理念

| 关键词 | 含义 |
|--------|------|
| **现代渐变** | 多层渐变背景 + 浮动光斑，营造现代感 |
| **萌系亲和** | 大圆角、柔和阴影、毛玻璃卡片，传递可爱亲和力 |
| **精致交互** | 渐变按钮 + 微光晕 + 弹性按压动画，每个操作都有愉悦反馈 |
| **品牌一致** | 心形/星形图标 + 紫色调贯穿全局，强化品牌识别 |

### 核心原则

- **不破坏现有功能**：所有改动只涉及视觉层，业务逻辑零修改
- **向后兼容**：MoeTokens 只新增不删除，旧别名保留
- **性能友好**：毛玻璃使用 `ImageFilter.blur`，移动端有硬件加速

---

## 2. Design Tokens（`MoeTokens`）

### 2.1 色彩系统

#### 基础色板
| Token | 色值 | 用途 |
|-------|------|------|
| `primary` | `#7F7FD5` | 品牌主色（紫） |
| `secondary` | `#86A8E7` | 辅助色（蓝） |
| `accent` | `#91EAE4` | 点缀色（青） |
| `pastelOrange` | `#FFB347` | 暖色点缀 |

#### 表面色层级（从底到顶逐渐变亮）
| Token | 色值 | 用途 |
|-------|------|------|
| `surface0` | `#F5F7FA` | 页面背景 |
| `surface1` | `#FFFFFF` | 卡片 |
| `surface2` | `#FFFFFF` | 浮层 / Sheet（配合 blur） |
| `surface3` | `#FFFFFF` | 最高层 Tooltip / Dialog |
| `surfaceBorder` | `#7F7FD5 @ 8%` | 半透明描边色 |

#### 语义色
| Token | 色值 | 用途 |
|-------|------|------|
| `success` | `#2E7D32` | 成功 |
| `danger` | `#E53935` | 错误/危险 |
| `warning` | `#FF6F00` | 警告 |
| `goldLight` | `#FFE082` | VIP 主金色（徽章描边/会员强调） |
| `goldBg` | `#FFF8E1` | VIP 金色浅底（徽章文字/浅金底色） |

### 2.2 渐变系统

| Token | 色值 | 用途 |
|-------|------|------|
| `gradientPrimary` | `#7F7FD5 → #9B8FE8` | **主 CTA 按钮**（紫→薰衣草） |
| `gradientSoft` | `#E0C3FC → #8EC5FC` | 次级 CTA / 装饰背景 |
| `gradientKawaii` | `#FF9A9E → #FAD0C4 → #A18CD1` | 品牌特色萌系渐变 |
| `gradientPageBg` | `#FFFCFF → #F0F2FF → #F5F7FA` | 页面背景微渐变 |
| `gradientText` | `#7F7FD5 → #9B8FE8 → #86A8E7` | 文字渐变（ShaderMask） |

#### 渐变文字实现
```dart
ShaderMask(
  shaderCallback: (bounds) => MoeTokens.gradientText.createShader(bounds),
  child: const Text(
    '标题文字',
    style: TextStyle(color: Colors.white), // ShaderMask 会覆盖此颜色
  ),
)
```

### 2.3 阴影系统

所有阴影统一使用**紫色调** `rgba(127,127,213, α)`，保持品牌一致性。

#### 双层阴影（推荐用于卡片/浮层）
| Token | 内层（硬） | 外层（柔） | 用途 |
|-------|-----------|-----------|------|
| `shadowCard()` | `α=0.07, blur=4, y=2` | `α=0.04, blur=24, y=12` | 卡片 |
| `shadowElevated()` | `α=0.09, blur=8, y=4` | `α=0.05, blur=40, y=20` | 弹窗/Sheet |

#### 光晕阴影（按钮外发光）
```dart
MoeTokens.shadowGlow(MoeTokens.primary)
// → [α=0.31, blur=20, spread=-2] + [α=0.16, blur=40, spread=4]
```

#### 使用规则
- **每张卡片/浮层使用双层阴影**，而非单层 — 内层硬阴影提供清晰度，外层柔阴影提供浮起感
- **按钮使用光晕阴影** — 渐变按钮外发光增强"可点击"暗示
- 旧 `shadowSm/shadowMd/shadowLg` 保留但新代码优先使用双层阴影

### 2.4 毛玻璃参数

| Token | 值 | 用途 |
|-------|------|------|
| `blurHeavy` | `24.0` | 弹窗 / Sheet |
| `blurMedium` | `16.0` | 卡片 |
| `blurLight` | `8.0` | 导航栏 |

#### 毛玻璃卡片标准写法
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
  child: BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: MoeTokens.blurMedium,
      sigmaY: MoeTokens.blurMedium,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        border: Border.all(color: MoeTokens.surfaceBorder, width: 1),
        boxShadow: MoeTokens.shadowCard(),
      ),
      child: /* 内容 */,
    ),
  ),
)
```

### 2.5 圆角系统

| Token | 值 | 用途 |
|-------|------|------|
| `radiusSm` | `8px` | 小圆角 — 标签/Badge |
| `radiusMd` | `12px` | 中圆角 |
| `radiusLg` | `16px` | 大圆角 — 小组件 |
| `radius2xl` | `24px` | 极大圆角 — 卡片/毛玻璃 |
| `radiusButton` | `25px` | 按钮专用 |
| `radiusInput` | `15px` | 输入框专用 |
| `radiusFull` | `9999px` | 胶囊/圆形 |

### 2.6 动效参数

| Token | 值 | 用途 |
|-------|------|------|
| `motionFast` | `160ms` | 快速反馈（按钮按压、Toast 消失） |
| `motionMedium` | `260ms` | 标准过渡（入场、切换） |
| `motionSlow` | `420ms` | 慢速过渡（页面切换） |
| `motionPressScale` | `0.97` | 轻微按压缩放 |
| `motionPressScaleStrong` | `0.94` | 强按压缩放 |
| `motionFadeOffset` | `30px` | 入场动画偏移量 |

---

## 3. 组件视觉规范

### 3.1 按钮（CustomButton）

```
┌──────────────────────────────────┐
│  gradientPrimary 渐变背景         │
│  shadowGlow 光晕阴影              │
│  MoePressable 弹性按压 (0.97)    │
│  圆角 radiusButton (25px)        │
└──────────────────────────────────┘
```

- **默认模式**：`gradientPrimary` + `shadowGlow` + 白色文字
- **轮廓模式**（`isOutline: true`）：品牌色 6% 透明背景 + 30% 透明描边
- **加载状态**：隐藏光晕，显示 `CircularProgressIndicator`

### 3.2 输入框（MoeInputField）

- 背景：`Colors.white.withValues(alpha: 0.6)` 微透
- 边框：`surfaceBorder` 半透明
- **聚焦效果**：外发光 `shadowGlow` + 图标圆圈切换到 `gradientPrimary`
- 图标：包裹在渐变圆形容器中

### 3.3 空态（MoeEmptyState）

- 卡片：`shadowCard()` 双层阴影 + `surfaceBorder` 边框
- 插图背景：`gradientSoft` 渐变圆形
- 圆角：`radiusCardLarge` (24px)

### 3.4 加载（MoeLoading）

- 使用 `gradientPrimary` 渐变圆形容器
- 心形图标 + 呼吸脉冲动画（scale 1.0→1.06）
- 光晕透明度 0.5→1.0 循环

### 3.5 底部导航栏（MoeBottomBar）

- 外层：`shadowCard()` 双层阴影
- 内层 bar：`surfaceBorder` 边框
- 选中指示器：`gradientPrimary` 渐变

### 3.6 搜索栏（MoeSearchBar）

- 背景：半透明白色 + `surfaceBorder` 边框
- 搜索图标：`gradientSoft` 渐变圆形容器
- 阴影：`shadowSm`

### 3.7 Toast（MoeToast）

- 背景：半透明 + `surfaceBorder` 边框
- 阴影：`shadowElevated()` 双层
- 图标：包裹在半透明圆形容器中

### 3.8 对话框（ConfirmDialog）

- 使用 `Dialog` + 自定义 `Container`（非 AlertDialog）
- 毛玻璃风格：`surfaceBorder` 边框 + `shadowElevated()`
- 确认按钮：`CustomButton`（渐变）
- 取消按钮：`CustomButton(isOutline: true)`

---

## 4. 统一组件强制规范（防新增护栏）

> **硬性要求**：以下映射为强制项，新代码与改动代码一律使用统一组件；
> 由 `scripts/check_ui_hardcode.sh` 在提交前 / CI 拦截新增违规（只查 diff 新增行，存量不追溯）。

### 4.1 场景 → 必须使用的组件

| 场景 | 必须使用 | 禁止新增 |
|------|---------|---------|
| 按钮 | `CustomButton`（配 `MoeButtonSize` 档位） | 裸 `ElevatedButton` / `TextButton` / 手拼 InkWell 按钮 |
| 输入框 | `MoeInputField` | 裸 `TextField` / `TextFormField` |
| 轻提示反馈 | `MoeToast` | 裸 `SnackBar` / `ScaffoldMessenger.showSnackBar` |
| 加载中 | `MoeLoading` / `CustomButton(isLoading: true)` | 裸 `CircularProgressIndicator` |
| 未读角标 | `MoeBadgeDot`（全局权威实现） | 手拼小圆点 / 自绘角标 |
| 列表吸顶头 | `MoePinnedHeaderDelegate`（全局权威实现） | 自写 `SliverPersistentHeaderDelegate` |
| 菜单/设置条目 | `MoeMenuCard` | 手拼 ListTile 卡片 |
| 颜色 / 圆角 / 间距 | `MoeTokens.*` | 硬编码 `Colors.*` / `Color(0x…)` / `BorderRadius.circular(字面量)` |

### 4.2 按钮尺寸档位（`MoeButtonSize`）

| 档位 | 高度 | 水平内边距 | 适用场景 |
|------|------|-----------|---------|
| `small` | 40px | 16px | 紧凑列表、弹窗次级操作 |
| `medium`（默认） | 48px | 20px | 多数页面 CTA |
| `large` | 56px | 24px | 登录/注册等主 CTA |

```dart
CustomButton(text: '保存', size: MoeButtonSize.small, onPressed: onSave)
```

确需非标尺寸时才显式传 `height` / `padding`，并优先复用 `MoeTokens.btnHeight*` / `btnPad*`。

### 4.3 图标分层

| 层级 | 方案 | 适用 |
|------|------|------|
| 系统级 | Material Icons（`Icons.*`） | 通用操作（返回、关闭、更多）等非品牌图标 |
| 品牌门面 | `MoeIcon`（SVG，资产 `assets/icons/ui/`） | 心形/星形等品牌识别图标；缺失时自动降级 Material 近义图标 |
| 动效图标 | Lottie（`assets/lottie/`） | 礼物、聊天等需要动画表达的场景 |

### 4.4 禁止项清单

- 禁止新增硬编码色值（`Colors.*` / `Color(0x…)`）—— 一律 `MoeTokens`；缺 token 先补录再用
- 禁止新增字面量圆角（`BorderRadius.circular(18)` 式）—— 一律 `MoeTokens.radius*` 档位
- 禁止新增裸 `TextField` / `TextFormField` / `SnackBar` / `CircularProgressIndicator`
- 禁止绕过 `MoeBadgeDot` / `MoePinnedHeaderDelegate` 重复实现全局角标与吸顶逻辑

### 4.5 护栏脚本用法（`scripts/check_ui_hardcode.sh`）

```bash
scripts/check_ui_hardcode.sh            # 默认 base=HEAD，提交前自检工作区新增行
scripts/check_ui_hardcode.sh origin/main  # CI：检测整个 PR 的新增行
```

- 退出码：`0` 无新增违规 / `1` 存在违规（输出 `文件:行号:[类型] 内容` 清单）/ `2` 环境错误
- 豁免：行尾 `// ui-hardcode: ignore`；文件前 10 行 `// ui-hardcode: ignore-file`；
  环境变量 `EXCLUDES`（冒号分隔，默认豁免 `lib/theme/moe_tokens.dart` — 色值 SSOT）

---

## 5. 页面模板

### 5.1 认证页通用结构

```
AuthBackground（4色渐变 + 浮动光斑）
  └─ Stack
      ├─ Positioned(返回按钮)
      └─ Center
          └─ SingleChildScrollView
              └─ Column
                  ├─ Logo 区域（呼吸动画 + 渐变文字）
                  ├─ 毛玻璃表单卡片（BackdropFilter）
                  │   └─ Form
                  │       ├─ MoeInputField × N
                  │       ├─ 渐变主按钮（gradientPrimary + shadowGlow）
                  │       └─ 第三方登录（品牌色半透明卡片）
                  └─ 底部引导（渐变分隔线 + 渐变文字）
```

### 5.2 认证页背景（AuthBackground）

- **4 色渐变**：紫 / 蓝 / 青 / 粉（粉色增加萌感）
- **4 个浮动光斑**：Lissajous 曲线运动轨迹
- **顶部光晕条**：模拟光源照射效果

### 5.3 登录页特有元素

- `_BreathingLogo`：渐变容器 + 心形图标 + 呼吸脉冲动画
  - padding: 16, icon: 40, borderRadius: 22
  - scale: 1.0 → 1.06, glow opacity: 0.5 → 1.0
- 品牌名 "Moe Social"：`gradientText` ShaderMask，fontSize 26
- 副标题：`gradientSoft` ShaderMask

### 5.4 页面高度控制

登录页经过高度优化，确保 iPhone 14 一屏可见：
- Logo 区域紧凑化（~130px）
- 区域间距压缩（28px / 20px）
- 表单卡片内边距（horizontal: 20, vertical: 20）
- 按钮高度精简（登录 48px / 第三方 44px）

---

## 6. 新页面/组件开发指南

### 检查清单

创建新页面或组件时，按以下清单检查：

- [ ] 颜色是否引用 `MoeTokens`？（禁止硬编码色值）
- [ ] 按钮/输入/反馈/加载是否使用统一组件（见第 4 章强制规范）？
- [ ] 提交前是否通过 `scripts/check_ui_hardcode.sh` 检查？
- [ ] 卡片是否使用 `shadowCard()` 双层阴影？
- [ ] 浮层是否使用 `shadowElevated()` 双层阴影？
- [ ] 按钮是否使用 `gradientPrimary` + `shadowGlow`？
- [ ] 圆角是否使用 `MoeTokens.radius*` 系列？
- [ ] 间距是否使用 `MoeTokens.space*` 系列？
- [ ] 字号是否使用 `MoeTokens.text*` 系列？
- [ ] 动画时长是否使用 `MoeTokens.motion*` 系列？
- [ ] 按压反馈是否使用 `MoePressable`？
- [ ] 入场动画是否使用 `MoeReveal`？
- [ ] 毛玻璃卡片是否遵循标准写法（ClipRRect + BackdropFilter）？

### 代码示例：渐变按钮

```dart
SizedBox(
  width: double.infinity,
  height: 48,
  child: MoePressable(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
    child: Container(
      decoration: BoxDecoration(
        gradient: MoeTokens.gradientPrimary,
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
        boxShadow: MoeTokens.shadowGlow(MoeTokens.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
          child: const Center(
            child: Text(
              '按钮文字',
              style: TextStyle(
                fontSize: MoeTokens.textLg,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
)
```

### 代码示例：渐变文字

```dart
ShaderMask(
  shaderCallback: (bounds) => MoeTokens.gradientText.createShader(bounds),
  child: const Text(
    '渐变标题',
    style: TextStyle(
      fontSize: MoeTokens.text2xl,
      fontWeight: FontWeight.w900,
      color: Colors.white, // 被 ShaderMask 覆盖
      letterSpacing: 1,
    ),
  ),
)
```

### 代码示例：渐变淡出分隔线

```dart
Container(
  height: 1,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.transparent,
        MoeTokens.hintText.withValues(alpha: 0.25),
        Colors.transparent,
      ],
    ),
  ),
)
```

---

## 7. 文件索引

| 文件 | 职责 |
|------|------|
| `lib/theme/moe_tokens.dart` | 全局 Design Tokens SSOT |
| `lib/theme/moe_theme.dart` | ThemeExtension + light/dark + lerp |
| `lib/widgets/auth_background.dart` | 认证页渐变背景 + 浮动光斑 |
| `lib/widgets/custom_button.dart` | 统一按钮组件（+ `MoeButtonSize` 档位） |
| `lib/widgets/moe_input_field.dart` | 统一输入框 |
| `lib/widgets/moe_icon.dart` | 品牌 SVG 图标（带 Material 降级） |
| `lib/widgets/moe_badge_dot.dart` | 全局未读角标（权威实现） |
| `lib/widgets/moe_pinned_header_delegate.dart` | 全局吸顶 Delegate（权威实现） |
| `lib/widgets/moe_menu_card.dart` | 菜单/设置条目卡片 |
| `lib/widgets/moe_empty_state.dart` | 空态组件 |
| `lib/widgets/moe_loading.dart` | 加载动画 |
| `lib/widgets/moe_bottom_bar.dart` | 底部导航栏 |
| `lib/widgets/moe_search_bar.dart` | 搜索栏 |
| `lib/widgets/moe_toast.dart` | Toast 通知 |
| `lib/widgets/dialogs/confirm_dialog.dart` | 确认对话框 |
| `lib/widgets/motion/moe_pressable.dart` | 弹性按压反馈 |
| `lib/widgets/motion/moe_reveal.dart` | 入场动画 |
| `lib/pages/auth/login_page.dart` | 登录页（标杆示范） |
| `lib/pages/auth/register_page.dart` | 注册页 |
