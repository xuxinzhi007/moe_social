# Animation Sheet v1

## Purpose

将无规则的 PNG/视频帧整理为一张透明、等格、按动画行排列的通用 sprite sheet。该格式只描述资源布局，不绑定 Godot、LPC、Unity 或其他运行时。

## Sheet Rules

- 每个 cell 使用统一的 `width` / `height`。
- 每一行代表一个动画片段。
- 每一列代表该片段中的一个帧。
- 不足最大列数的行保持透明，不填充假帧。
- 所有帧在导出前完成缩放、偏移和锚点校准。
- 产物必须是透明 RGBA PNG。

## Manifest

```json
{
  "specVersion": "sprite-animation-v1",
  "kind": "animation_sheet",
  "sheet": "character_sheet.png",
  "cellSize": { "width": 128, "height": 128 },
  "columns": 8,
  "rows": 4,
  "animations": {
    "idle": { "label": "待机", "row": 0, "frames": 2, "fps": 6, "loop": true },
    "walk": { "label": "行走", "row": 1, "frames": 8, "fps": 10, "loop": true }
  }
}
```

## Editor Responsibilities

编辑器负责：

1. 导入视频或 PNG 帧。
2. 处理帧顺序、删除、复制和分组。
3. 设置每个动画行的 FPS 和循环属性。
4. 对每个帧执行缩放、偏移和锚点调整。
5. 导出透明网格 PNG 和通用 manifest。

编辑器不负责：

- 运行时状态机。
- 引擎专用场景文件。
- Godot、LPC 或 Unity 的播放 API。
- 替用户决定动画如何接入游戏。

## Consumer Examples

- Godot：使用网格区域创建 `SpriteFrames`。
- LPC 风格工具：按行和列读取动作帧。
- Unity：使用 Sprite Editor 切格后建立 Animation Clip。
- 纯图片用户：直接使用导出的 PNG。
