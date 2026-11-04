# 回复参谋技术评估（2026-11-05）

## 决策

**推荐路径 B**：读屏能力走侧载/内测 APK；主 App 商店包可通过 `FeatureFlags.replyAssistPrototype`（默认关）隐藏入口，降低 CI/审核风险。

## 现有资产

| 资产 | 位置 | 本特性用法 |
|------|------|------------|
| 孤儿 AutoGLM 无障碍 | `android/.../AutoGLMService.kt` | **不启用**（未在 Manifest 注册）；含 tap/type/自动化，禁止复用到回复参谋 |
| Companion LLM 网关 | `internal/service/companion` + `pkg/llminference` | 复用推理配置解析；**新 API** `replyassist.v1.Suggest` |
| 微信包可见性 | `AndroidManifest.xml` `<queries>` | 已有 `com.tencent.mm` |

## 目标架构

```text
点按悬浮球 → ReplyAssistAccessibilityService（只读树，微信白名单）
          → Flutter ReplyAssistPage
          → POST /api/reply-assist/suggest
          → llminference.Chat（JSON 判读 + 3 选项 + 反 PUA 过滤）
          → 结果面板（复制）
```

## Android 读屏服务（新建）

- 类：`com.example.moe_social.ReplyAssistAccessibilityService`
- 配置：`res/xml/reply_assist_accessibility_service_config.xml`
  - `canPerformGestures=false`
  - `packageNames=com.tencent.mm`
- MethodChannel：`com.moe_social/reply_assist`（状态、悬浮球、读屏快照）
- 空树：返回 `needs_screenshot_fallback`，引导粘贴/截图

微信新版本 a11y 树为空为已知风险（JevGuide 已公开）；MVP 为 **best-effort 文本收集**，不做说话人精确区分。

## 后端

- Proto：`backend/api/replyassist/v1/reply_assist.proto`
- Biz：`internal/biz/replyassist`（prompt、JSON 解析、90s 内存缓存 TTL、关键词安全闸）
- 与 Companion 会话 **隔离**：不写 `companion_chat_log`

## Flutter

- `lib/pages/reply_assist/reply_assist_page.dart`
- `lib/services/reply_assist_service.dart`
- 开关：`FeatureFlags.replyAssistPrototype`（默认 `showExperimentalFeatures == false`）

## 安全与合规

- 服务端禁止 PUA/操控类关键词输出（初版关键词闸 + prompt 约束）。
- 客户端文案强调：不代发、点按才读。
- Play 读屏政策严格 → 路径 B 不赌上架读屏插件。

## 本 PR 范围 vs 后续

| 能力 | 本 PR | 后续 |
|------|-------|------|
| 判读 + 3 选项 API | ✓ | 提示词迭代、Jev 可选对接 |
| 粘贴 / 图片上传 | ✓ | 截图 OCR/视觉模型 |
| 微信读树 | 骨架 + 文本节点扫描 | 说话人/顺序、空树 OCR 兜底 |
| 多 App 白名单 | 仅微信 | 设置页可配置 |
| 代发/自动化 | **无** | 永久不做 |
