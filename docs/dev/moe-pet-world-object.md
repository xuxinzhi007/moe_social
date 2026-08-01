# Moe 养成 · World Object 与内容包长期架构

> **日期**：2026-08-01  
> **状态**：架构 SSOT · admin MVP 进行中  
> **前置**：[moe-pet-content-pack.md](./moe-pet-content-pack.md)

## 1. 结论（对齐你的分析）

「养成内容」**长期应是统一内容包平台**，不是三个孤岛编辑器：

| 现状 | 长期 |
|------|------|
| avatar / furniture / decor 分 manifest | **单一 Pet Content Pack**，按 `kind` 分节 |
| 家具 = 资源预览 + JSON | **World Object** 定义 + **场景编辑器** |
| 运行时仅 `PetFurniture` 摆放 | 可拾取 / 可交互 / 背包状态机 |
| 角色 = LPC 式 sheet | 仍为 `avatar` 子域，但进同一 pack |

你的判断准确：**缺的不是多一个按钮，而是通用对象模型 + admin 场景编辑 + runtime 拾取流转。**

## 2. 三层能力（对应你列的三点）

### 2.1 数据模型 — `WorldObjectDef`

在 `FurnitureItemDef` 之上演进为统一对象（家具 / 装饰 / 可拾取物 / 静态道具）：

```typescript
// 目标形态（v2 schema · admin types 待对齐）
type WorldObjectDef = {
  id: string
  kind: 'furniture' | 'decor' | 'pickup' | 'prop'
  label: string
  asset: { path: string; thumb?: string }
  scenes: string[]           // living | yard | bedroom
  transform: {
    anchor: 'bottom_center' | 'center'
    defaultScale: number
    zIndex?: number
  }
  interaction?: {
    draggable: boolean       // 布置模式可拖（默认 true 家具）
    rotatable: boolean
    scalable: boolean
    pickupable: boolean      // 可拾取进背包
    interactable: boolean    // 点击触发 use
    useAction?: string       // feed | sit | open | custom:*
    collision?: 'none' | 'block' | 'platform'
    dropTo?: 'floor' | 'hand' | 'inventory'
  }
  placement?: 'floor' | 'wall' | 'hanging'  // decor
}
```

| 字段 | App  today | 需要补 |
|------|------------|--------|
| x/y/rotation/scale | ✓ `PetFurniture` | — |
| draggable/rotate/scale UI | ✓ `PetRoomGame` 布置模式 | 读 manifest 默认值 |
| pickupable / inventory | ✗ | `PetInventory` + provider |
| useAction | ✗ | 事件 / 后端 item |

**avatar（角色）不进 WorldObject**：仍是分层 sheet + 槽位 id，但在 **同一 pack** 的 `avatar` 节。

### 2.4 角色动画 = Moe 自有 catalog（你的提议 · 已写入 schema）

人物与家具一样，是**长期核心资产**，不是「借用 ULPC 的附属品」：

```json
"avatar": {
  "animationPolicy": { "source": "moe_official" },
  "animations": {
    "walk": { "cols": 9, "rows": 4 },
    "idle": { "cols": 2, "rows": 4 }
  }
}
```

| v1（现在） | 后续（manifest 扩展即可） |
|------------|---------------------------|
| walk + idle，4 方向 | run、emote、sit、pickup、feed… |
| admin 分层 sheet 导出 | 格模板 + 动作注册 UI |
| App LPC 过渡 | `PetContentRegistry` 只认 manifest key |

**原则**：App **不得**硬编码 ULPC 动画全集；新动作 = 官方 sheet + manifest 注册 + App 播放器支持该 key。

### 2.2 admin — 场景编辑器（未做）

在「单品 manifest」之上增加：

```text
SceneEditorPage
  ├── 房间底图（living_bg.png）
  ├── 对象层（拖入 manifest 里的 WorldObject）
  ├── 变换：位置 / 旋转 / 缩放 / zIndex
  ├── 交互开关：可拾取 · 可 use · 碰撞
  └── 导出：preset 布局 JSON（可选）+ 仍导出 object 定义
```

这与 LPC「选层预览」互补：**LPC 管角色 sheet；Scene Editor 管房间里摆什么、怎么交互。**

### 2.3 runtime — 拾取与状态

```text
PetContentPack.load(manifest)
    → WorldObjectRegistry（id → def）
    → 布置模式：spawn 可 dragger 实例（已有）
    → 游玩模式：pickupable → inventory；interactable → useAction
```

`PetProvider`  today：`placeFurniture` / `moveFurniture` — 摆放已有；需加 `pickupObject` / `useObject` / `inventory` 持久化。

## 3. 分期（最小可行 → 完整体系）

| 阶段 | admin | App | manifest |
|------|-------|-----|----------|
| **现在** | 角色 MVP；家具/装饰资源预览；**统一 pack 导出** | LPC 角色 + 家具拖放 | `moe_content/manifest.json`（avatar + objects） |
| **P1** | 导入 PNG · 格模板 · Flutter 消费统一 manifest | 读 `moe_content/manifest.json` | + `animationPolicy` |
| **P2** | **场景编辑器** MVP（摆对象、存 preset） | `WorldObjectRegistry` | + `interaction` 字段 |
| **P3** | 拾取 / use 预览 | inventory + pickup 动画 | + 后端 `game_item` 对齐 |
| **P4** | 远程 pack 版本 / OSS | 热更新 content pack | 签名 + 版本号 |

## 4. 与 LPC 的关系（再强调）

| LPC | Moe Content Pack |
|-----|------------------|
| 全动画 · 全品类部件 | **walk/idle** + 软 Q（avatar 子集） |
| 在线/本地 Generator | **admin 内容包平台** |
| CC 素材库 | 官方自有 + 可选社区 |
| 不涉及房间摆放 | **World Object + Scene Editor** |

不要复刻 LPC 全量；要复刻 **「模板 + 导出 + 可扩展 catalog」** 思路。

## 5. 代码落点（规划）

| 层 | 路径 |
|----|------|
| SSOT 文档 | `docs/dev/moe-pet-content-pack.md` · 本文 |
| admin 类型 | `moe-admin/src/features/moe-content/petContentPack.ts` · `worldObject.ts` |
| admin 统一导出 | `exportUnifiedPetPack.ts` · 总览页「导出完整内容包」 |
| admin 场景编辑 | `moe-admin/src/pages/PetSceneEditorPage.tsx`（P2） |
| Flutter registry | `lib/game/pet/pet_content_registry.dart`（P1） |
| 背包/拾取 | `lib/models/pet_inventory.dart` · `PetProvider`（P3） |

## 6. 当前 MVP 边界（避免 scope 漂移）

**现在做完就够用的：**

- 统一 pack 目录 `assets/pet/moe_content/`
- 角色 walk/idle 导出
- 家具/装饰 object 定义（无 interaction 字段也可先跑）

**明确不做进当前 sprint：**

- 全 LPC 动画集
- 完整 3D/Spine 模型编辑器
- 拾取/backend 全链路（先写进 schema，后接 runtime）

---

**你的分析 = 本产品长期方向。** 下一步建议：**冻结 `WorldObjectDef` v2 schema → P1 合并 manifest → P2 场景编辑器。**
