# 序列帧 Sheet Godot 回测

## 目的

验证工作台导出的 `spritesheet.png` 和 `spritesheet.json` 不依赖管理台内部状态，可以被 Godot 通过固定 cell 网格直接裁剪和播放。

## 最小场景

1. 创建 Godot 4 项目。
2. 添加 `Sprite2D` 或 `AnimatedSprite2D`。
3. 将导出的 `spritesheet.png` 设置为纹理。
4. 使用 JSON 中的 `frameLayout.frameWidth`、`frameLayout.frameHeight` 设置 Hframes/Vframes。
5. 按 JSON 中动画的 `row` 和 `outputFrameIndex` 设置播放范围。
6. 将 `anchor.x`、`anchor.y` 转换为 Sprite2D 的中心偏移，检查角色脚底或指定锚点是否稳定。

## 自动回测

在本目录放入工作台导出的 `spritesheet.png` 与 `spritesheet.json`，使用 Godot 4 headless 运行：

```powershell
& $env:GODOT_PATH --headless --path docs/dev/godot-sheet-smoke-test --quit-after 2
```

场景会优先读取真实 PNG；缺少 PNG 时才使用内置夹具。成功输出必须包含 `GODOT_SHEET_SMOKE_PASS`，并报告真实来源为 `real-export`。

## 验收项

- PNG 是 RGBA，空白 cell 完全透明。
- 所有 cell 尺寸相同，PNG 宽高等于 `frameWidth × columns`、`frameHeight × rows`。
- 播放顺序等于工作台帧条从左到右顺序。
- 禁用帧不会进入输出帧和播放序列。
- 多个动画行的 `row`、帧数和 FPS 与 JSON 一致。
- 切换帧时角色锚点不跳动。
- 从 PNG + JSON 重新导入工作台后，帧数、时长、来源映射和动画结构保持一致。

## 当前状态

导出前的浏览器契约校验已经检查尺寸、网格、帧数和空画布；Godot 实际场景回测仍需使用一组真实 AI 多动作素材完成，并作为 P0 的完成条件。
