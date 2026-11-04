# 回复参谋贴纸桌宠悬浮层 — 补丁式技术评估（2026-11-05）

> 本文是路径 B 评估的**补丁**，不重写 [reply-assist-tech-eval-2026-11-05.md](./reply-assist-tech-eval-2026-11-05.md)。  
> UX 拍板：[../product/reply-assist-pet-overlay-ux-2026-11-05.md](../product/reply-assist-pet-overlay-ux-2026-11-05.md)。

## 1. 决策（本补丁）

**推荐：Native `WindowManager` 自定义 View（贴纸脸 + 气泡）**，挂在现有 `ReplyAssistAccessibilityService` 上。

**不**在本轮引入 Flutter 悬浮引擎（第二 `FlutterEngine` / `FlutterView` 塞进 overlay）。

Suggest **仍走 Flutter**（token、`ApiService`、既有 `POST /api/reply-assist/suggest`）。Native 负责读树、展示、剪贴板。Flutter 未起则降级，不崩溃、不代发。

## 2. 架构选型

| 方案 | 优点 | 代价 | MVP |
|------|------|------|-----|
| **A. Native WM 自定义 View** | 已有紫块 `addView`；盖在微信上不依赖 Activity 前台；FLAG 与拖动是 Android 常规；气泡/表情用 View+Canvas 足够 | 两套 UI（悬浮 native / App Flutter） | **采用** |
| B. Overlay 内嵌 Flutter 引擎 | 气泡可复用 MoeTokens | 引擎保活、首帧、无障碍进程与 Activity 生命周期耦合；为 44dp 脸 + 3 气泡过重 | 不做 |
| C. 只 Toast / 拉回 App 大卡 | 实现短 | 违反「当场闭环、无大卡」 | 否决 |

理由摘要：路径 B 骨架已经把 overlay 放在无障碍服务里。本轮是把紫 `View` 换成脸+气泡，而不是换窗口栈。AutoGLM 的 `WindowManager`/`TYPE_APPLICATION_OVERLAY` 可作参考，**只借窗口模式，不借 tap/type/手势，且 `AutoGLMService` 保持未接线**。

## 3. 触控

### 3.1 拖 vs 点

- 只在**脸**上监听 `MotionEvent`（气泡不拖，避免和「复制」抢手势）。
- `ViewConfiguration.get(context).scaledTouchSlop`：位移超过 slop → 拖；否则 `ACTION_UP` 当单击。
- 坐标系：`Gravity.TOP|START`，`params.x/y` 与 `rawX/rawY` 同向，避免旧紫球 `Gravity.END` 导致 x 轴反号。
- 拖时 `wm.updateViewLayout`；松手 clamp 到屏幕内（含刘海/导航条 inset）。

### 3.2 展开后复制命中

- 展开时窗口 `WRAP_CONTENT`，命中区=脸 ∪ 可见气泡，不铺全屏遮罩。
- 「复制」芯片与选项正文都可点；写入 `ClipboardManager`（`ClipData.newPlainText`）。
- 展开后调整 `params.y`，让**脸的屏幕锚点不变**（否则 `WRAP_CONTENT` 向上长高会把脸顶下去）。

### 3.3 FLAG 与展开策略

| Flag | 始终 | 原因 |
|------|------|------|
| `FLAG_NOT_FOCUSABLE` | 是 | 不抢微信 IME / 焦点；复制不需要输入焦点 |
| `FLAG_NOT_TOUCH_MODAL` | 是 | 窗外触摸交给微信，不挡聊天 |
| `FLAG_WATCH_OUTSIDE_TOUCH` | 是 | 展开时收 `ACTION_OUTSIDE` → 收回气泡（「点空白收回」） |
| `FLAG_LAYOUT_NO_LIMITS` | 是 | 允许贴边；仍 clamp |

**不**在展开时改成可 focus、也**不**上 `FLAG_NOT_TOUCH_MODAL` 的反面（全屏模态）。那会变成半屏挡操作。

听/想期间忽略二次单击，防止重入 suggest。

## 4. 当场闭环与进程边界

```text
点脸 (Native)
  → 表情 listening + 思考小气泡
  → ReplyAssistAccessibilityService.readWeChatSnapshot()
       微信白名单 / 空树 → needs_screenshot_fallback
  → 表情 thinking
  → MethodChannel com.moe_social/reply_assist
       Native invoke  "onOverlaySuggest"  + snapshot map
  → Flutter ReplyAssistOverlayBridge（进程内、Activity 可在后台）
       AuthService token + ReplyAssistService.suggest(source: a11y)
  → Result: { options: [{label,text}×3] } 或 { ok:false, fallback, message }
  → Native 轻动画 → ready 脸 + 3 气泡
  → 点复制 → Clipboard + success 脸
```

| 边界 | 处理 |
|------|------|
| Flutter 引擎在、handler 已 `ensureAttached` | 当场闭环，不打开 App 页 |
| 引擎在但未登录 / API 失败 | 气泡或 Toast 短文案；不崩 |
| `ReplyAssistBridge.channel == null` 或 `notImplemented` | Toast「请先打开 Moe，让回复参谋在线」；脸回待命 |
| 无障碍进程还在、Activity 已被划掉 | 同上降级（token 在 Dart，本轮不在 Native 重放 HTTP） |
| 非微信前台 | 气泡「现在不在微信聊天页」 |
| 空树 | 气泡「读不到字，去 App 贴图」；`needs_screenshot_fallback=true` |

App 页继续承担：权限、显示/隐藏桌宠、粘贴/截图长编辑。悬浮层不替代这些。

Channel 扩展：

- Flutter → Native（原有）：`isAccessibilityEnabled` / `isOverlayVisible` / `openAccessibilitySettings` / `toggleOverlay` / `readWeChatSnapshot`
- Native → Flutter（新增）：`onOverlaySuggest`
- 不把 suggest URL 或 token 拷到 Kotlin。

## 5. 表情资源

首版：**Kotlin `ReplyAssistPetFaceView` Canvas 绘制** + XML 气泡背景。

- 五态：`idle` / `listening` / `thinking` / `ready` / `success`
- 点点：独立小 View + `ValueAnimator`，不依赖帧 PNG 序列
- **禁止**本轮依赖 `moe-avatar/`、Pet LPC、Spine

可后续换成 drawable 帧，但 API 保持 `setExpression(enum)`。

## 6. 权限与 AutoGLM 资产边界

| 权限/资产 | 用法 |
|-----------|------|
| `SYSTEM_ALERT_WINDOW` | 已有；桌宠 overlay |
| 无障碍 `canRetrieveWindowContent=true` | 点按才读 |
| `canPerformGestures=false` | **保持**；只读 |
| `packageNames=com.tencent.mm` | **保持** 白名单 |
| `canTakeScreenshot` | 本轮仍 `false`；空树走 fallback 交互；OCR 识图补洞为后续 stub |
| `AutoGLMService` | **不注册、不启用**；禁止 performTap/type/手势/代发 |
| AutoGLM overlay 代码 | 只参考 WM addView 模式；不调用其任务引擎 |

## 7. 风险

| 风险 | 缓解 |
|------|------|
| 微信 a11y 树为空 | fallback 气泡 + App 贴图；不装 OCR 挡 MVP |
| 划掉 App 后 channel 空 | Toast 开 App；不在 Native 存 token |
| LLM 慢 | 想态最长约 25s，超时收回提示「再点一次」 |
| 展开后脸被顶走 | 按脸锚点回写 `params.y` |
| 贴左边时气泡出屏 | 按水平位置把气泡栈改 `gravity` 向内 |
| 误把 AutoGLM 接上 | Manifest 不注册；代码路径不引用其手势 API |

## 8. MVP 砍刀

做：

- 替换紫球为可拖贴纸脸
- 状态机 UI（听/想/选项/复制成功/收回）
- Channel 当场闭环 + Flutter 未起降级
- 剪贴板复制

明确不做：

- 代发 / 自动点输入框
- Flutter overlay 引擎
- 服务端 OCR / 视觉模型（交互态要有，识别可 stub）
- 说话人精确区分
- 磁吸动画精修、半屏判断卡
- moe-avatar 养成素材
- 启用 AutoGLM
