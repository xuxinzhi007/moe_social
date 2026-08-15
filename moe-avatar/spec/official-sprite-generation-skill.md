# Official Sprite Generation Skill

## Purpose

为 Moe 自有 `soft_chibi` 角色包生成可组合、可预览、可导出的分层 sprite 资源。

## Source Of Truth

- 画风：Moe soft chibi，透明背景，柔和色块，低对比阴影。
- 格子：128 × 128 px。
- 方向：`up` → `left` → `down` → `right`。
- 动作：v1 使用 `idle` 2 列 × 4 行、`walk` 9 列 × 4 行。
- 原点：脚底中心约 `(64, 124)`。
- 资源格式：每个部件独立透明 sprite sheet；PNG 是生产格式，SVG 可用于原型和可替换源稿。

## Layer Contract

固定合成顺序：

```text
body → bottom → top → shoes → head → face → hat → hair
```

每个部件必须：

1. 使用相同的 cell 尺寸和方向行序。
2. 在 `down / idle / frame 0` 对齐脚底原点。
3. 不绘制其他部件的像素。
4. 保持透明背景，不使用黑色或纯色底。
5. 在 manifest 中声明 `walk` 和 `idle` 路径。

## Naming

```text
layers/base/body.svg
layers/base/head.svg
layers/base/face.svg
layers/base/hair.svg
layers/slots/top_basic.svg
layers/slots/bottom_basic.svg
layers/slots/shoes_basic.svg
```

商品槽位使用稳定 ID，例如 `top_hoodie`、`bottom_jeans`、`shoes_sneaker`。显示名写入 manifest 的 `label`，不把中文名称作为资源路径。

## Animation Rules

- `idle` 必须保持脚底稳定，只允许呼吸、眨眼、轻微衣物变化。
- `walk` 需要保持头部和躯干中心稳定，腿部和手臂产生周期变化。
- 不得用同一张静态图冒充真实攻击或行走动作；没有真实姿态时标记为草稿。
- 新动作必须先加入 manifest，再加入各部件 sheet，最后加入管理台预览。

## Export Rules

- 完整素材包：`manifest.json` + `layers/` + `thumbs/` + 可选 `baked/`。
- 当前角色包：只包含当前选择的部件和合成后的角色图片。
- 导出前必须检查 cell 尺寸、方向行数、动画列数、透明背景和原点。

## Current Pack

当前管理台默认使用已有的 PNG 原型包：

```text
moe-admin/public/pet/moe_content/avatar/
```

新生成的 SVG 仅作为实验源稿，不随管理台默认资源包发布。正式官方素材需要真实绘制的逐帧 PNG；当前 SVG 只用于验证分层协议和资源替换流程。

## Next Expansion

按以下顺序扩展：

1. 多身体、脸型和发型。
2. 帽饰、背部和手持物。
3. `attack`、`hurt`、`run` 动作。
4. PNG 正式绘制稿替换 SVG 原型。
5. 导出后的 Flutter 运行时验证。
