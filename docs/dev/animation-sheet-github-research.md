# 序列帧工作台 GitHub 调研

> 调研时间：2026-08-02。本文用于产品和技术选型，不表示直接复制任何第三方代码。

## 结论

当前项目已经具备“导入 → 帧条 → 统一画布 → 预览 → PNG + JSON 导出”的原型闭环，但距离稳定交付还缺少三类能力：可靠的抠图质量、单一且一致的整理数据模型、真实引擎回测。

建议保留现有 React + Canvas + 本地处理方向，吸收成熟项目的交互和数据契约，不直接引入 GPL/AGPL 代码。下一阶段的核心目标是：

1. 帧条成为唯一的播放与导出顺序入口，左到右不再与额外动画分组产生冲突。
2. 统一锚点、统一 cell、帧级变换和导出矩形使用同一份状态。
3. 抠图从简单颜色洪泛升级为“AI 初始蒙版 + 可控边缘修复 + 噪点清理”。
4. 用 Godot 网格裁剪真实导入导出结果，而不是只验证浏览器预览。

## 重点参考项目

### `markentingh/SpriteSheetEditor`

- 地址：[github.com/markentingh/SpriteSheetEditor](https://github.com/markentingh/SpriteSheetEditor)
- 许可证：GPL-3.0，适合研究交互，不适合直接复制代码到当前管理台。
- 与本项目最接近：React + Vite + Tailwind 的浏览器端 Sprite Sheet 编辑器。
- 值得借鉴：多 Sheet 标签、网格参数、单帧启用/禁用、拖拽重排、时间线、FPS、缩放和 Pan、预览背景、项目 JSON 保存/加载。
- 特别值得借鉴的是“预览状态完整保存”和“选中帧集合直接驱动播放与导出”，这能避免我们现在帧池和动画分组两套顺序互相冲突。
- 还提供像素编辑器、取色/容差、Chroma Key 和蒙版预览，可作为后续抠图手工修复方向。

### `tigermkiiiddd/sprite-pipeline`

- 地址：[github.com/tigermkiiiddd/sprite-pipeline](https://github.com/tigermkiiiddd/sprite-pipeline)
- 许可证：MIT。
- 形态：Godot 4 .NET 插件 + 本地 Web 编辑器。
- 值得借鉴：`LoadSheet → FrameView → SaveSheet` 的单向数据流、foot anchor/pivot、frame tags、aligned 标记，以及让资源文件成为唯一事实来源。
- 对我们的直接启发：JSON 应明确保存每帧矩形、pivot、tag、disabled、duration 和动画归属；Godot 验证应成为验收步骤，而不是额外产品分支。

### `imgly/background-removal-js`

- 地址：[github.com/imgly/background-removal-js](https://github.com/imgly/background-removal-js)
- 许可证：AGPL-3.0，商业/闭源集成前必须单独做许可证评估。
- 能力：浏览器或 Node.js 端本地 AI 背景移除，强调隐私和不上传。
- 值得借鉴：把 AI 分割作为“初始蒙版”，再进入边缘清理和人工修正，而不是把颜色距离算法当成最终抠图方案。
- 当前不建议直接接入，先确认许可证、模型文件许可证、包体大小和 WebGPU/WASM 兼容性。

### `thebarbadev/erase-bg`

- 地址：[github.com/thebarbadev/erase-bg](https://github.com/thebarbadev/erase-bg)
- 许可证：MIT；其 README 同时依赖 ISNet ONNX 模型，模型许可证需要单独确认。
- 能力：ONNX Runtime Web，优先 WebGPU，回退 WASM，完全本地处理。
- 值得借鉴：将抠图模块封装成输入 Blob → 透明 PNG 的独立服务，并允许指定模型地址；后续可以在当前 `removeImageBackground` 外增加可选 AI provider。

### `RetroNick2020/raster-master`

- 地址：[github.com/RetroNick2020/raster-master](https://github.com/RetroNick2020/raster-master)
- 许可证：MIT。
- 值得借鉴：项目文件可携带多张图和编辑状态、缩略图/胶片带管理、面向多种引擎和语言的导出思路。
- 对我们的启发：增加可重开的工作区项目文件，而不是只保存最终 Sheet；最终 PNG、JSON 和源帧引用应该可以一起恢复。

### 其他低优先级参考

- [`craftworkgames/SpriteFactory`](https://github.com/craftworkgames/SpriteFactory)：MIT，MonoGame Sprite Sheet 动画编辑器，但 README 明确仍是 WIP，可参考范围控制和基础动画编辑。
- [`ChrisLR/godot-spritesheet-organizer`](https://github.com/ChrisLR/godot-spritesheet-organizer)：GPL-3.0，Godot 内网格 Sheet 整理，可参考 Godot 侧工作流，不直接复制实现。
- [`soshimozi/snes-tools`](https://github.com/soshimozi/snes-tools)：无明确许可证，TypeScript + React 的多 Sheet、tile、meta-sprite 和 JSON/PNG 导出思路可观察，但不应直接复用代码。

## 对当前实现的统一问题清单

### P0：必须先解决

- **抠图可靠性不足**：当前是颜色距离 + 边缘洪泛 + 孤立连通域，容易残留噪点，也可能误伤白发、脸部高光和衣服亮色区域。
- **缺少非破坏式蒙版**：清理后只保留一次原始帧恢复，不能查看蒙版、擦除/恢复局部区域、调节容差后重新计算。
- **导出没有真实验收**：没有自动检查透明边缘、空白 cell、尺寸一致、帧数、源帧映射和 JSON 矩形是否一致。
- **没有 Godot 回测**：需要用真实导出 PNG 在 Godot 中网格裁剪并播放，验证 pivot、行列和透明通道。

### P1：影响产品一致性

- **历史动画元数据需要收敛**：产品界面不再提供独立动画分组；导入旧 JSON 时仅保留第一条序列的元数据，并按当前帧条重建输出顺序。
- **帮助文案与界面已收敛**：当前引导只说明导入、排序、统一画布、蒙版和导出；Godot 动画编辑留给 Godot 原生能力。
- **统一变换语义不清晰**：偏移/缩放控件实际会批量作用于所有帧，但界面仍显示“当前帧”，恢复按钮也只恢复单帧。
- **预览背景不是统一渲染管线**：多帧预览和单张图集切格预览走不同绘制逻辑，背景选择不能保证在所有阶段生效。
- **项目状态没有持久化**：刷新页面后帧池、排序、锚点、时长、禁用状态和清理前快照都会丢失。

### P2：交付体验和扩展能力

- 导出目前以 ZIP 为主，应同时提供直接下载 PNG 和 JSON。
- 需要“保存工作区 / 加载工作区”，包括源帧、变换、动画、背景清理参数和输出设置。
- 需要批量处理多动作、多角色和重复使用帧的验证。
- 需要输出前的透明背景检查、边缘高亮检查和“当前预览 / 最终 Sheet”对照。

## 建议的升级顺序

1. 固化单一 `AnimationSheetDocument` 状态模型，帧条顺序作为唯一整理、预览和导出顺序；动作命名和播放编辑交给 Godot。
2. 把抠图拆成 `SegmentationProvider → MatteCleanup → Preview/Export` 三层，先保留颜色算法，再增加可选 ONNX/WASM provider。
3. 加入蒙版预览、前景/背景对比、容差、孤立区域大小、边缘收缩/羽化和人工擦除恢复。
4. 统一所有预览、测量、导出都调用同一个 `renderFrameToCell`，消除当前单帧/多帧分支差异。
5. 增加导出契约测试和一组真实 AI 帧 fixture，检查 RGBA、网格尺寸、帧顺序、透明边缘和 JSON 重导入。
6. 用 Godot 4 建立最小回测场景：导入 PNG，按 JSON 或固定 cell 网格创建 AnimatedSprite2D，验证播放和 pivot。
7. 最后再考虑多动画行、项目持久化、直接导出和 AI provider 的性能优化。

## 许可证结论

- 可优先研究或借鉴架构：MIT 项目。
- GPL-3.0 项目：只借鉴产品行为和公开文档，不复制代码或组件实现。
- AGPL-3.0 抠图库：不直接集成，除非明确接受网络服务/分发义务或取得商业许可。
- ONNX 模型、预训练权重和示例素材必须与代码许可证分开审查。
