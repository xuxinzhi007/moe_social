# UI 裸组件保留项清单（ui-retained-raw-components）

> 配套 `docs/DESIGN_SYSTEM.md` 第 4 章「统一组件强制规范」与护栏脚本 `scripts/check_ui_hardcode.sh`。
>
> 本清单登记**有意保留**的裸 Material 组件（TextField / SnackBar / CircularProgressIndicator）。
> 每一项均因统一组件当前能力无法等价覆盖而保留，**不是遗漏**。
> 新增代码一律禁止使用裸组件（护栏脚本会拦截）；本清单内的存量项按「解除条件」逐步迁移。
>
> 豁免标记约定：确需保留的行尾加 `// ui-hardcode: ignore`，整文件豁免用 `// ui-hardcode: ignore-file`。

---

## 1. 定式进度环（待 MoeLoading 支持 value 参数）— 3 处

`MoeLoading` / `MoeSmallLoading` 目前仅支持不定式（indeterminate）动画，
以下 3 处为**确定性进度**（`value:` 实参），迁移会导致功能退化，故保留裸 `CircularProgressIndicator`：

| 文件:行号 | 场景 | 理由 | 解除条件 |
| --- | --- | --- | --- |
| `lib/pages/gallery/cloud_image_viewer_page.dart:188` | 云端大图加载 | 需真实下载进度 `value: progress` | MoeLoading 增加确定性进度变体（如 `MoeProgress(value:)`） |
| `lib/widgets/post_image_viewer.dart:140` | 帖子图片加载 | 同上 | 同上 |
| `lib/pages/profile/profile_page.dart:1130` | 成就进度环 | `value: unlockedBadges/totalBadges` + 环心百分比文字 | 同上 |

## 2. Action 型撤销 SnackBar — 1 处

`MoeToast` 为纯通知（无 action 按钮、无倒计时），以下场景属合理保留：

| 文件:行号 | 场景 | 理由 | 解除条件 |
| --- | --- | --- | --- |
| `lib/pages/chat/conversations_page.dart:843` | 「隐藏会话」撤销 | 带「撤销」action + `_CountdownSnackLabel` 倒计时，依赖 ScaffoldMessenger 生命周期 | MoeToast 支持 action 回调 + 倒计时 label |

## 3. 保留裸输入框 — 18 处

### 3.1 聊天/评论 Composer（复杂输入交互）— 5 处

多行自增高 + `TextInputAction.send` + 工具栏（语音/表情/发送按钮）联动，
交互密度超出 `MoeInputField` 当前形态：

| 文件:行号 | 场景 | 理由 | 解除条件 |
| --- | --- | --- | --- |
| `lib/pages/chat/direct_chat_page.dart:1309` | 私信输入框 | maxLines 1–5 自增高 + 发送联动 | 抽出统一 MoeComposer 组件 |
| `lib/pages/companion/companion_chat_page.dart:1031` | AI 陪伴输入框 | 同上 + 语音监听态 hint 切换 | 同上 |
| `lib/pages/ai/chat_page.dart:1644` | AI 聊天 AppBar 内搜索框 | 嵌入 AppBar title、无边框、autofocus | AppBar 内嵌搜索变体 |
| `lib/widgets/ai/ai_chat_composer.dart:153` | AI 通用 Composer | KeyEvent 回车发送拦截 + AiTheme 样式 | 统一 MoeComposer 组件 |
| `lib/pages/feed/comments_page.dart:539` | 评论输入框 | 胶囊容器内无边框 + maxLines 3 + 回复态 hint | 统一 MoeComposer 组件 |

### 3.2 搜索栏（透明无边框、嵌入页面头部容器）— 4 处

视觉为「容器在外、输入框无边框」，与 `MoeInputField` 自带渐变背景形态不同：

| 文件:行号 | 场景 | 理由 | 解除条件 |
| --- | --- | --- | --- |
| `lib/pages/settings/settings_page.dart:110` | 设置页搜索 | 外层容器 + InputBorder.none | 抽出统一 MoeSearchBar 组件（或 MoeInputField 支持无边框变体） |
| `lib/widgets/settings/settings_search_bar.dart:39` | 设置搜索栏组件 | 同上 | 同上 |
| `lib/widgets/moe_search_bar.dart:61` | 通用搜索栏组件 | 同上 | 同上 |
| `lib/pages/profile/friends_page.dart:863` | 联系人面板搜索 | 同上 | 同上 |

### 3.3 深度定制表单/对话框 — 9 处

| 文件:行号 | 场景 | 理由 | 解除条件 |
| --- | --- | --- | --- |
| `lib/widgets/signature_input.dart:72` | 个性签名输入 | maxLength 计数 + 多行 + 主题化禁用态，定制 UI 整体 | MoeInputField 支持 maxLength 计数视图 |
| `lib/pages/profile/widgets/add_friend_bottom_sheet.dart:177` | 加好友申请框 | labelText + filled grey 底、Sheet 内定制视觉 | MoeInputField 支持 labelText 上浮形态 |
| `lib/pages/autoglm/autoglm_config_page.dart:322` | API 密钥输入 | TextFormField + obscure + validator 表单字段 | 逐项评估迁移（MoeInputField 已支持 validator） |
| `lib/pages/autoglm/autoglm_config_page.dart:834` | 对话框内嵌输入 | AlertDialog 内定制样式 | 同上 |
| `lib/pages/autoglm/autoglm_page.dart:997` | 指令输入胶囊 | 胶囊容器 + suffix 清空按钮联动 | 统一 MoeSearchBar / Composer 后迁移 |
| `lib/pages/autoglm/autoglm_task_page.dart:623` | 命令输入框 | OutlineInputBorder 胶囊 + 无障碍服务状态 hint | 同上 |
| `lib/pages/ai/content_generation_page.dart:466` | 生成需求输入 | maxLines 4 + AiBrand 容器样式 | 统一 MoeComposer 后迁移 |
| `lib/pages/ai/companion_hub_page.dart:1826` | 档案字段输入（labelText+maxLength） | labelText 上浮 + 字符上限 | MoeInputField 支持 labelText 上浮形态 |
| `lib/widgets/ai/ai_model_binding_sheet.dart:244` | 模型 ID 绑定 | AiTheme.mono 等宽样式 + AiTheme.inputDecoration | Ai 子系统主题收敛批次统一处理 |

---

## 维护约定

- 迁移任一保留项后，从本清单删除对应行，并确认护栏脚本无新增违规。
- 新增保留项必须同时满足：① 统一组件能力确实无法覆盖；② 在本清单登记理由与解除条件；③ 代码行加 `// ui-hardcode: ignore` 豁免注释。
- 行号随代码演进可能漂移，定位以「场景描述 + 就近搜索」为准。
