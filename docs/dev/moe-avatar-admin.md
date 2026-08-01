# Moe Avatar — 管理台编辑器（moe-admin）

> **角色**是「养成内容包」的一类；家具/装饰见 [moe-pet-content-pack.md](./moe-pet-content-pack.md)  
> **入口**：运营 → **养成内容** → 角色装扮（`/ops/biz/pet/avatar`）

## 1. 目标

在 **现有 moe-admin（Vite + React）** 内实现角色装扮**生产力**工具：

- **分层导出**：每个槽位单品各一份 walk/idle sheet，非整身合体图
- **运行时任意组合**：App 读 manifest，按 `composeOrder` 叠层；帽/衣/裤/鞋 id 自由搭配
- Canvas **实时合成**（admin 验证上传效果）
- **单品生产**：新建 id · 上传 walk/idle · 删单品
- **manifest JSON** 高级编辑 Tab

不内嵌 ULPC 整站；不导出「固定套装」sprite。ULPC 仅为过渡参考。

## 2. 代码位置

| 路径 | 职责 |
|------|------|
| `moe-admin/src/pages/PetAvatarEditorPage.tsx` | 页面（双 Tab） |
| `moe-admin/src/features/moe-avatar/` | composer · Canvas 组件 · zip 导出 |
| `moe-admin/public/pet/moe_content/avatar/` | 开发用 manifest + 层 PNG |

## 3. 工作流

```text
1. cd moe-admin && npm run dev
2. 打开 /ops/biz/pet/avatar → **生产编辑**
3. 选槽位 → **新建单品** 或选已有 → 上传 walk/idle 分层 PNG
4. 中间「实时合成」确认叠层效果（与 App 同款逻辑）
5. 「导出官方包 zip」
6. 解压到 moe-social：assets/pet/moe_content/avatar/
7. App 换衣/小家验证（Flutter 接入 petMoeAvatar 后）
```

## 4. 与 Flutter 关系

| 阶段 | App |
|------|-----|
| 现在 | 仍用 `petLpcPrototype` + `lpc_catalog.json` |
| 下一竖切 | `FeatureFlags.petMoeAvatar` + 读 `assets/pet/moe_avatar/manifest.json` |

## 5. MVP 已做 / 待做

| 已做 | 待做 |
|------|------|
| Canvas **实时合成**（上传后立即刷新） | cellSize 128 正式软 Q 美术 |
| **单品生产**：新建 id · 上传 walk/idle · 删单品 | 后端上传 pack / admin 持久化 |
| zip 导出 manifest/layers/thumbs/baked | 与 Flutter composer 联调 |
| manifest JSON 高级编辑 Tab | 格线模板 PNG 下载 |

## 6. 依赖

- `jszip` — 官方包 zip（已加入 `moe-admin/package.json`）
- 原生 `<canvas>` — 无需额外 UI 库

## 7. 相关文档

- [moe-avatar/README.md](../../moe-avatar/README.md)
- [moe-avatar/spec/editor-vision.md](../../moe-avatar/spec/editor-vision.md)
- [pet-lpc-pipeline.md](./pet-lpc-pipeline.md)（LPC 短跑 · 过渡）
