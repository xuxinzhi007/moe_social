# Pet 绑定骨架 SSOT（正式 · Paper 单轨）

> **日期**：2026-08-01  
> **状态**：正式绑定契约 · 资源方只换图/改 JSON，禁止再开平行渲染默认  
> **目的**：你找图 → 按本文件登记 → App 自动出现在换装/商店/小家；不再靠硬编码假 ID

---

## 0. 一句话

> **角色显示轨（当前）= LPC**（`petLpcPrototype=true`，Moe=false）：走动 sheet，换装绑 `lpc_catalog.json` + `assets/pet/lpc/layers/`。  
> **家具/商店/房间**仍走 `content_manifest` / `room_composition`（与显示轨无关）。  
> 合成失败会回落 Paper PNG，禁止蓝块占位。

---

## 1. 目录与职责（冻结）

| 路径 | 放什么 | 谁改 |
|------|--------|------|
| `assets/pet/lpc/layers/` | **LPC 角色层**（body/head/face/hair + 服装 idle/walk） | 美术 |
| `assets/pet/config/lpc_catalog.json` | **LPC 换装绑定**（id → 层路径） | 绑定 |
| `assets/pet/lpc/hero_*.png` | 合成失败时的整表回落 | 美术 |
| `assets/pet/character/` | Paper 回落本体：`model.png` 等 | 美术 |
| `assets/pet/clothes/{id}.png` | Paper 服装分片（回落轨） | 美术 |
| `assets/pet/furniture/{id}.png` | 家具图，**文件名 = 家具 id** | 美术 |
| `assets/pet/room/{scene}_bg.png` | `living` / `yard` / `bedroom` 背景 | 美术 |
| `assets/pet/ui/` | 图标（coin 等） | 美术/UI |
| `assets/pet/config/avatar_stack.json` | 穿搭深度 + **wearAnchors** 默认锚点 | 绑定/研发 |
| `assets/pet/config/content_manifest.json` | **货架唯一清单**（服装+家具+展示名） | 绑定 |
| `assets/pet/config/shop_catalog.json` | 软币商品（id 必须已在 manifest） | 绑定 |
| `assets/pet/config/room_composition.json` | 房间尺度 + 三场景起步构图 | 绑定/研发 |
| `assets/pet/config/unlock_table.json` | 年龄解锁 | 产品/研发 |

**禁止**：在 `pet_dressing_page` / 商店里再写一长串不存在的 `hat_crown` 等假 ID。

---

## 2. ID 与文件命名（绑定规则）

### 2.1 服装（LPC 显示轨 · 优先）

| 槽 | 在 `lpc_catalog.json` | 层文件 |
|----|----------------------|--------|
| top | `slotLayers.top.{id}` | `lpc/layers/*_idle.png` + `*_walk.png` |
| bottom | 同上 | 同上 |
| shoes | 同上 | 同上 |
| hat | 同上（可空） | 同上 |

绑定步骤（LPC 新衣服）：

1. 导出/放入 idle + walk 两张层图到 `assets/pet/lpc/layers/`  
2. 在 `lpc_catalog.json` → `slotLayers.{slot}` 登记 id → walk/idle 路径  
3. （可选）同 id 写入 `content_manifest` / `shop_catalog` 方便商店展示名  
4. 热重启；换衣间与小家应更新  

### 2.1b Paper 回落轨（Flag 关 LPC 时）

| 槽 | 文件 |
|----|------|
| 四槽 | `assets/pet/clothes/{id}.png` + `content_manifest` |

锚点仅 Paper：`avatar_stack.json` → `wearAnchors`。

### 2.2 家具

| 类型前缀 | 示例 |
|----------|------|
| `bed_` / `table_` / `lamp_` / `rug_` / `window_` | `bed_basic.png` |

绑定步骤：

1. 放入 `assets/pet/furniture/{id}.png`  
2. `content_manifest.json` → `furniture[]` 登记，`scenes` 写可用场景  
3. （可选）`shop_catalog.json`  
4. 默认尺寸看 `room_composition.json` → `furnitureDefaults`（按前缀）  
5. 起步摆放看同文件 `scenes.*.slots`

### 2.3 房间背景

| sceneId | 文件 |
|---------|------|
| living | `assets/pet/room/living_bg.png` |
| yard | `assets/pet/room/yard_bg.png` |
| bedroom | `assets/pet/room/bedroom_bg.png` |

要求：竖屏、无平台水印、与扁平角色尽量同族色。

---

## 3. JSON 契约（最小字段）

### 3.1 `content_manifest.json`

```json
{
  "specVersion": "1",
  "pattern": "paper",
  "clothes": {
    "hat": [{ "id": "hat_cap", "label": "帽子", "asset": "assets/pet/clothes/hat_cap.png" }]
  },
  "furniture": [
    { "id": "bed_basic", "label": "小床", "asset": "assets/pet/furniture/bed_basic.png", "scenes": ["living", "bedroom"] }
  ]
}
```

规则：`asset` 必须真实存在；UI **只展示** manifest 内 id。

### 3.2 `room_composition.json`

- `actor.footY` / `displayHeightNorm`：角色站位与高度  
- `furnitureDefaults.{kind}.scale`：新放家具默认倍率  
- `scenes.{id}.slots[]`：`{ id, x, y, scale, rotation }` 起步构图  

### 3.3 `avatar_stack.json`

- `body.*`：角色分层路径（缺则用 `fallbackWhole` = model）  
- `wearAnchors`：四槽默认贴合  

---

## 4. 运行时读取（维护边界）

| 类 | 职责 |
|----|------|
| `PetContentCatalog` | 读 manifest / shop / composition；失败用内置真实回落 |
| `PetArt` | 路径解析；优先 catalog 登记的 asset |
| `PetAvatarStack` | 读 avatar_stack 合成 Paper |
| Page / Provider | **禁止**硬编码货架 ID 列表 |

Flag：`petMoeAvatar` / `petLpcPrototype` 正式默认 **false**。

---

## 5. 资源方检查清单（交图前）

- [ ] 文件名 = id，路径符合上表  
- [ ] PNG 真透明（无白底大方块）  
- [ ] 已写入 `content_manifest.json`  
- [ ] 若可买：已写入 `shop_catalog.json`  
- [ ] 家具：scenes + 默认 scale 合理  
- [ ] 热重启后：换装/商店/小家能看到，且无蓝块占位  

---

## 6. 与其它文档

| 文档 | 关系 |
|------|------|
| `pet-layered-avatar.md` | 分层穿搭细节 |
| `pet-content-pack-maturity.md` | moe_content 包成熟度（工具轨） |
| 产品止损 / 仿成品方案 | 体验与排期；**绑定以本文为准** |
