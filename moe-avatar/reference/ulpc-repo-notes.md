# ULPC 仓库阅读笔记（本地 clone）

路径：`C:\Users\ZhuanZ1\Desktop\Universal-LPC-Spritesheet-Character-Generator`

## 启动

```powershell
cd C:\Users\ZhuanZ1\Desktop\Universal-LPC-Spritesheet-Character-Generator
npm install
npm run dev
# http://localhost:5173
```

## 关键常量（`sources/state/constants.ts`）

| 常量 | 值 | Moe v1 计划 |
|------|-----|-------------|
| `FRAME_SIZE` | 64 | **128** |
| `DIRECTIONS` | up, left, down, right | 同序 |
| `ANIMATION_CONFIGS.walk` | row 8, cycle 9 帧 | 同逻辑，格变大 |
| `ANIMATION_CONFIGS.idle` | row 22, cycle 2 帧 | 同逻辑 |

ULPC 标准 sheet **很高**（含 spellcast/thrust/… 多段）；Moe v1 只导出 **walk + idle 两行区域** 即可。

## 数据流

```text
用户选部件 (CategoryTree)
    → state.selections { itemId, variant, … }
    → catalog.getItemMerged + layersMetadata (zPos)
    → renderer.runRenderCharacter → drawCalls[]
    → Canvas 预览 / 导出
```

Metadata **构建时生成**（`vite` 插件 + scripts），不在运行时读 `sheet_definitions/*.json` 原文。

## 导出（`sources/components/download/Download.ts`）

- **Spritesheet PNG** — `canvas/download.ts` → `downloadAsPNG`
- **ZIP split by item** — `state/zip.ts` → `exportSplitItemSheets` → 每层 `renderSingleItem` → `items/*.png`
- **character.json** — `state/json.ts` → `serializeLayersForJson(drawCalls)`

Moe Editor 的「官方包导出」≈ ULPC 的 **split by item** + **按动画拆 walk/idle 文件** + **manifest 命名** + **thumbs**。

## 自定义图（`AdvancedTools.ts`）

- 仅 `state.customUploadedImage` + 手填 `customImageZPos`
- **无**模板锚点、无槽位、无 walk/idle 校验  

→ Moe Editor 的 **Import Layer** 要自己做，这是主要增值点。

## 与 `moe-avatar` manifest 字段对照

| ULPC | Moe manifest v1 |
|------|-----------------|
| `itemId` + `layerNum` | `slots.top.top_basic.walk` 路径 |
| `zPos` | `composeOrder` 顺序 |
| `character.json` layers[] | `manifest.json` base + slots |
| credits.csv | **无**（官方包） |
| ZIP items/foo.png | `layers/slots/top_basic_walk.png` |

## 详见

- [editor-vision.md](../spec/editor-vision.md) — Moe Editor 产品定义  
- [moe-avatar-spec-v1.md](../spec/moe-avatar-spec-v1.md) — 模板契约
