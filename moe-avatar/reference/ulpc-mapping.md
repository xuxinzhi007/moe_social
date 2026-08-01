# 与 Universal LPC Generator 的对照

本地 clone 路径（示例）：

`C:\Users\ZhuanZ1\Desktop\Universal-LPC-Spritesheet-Character-Generator`

## 借鉴（工作流）

| ULPC 概念 | Moe Avatar 对应 |
|-----------|-----------------|
| `spritesheets/**/walk.png` | `layers/**/**_walk.png` |
| `sheet_definitions/*.json` 的 variants + z | `manifest.slots` + `composeOrder` |
| 64×64 格、4 方向行序 | Spec v1 默认 **128** 格，行序相同 |
| Generator UI：选层 → 预览 → 导出 | 独立 **Moe Avatar Editor** |
| `npm run dev` 本地预览 | 编辑器 dev 同样本地优先 |

## 不继承

| ULPC | Moe |
|------|-----|
| CC-BY / CC-BY-SA 素材 | 官方自绘 + 自有协议 |
| 像素 RPG 画风 | 软 Q 版（`assets/pet/character`） |
| 全量 `spritesheets/` 目录结构 | 仅 `manifest` 声明的文件 |
| `sheet_definitions` 文件名 | `manifest.json` + JSON Schema |
| 全动画全集 | v1 仅 walk + idle |

## 编辑器实现选项（clone 完成后评估）

1. **Fork 精简 ULPC** — 保留 UI 框架，换底模与导出格式 → 快，但要删大量代码  
2. **Greenfield** — Vite + Canvas，只实现 Spec v1 槽位 → 干净，工期稍长  
3. **混合** — 从 ULPC 抽 `composer` 逻辑，UI 重写 Moe 风  

建议：先读 ULPC 的 **层叠预览与导出 PNG** 相关代码，再定 fork 比例。clone 就绪后在本文件追加「关键文件路径」一节。

## 迁移对照

| 现有 `lpc_catalog.json` | `manifest-v1` |
|---------------------------|---------------|
| `base.body.walk` | `base.body.animations.walk` |
| `slotLayers.top.top_basic.walk[]` | `slots.top.top_basic.walk` |
| 无 | `slots.top.top_basic.thumb` |
| `admin.localGeneratorPath` | 编辑器仓库 README，不进 manifest |
