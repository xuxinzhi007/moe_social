# 脚本 JSON 格式（v1）

```json
{
  "id": "demo_tap_swipe",
  "name": "示例：滑动与点击",
  "version": 1,
  "loop": 1,
  "steps": [
    { "action": "wait", "ms": 800 },
    { "action": "home" },
    { "action": "swipe", "x1": 0.5, "y1": 0.75, "x2": 0.5, "y2": 0.25, "duration_ms": 350 },
    { "action": "tap", "x": 0.5, "y": 0.5 },
    { "action": "click_text", "text": "设置", "timeout_ms": 5000 },
    { "action": "input", "text": "hello" },
    { "action": "launch", "package": "com.android.settings" },
    { "action": "back" }
  ]
}
```

## 坐标

`tap` / `swipe` 的 `x`,`y`,`x1`,`y1`,`x2`,`y2` 为 **0~1 屏幕比例**（左上 0,0，右下 1,1）。

## action 一览

| action | 字段 | 说明 |
|--------|------|------|
| `wait` | `ms` | 延时 |
| `tap` | `x`, `y` | 坐标点击 |
| `swipe` | `x1`,`y1`,`x2`,`y2`, `duration_ms?` | 滑动 |
| `click_text` | `text`, `timeout_ms?` | 按节点树可见文字点击 |
| `wait_for_text` | `text`, `timeout_ms?` | 等待节点文字出现 |
| `ocr_click` | `text`, `timeout_ms?` | 截图 OCR 识屏后点击 |
| `ocr_wait` | `text`, `timeout_ms?` | OCR 等待文字出现 |
| `click_image` | `image`, `threshold?`, `timeout_ms?` | 模板图匹配点击（图放 user_scripts/templates/） |
| `input` | `text` | 向当前焦点输入框写入 |
| `launch` | `package` | 启动应用 |
| `back` / `home` / `recents` | — | 系统导航 |
| `log` | `message` | 写运行日志 |

失败默认 **中止脚本**（后续可加 `on_error: continue`）。
