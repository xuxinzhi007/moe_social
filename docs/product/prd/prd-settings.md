# PRD — 设置

- **生成时间**：2026-11-13 · **层级**：支撑面，不进主 Tab · **数据源**：代码事实
- **上级文档**：[moe-social-prd.md](./moe-social-prd.md) · **定位**：[../product-positioning.md](../product-positioning.md)
- **知识层**：`knowledge_root` / `cards_dir` 未配置。事实只来自下面点名的代码。

这是设置页的现状规格。读者用它核对「现在有什么、存在哪、什么还没拍板」。这次不改页面，也不新增指标目标。

## 1. Summary

设置是「我的」里的一个齿轮入口，不是第五个之外的新主路径。它把账号安全、通知、私信保留、AI 旁路、本机数据和关于，收成一页可搜索的清单。主路径仍然是发帖、看动态、聊天。

入口：`ProfilePage` 只在 AppBar 放齿轮，注释写明不再在页面里重复入口（`lib/pages/profile/profile_page.dart`）。路由 `/settings` → `SettingsPage`（`lib/app/app_routes.dart`）。

## 2. Background & Problem

- **问题**：账号、通知、陪伴和实验开关如果散在各个业务页，用户找不到，也会在主路径上多出入口。
- **现在的做法**：一页五段，加上顶部搜索。搜索命中后，路由项直接打开子页，其余项滚回对应段（`SettingsPage._navigateToSettingItem`）。
- **不解决**：不把星辉、Feed、私信聊天本身做进设置。那些只在这里留开关或跳转。

## 3. Personas

沿用总 PRD 的使用者。本页额外碰到两类人：要关通知或注销的普通用户，以及打开实验开关后的开发者。没有访谈，不新造画像。

## 4. Goals & Success Metrics

目标值 **待确认**。代码里没有设置页的成功指标。下面只列可以数的行为，不填数字。

| 可以数的行为 | 现在能不能数 | 状态 |
| --- | --- | --- |
| 从「我的」进入设置 | 未在本页看到埋点 | 待确认 |
| 搜索后零结果 | 有空状态文案，无计数 | 待确认 |
| 注销完成 | 有成功/失败 Toast | 待确认 |
| 通知开关被系统拒绝 | 有错误 Toast | 待确认 |

## 5. Value Proposition

用户在一个地方处理账号和本机偏好，不用在主 Tab 里找。实验能力默认收在折叠的高级选项里，不和改密码放在同一视觉重量上。

## 6. Solution & Feature Scope

信息架构以 `SettingsPage._buildNormalSettings` 为准，顺序固定：

1. 当前体验状态
2. 账号与隐私
3. AI 与助手
4. 设备与数据
5. 高级选项（默认折叠）
6. 关于与支持

### Story 6.1 — 体验状态 · 只读摘要

**功能描述**：页顶一张渐变卡片，拼两句本机状态：「通知开启/关闭」和「启动自动检查更新/不检查」。点击滚到「账号与隐私」。

**In Scope**：这两句。数据来自 `NotificationPreferences` 和 `StartupUpdatePreferences`，在 `initState` 之后读取。
**Out of Scope**：不在这张卡上改开关。

**验收**：
- Given 通知偏好为关，When 打开设置，Then 卡片含「通知关闭」。
- Given 点击卡片，When 列表可滚动，Then 滚到账号与隐私段。

**触点**：`SettingsPage._buildExperienceDashboard`。

### Story 6.2 — 账号与隐私

**功能描述**：修改密码、隐私与权限、登录记录、注销，外加系统公告、私信保留、推送通知。

| 项 | 行为 | 触点 |
| --- | --- | --- |
| 修改密码 | 对话框改密 | `AccountSecurityModule` |
| 隐私设置 | 打开 `PrivacySettingsPage`：通知、摄像头、麦克风、定位。回复参谋开关打开时还有无障碍、悬浮窗 | `privacy_settings_page.dart` |
| 登录记录 | 底部表，当前设备与最近登录 | `AccountSecurityModule` |
| 注销 | 两次确认。文案写明资料删除、微信/飞书绑定解除、不可恢复，完成后退出 | `AccountSecurityModule._confirmDeleteAccount` |
| 系统公告 | 路由 `/announcements` | `SettingsPage` |
| 私信记录保留 | 子页三选：自动、至少 7 天、至少 30 天。写入 `UserService.updateUserInfo`，对齐 `message_retention_choice` | `MessageRetentionSettingsPage` |
| 推送通知 | 本机开关。打开但系统未授权时 Toast「未获得通知权限」，开关不变成开 | `SettingsPage._onNotificationToggle` · `NotificationPreferences`（SharedPreferences） |

**验收**：
- Given 未登录，When 点注销，Then Toast「请先登录」，不进入确认框。
- Given 第一次确认取消，When 返回，Then 不调用注销。
- Given 通知系统权限被拒，When 打开开关，Then 仍为关，并出现错误 Toast。

### Story 6.3 — AI 与助手

| 项 | 去哪 | 开关 |
| --- | --- | --- |
| 社区 AI | `/virtual-avatar-settings`，标题「社区 AI」。副文案写明旧悬浮入口已下线 | 始终显示 |
| AI 伙伴 | `/companion-settings`：主动联系、免打扰起止、再到模型配置 | 始终显示 |
| 伙伴·回复参谋 | `/reply-assist` | 仅 `FeatureFlags.replyAssistPrototype` |

伙伴设置页把模型配置指回「设置 → 高级选项 → AI 模型配置」（`CompanionSettingsPage`）。

**验收**：
- Given `replyAssistPrototype` 为 false，When 打开设置，Then 列表和搜索都没有「伙伴·回复参谋」。
- Given 在伙伴设置点 AI 模型，When 跳转，Then 进入 `/llm-model-config`。

### Story 6.4 — 设备与数据

`DeviceStorageModule`：

| 项 | 行为 |
| --- | --- |
| 启动时检查更新 | 本机偏好。副文案写明仅 Android 侧载包有效 |
| 本机设备信息 | 设备 ID、系统版本、网络。页初始化时 `DeviceInfoProvider.init` |
| 清理缓存 | 非 Web 显示大约 MB，确认后清。Web Toast 让用户清浏览器站点数据 |
| 清理本地数据 | 日志和字符卡导出等可再生成文件。Web 提示无需清理 |

**验收**：
- Given Web，When 点清理缓存，Then 不删除本机目录，只提示用浏览器清理。
- Given 关掉启动检查，When 回到页顶，Then 体验状态含「启动不自动检查更新」。

### Story 6.5 — 高级选项

`SettingsAdvancedSection` 默认 `_expanded = false`。展开后：

| 项 | 可见条件 |
| --- | --- |
| AI 模型配置 | 始终（`AiSettingsModule` → `LlmModelConfigPage`） |
| 飞书通知 | 始终，打开 `feishu_bind_sheet` |
| AutoGLM 助手 | `FeatureFlags.showAutoGlm` |
| 礼物 PK 联调 | `FeatureFlags.liveGiftPk`，去 `/battle` |
| 异地联机实验 | `FeatureFlags.showGameNetworkLab` |

当前 `showExperimentalFeatures` 为 true，所以上面三项实验入口跟着出现（`lib/constants/feature_flags.dart`）。同一文件写明商店包发布前要把总开关改回 false。

**验收**：
- Given 刚进设置，When 未点高级选项，Then 模型配置和 AutoGLM 不可见。
- Given 总开关为 false，When 展开高级选项，Then 没有 AutoGLM、礼物 PK、异地联机。

### Story 6.6 — 关于与支持

`AboutModule`：软件版本（点击检查更新）、访问官网、意见反馈（类型 + 描述）、用户协议摘要对话框。

### Story 6.7 — 搜索

`SettingsSearchBar` 对标题、描述、模块名、关键词做包含匹配，标题以前缀命中的排前面。无结果文案：「未找到与「…」相关的设置」。搜索项是另一份清单（`_buildSearchEntries`），和主列表不是同一个 widget 树。

**已知不一致（已证实）**：搜索里「隐私设置」「账号安全」的动作是滚到「账号与隐私」，不是直接打开隐私页。主列表里「隐私设置」会 `push` 隐私页。

## 7. 数据落点

| 偏好 | 落点 | 证据 |
| --- | --- | --- |
| 推送通知 | 本机 SharedPreferences | `NotificationPreferences` |
| 启动检查更新 | 本机 | `StartupUpdatePreferences` |
| 私信保留 | 账号字段 `message_retention_choice` | `MessageRetentionSettingsPage` 注释与 `UserService.updateUserInfo` |
| 伙伴主动联系 / 免打扰 | 伙伴设置页写入，细节不在本 PRD 展开 | `CompanionSettingsPage` |
| 注销 | 服务端删除账号与绑定 | `AccountSecurityModule` 文案；接口实现本次未逐行打开，调用链标待确认 |

## 8. 不做

- 不把设置做成主 Tab。
- 不在本轮改信息架构、不合并搜索清单和主列表。
- 不给指标填建议数字。
- 伙伴聊天、模型推理、Feed 的规则不在这份里重写，只记录设置上的入口。

## 9. 待拍板

1. 设置继续保持这一份总 PRD，还是按「账号 / AI / 设备 / 关于」拆开。推荐：保持一份，避免和现有分域 PRD 抢边界。
2. 搜索「隐私设置」应直接打开隐私页，还是继续只滚动。推荐：和主列表一致，直接打开。
3. 商店包是否在发版清单里强制把 `showExperimentalFeatures` 设为 false。推荐：是，代码注释已经这样写。
4. 体验状态要不要加上伙伴免打扰或私信保留。推荐：先不加，那两项不在本机这两句的数据源里。

## 10. 开放问题

- 注销请求打到哪个用户接口、失败时服务端是否部分删除：本次只证实了前端两次确认和 Toast，接口符号待确认。
- 意见反馈提交到哪：`AboutModule` 有提交态，接收方本次未追到后端，待确认。
