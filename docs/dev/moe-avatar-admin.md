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
| **现在** | `FeatureFlags.petMoeAvatar=true` · `PetMoeAvatarComposer` 读 `assets/pet/moe_content/avatar/manifest.json` · 换衣间 + 小家走动 |
| 回滚 | `petMoeAvatar=false` · `petLpcPrototype=true` 或 PNG |

## 5. 两种形象模式（重要）

| 模式 | 配置 | 身体 | 换装 |
|------|------|------|------|
| **格线 sheet（本页 · 过渡）** | `petMoeAvatar=true` | 64px walk/idle 四方向格 · LPC 原型素体 | 各槽 **整张 sheet 叠层**；PNG 只画该部位、其余透明 |
| **官方锚点模型（App 目标）** | `petMoeAvatar=false` | `assets/pet/character/` 头/躯干/腿/臂 + `avatar_stack.json` | 帽/衣/裤/鞋 **wearAnchors** 定位，分部位贴合 |

- 用户预期的「头/帽/身/腿/脚各就各位」= **锚点模型**（见 [pet-layered-avatar.md](./pet-layered-avatar.md)），不是本页格线 sheet。
- 本页 sheet 仅为 walk/idle 动画 **生产过渡**；正式美术应产出锚点分片或 Spine（[pet-spine-avatar.md](./pet-spine-avatar.md)）。
- manifest 中**每个单品 id 必须有独立文件路径**（如 `top_hoodie_walk.png`），禁止多 id 共用一路径。

## 6. 完整闭环（admin → App）

```text
1. admin /biz/pet/avatar → 生产编辑
2. 下载 walk/idle 格线模板 → 按格绘制各部位 sheet
3. 素体 base + 槽位单品：上传 PNG（自动校验尺寸）
4. 实时合成预览 → 导出官方包 zip
5. 解压到 assets/pet/moe_content/avatar/（覆盖 manifest + layers）
6. flutter run → 换衣间任意组合 · 小家 walk/idle
```

| 已做 | 待做 |
|------|------|
| 格线模板下载 · 上传尺寸校验 · **智能裁剪（原图 _originals/）** | cellSize 128 正式软 Q 美术 |
| 素体 base + 槽位单品生产 · 分层 zip 导出 | admin 服务端持久化 |
| **Flutter 闭环**：换衣间 + 小家 compose | 远程 pack 热更新 |
| manifest JSON 高级编辑 | 部件 rail 读 manifest label |

## 7. 依赖

- `jszip` — 官方包 zip（已加入 `moe-admin/package.json`）
- 原生 `<canvas>` — 无需额外 UI 库

## 8. 相关文档

- [moe-avatar/README.md](../../moe-avatar/README.md)
- [moe-avatar/spec/editor-vision.md](../../moe-avatar/spec/editor-vision.md)
- [pet-lpc-pipeline.md](./pet-lpc-pipeline.md)（LPC 短跑 · 过渡）
