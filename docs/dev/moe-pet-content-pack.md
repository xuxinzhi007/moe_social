# Moe 养成内容包（Pet Content Pack）

> **日期**：2026-08-01  
> **状态**：Spec v1 · **中间态**（非官方完全闭环）  
> **成熟度对照**：**[pet-content-pack-maturity.md](./pet-content-pack-maturity.md)** ← 官方标准 / 现状 / 待补齐  
> **编辑器**：`moe-admin` → 运营 → **养成内容**

## 1. 定位

**不是「角色换装页」**，而是 **官方养成资产生产平台**：admin 产 pack → App 消费。

> **三层边界**（规范 / 兼容 / 运行）与 capability 矩阵见 [pet-content-pack-maturity.md](./pet-content-pack-maturity.md)。

管理台统一产出 App 可消费的 **官方内容包**：

| 类型 | `kind` | App 用途 | 资源形态 |
|------|--------|----------|----------|
| **角色** | `avatar` | 换衣间 + 小家走动 | 分层 walk/idle sheet + manifest |
| **家具** | `furniture` | 小家布置模式拖放 | 单张透明 PNG + 元数据 |
| **装饰** | `decor` | 墙贴 / 挂饰 / 地饰等 | 单张 PNG 或轻量 sheet（v2） |

三类可打 **同一个 zip**（`pet-content-pack.zip`）或分 kind 导出；manifest 用 `kind` / 顶层分节区分。

**长期**：统一为 **World Object + avatar** 单一 pack，见 [moe-pet-world-object.md](./moe-pet-world-object.md)。

## 2. 统一 manifest（v1 · 已实现）

根路径：`public/pet/moe_content/manifest.json`（admin 静态预览 + 导出 zip SSOT）

```json
{
  "specVersion": "1",
  "packId": "moe-official-pet-v1",
  "displayName": "Moe 官方养成包",
  "publish": {
    "version": "1.0.0",
    "builtAt": "2026-08-01T00:00:00.000Z",
    "minAppVersion": "1.0.0"
  },
  "avatar": {
    "cellSize": 64,
    "directionRows": ["up", "left", "down", "right"],
    "animations": {
      "walk": { "cols": 9, "rows": 4 },
      "idle": { "cols": 2, "rows": 4 }
    },
    "animationPolicy": {
      "source": "moe_official",
      "description": "姿势/动作由 Moe 在 manifest 注册；App 只播放 catalog 内 key"
    },
    "composeOrder": ["body", "bottom", "top", "shoes", "head", "face", "hat", "hair"],
    "base": { "...": "layers/base/*_walk|idle.png" },
    "slots": { "...": "帽/衣/裤/鞋 分层 sheet" }
  },
  "objects": {
    "bed_basic": {
      "id": "bed_basic",
      "kind": "furniture",
      "asset": { "path": "objects/bed_basic.png" },
      "scenes": ["living", "bedroom"],
      "transform": { "anchor": "bottom_center", "defaultScale": 1 },
      "interaction": { "draggable": true, "rotatable": true, "scalable": true }
    }
  }
}
```

### 2.1 角色 = 一等资产（姿势/动作自控 · 分层组合）

| 原则 | 说明 |
|------|------|
| **导出形态** | 各部位 **分层 sheet**（base + slots 每单品 walk/idle），**不是**整身合体图 |
| **运行时** | App 按 manifest `composeOrder` 叠层；`hatId`/`topId`/`bottomId`/`shoesId` **任意组合** |
| **唯一对齐约束** | 同 cellSize + 同 animations 格线（walk 9×4、idle 2×4）；部位对齐即可混穿 |
| **不绑 ULPC 全集** | `avatar.animations` 是唯一动画 catalog |
| **与 World Object 并列** | 同一 zip；长期都是「我们的内容资产」 |

| 字段 | 角色 | 家具/装饰 |
|------|------|-----------|
| 动画 sheet | ✓ `animations` catalog（Moe 控） | ✗（v1 静态图） |
| 槽位 slots | hat/top/bottom/shoes | ✗ |
| 场景 scenes | — | living / yard / bedroom |
| 锚点 anchor | origin / headCenter | bottom_center / center |
| 商品 id | 与后端 `hat_id` 等一致 | 与 `PetFurniture.id` 一致 |

## 3. 编辑器（moe-admin）

```text
/biz/pet/content     总览 · 三类入口
/biz/pet/avatar      角色 · Canvas 叠层 + 导出
/biz/pet/furniture   家具 · 单品预览 + 导出
/biz/pet/decor       装饰 · 规划（P1）
```

代码：

| 路径 | 职责 |
|------|------|
| `moe-admin/src/features/moe-content/petContentPackTypes.ts` | **Pack 类型 SSOT**（manifest · publish · scenePreset） |
| `src/features/moe-avatar/` | 角色 composer / 生产编辑器 |
| `src/features/moe-content/worldObject.ts` | WorldObjectDef 字段 |
| `src/features/moe-content/petContentPack.ts` | 合并 manifest · 导出 helpers |
| `src/pages/PetContentHubPage.tsx` | 总览 |
| `public/pet/moe_content/` | 开发用资源 |

**无跨仓 TS 引用**；根目录 `moe-avatar/` 仅 Spec 文档归档（可选迁入 `moe-admin/docs/`）。

## 4. 导出 → Flutter

```text
admin 导出 zip
  → assets/pet/moe_content/
       manifest.json
       avatar/…
       furniture/items/*.png
       decor/…
  → App：PetArt / composer 按 kind 读取
```

| App 现状 | 迁移 |
|----------|------|
| `assets/pet/lpc/` + lpc_catalog | avatar 过渡 |
| `assets/pet/furniture/{id}.png` | furniture manifest |
| 装饰未独立 | decor 新域 |

## 5. 分期

| 期 | 内容 |
|----|------|
| **P0** | 角色编辑器 MVP（已有）+ 内容总览 + 家具 manifest 预览/导出 |
| **P1** | **合并单 zip**（已实现 admin 导出）· 装饰 · 导入 PNG · Flutter 读统一 manifest |
| **P2** | admin 上传 OSS · App 拉远程 pack · 社区包 |

## 6. 相关文档

- [moe-avatar-admin.md](./moe-avatar-admin.md) — 角色编辑器细节  
- [moe-avatar/spec/moe-avatar-spec-v1.md](../../moe-avatar/spec/moe-avatar-spec-v1.md) — 角色模板  
- [pet-life-sim-roadmap.md](./pet-life-sim-roadmap.md) — 养成路线图  
