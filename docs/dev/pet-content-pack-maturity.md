# Pet Content Pack · 成熟度对照（官方标准 / 现状 / 待补齐）

> **日期**：2026-08-01  
> **状态**：中间态 · 可继续推进 · **非**「官方标准已完全闭环」  
> **SSOT 规范**：`moe-admin/src/features/moe-content/petContentPackTypes.ts` · `worldObject.ts`  
> **代码能力矩阵**：`moe-admin/src/features/moe-content/petContentPackCapabilities.ts`

---

## 1. 一句话结论

当前方案是 **合理的过渡统一方案**：方向成立、可落地，但仍是 **规范 + 兼容 + 运行** 三层并行，尚未形成强约束的「官方生产 → 校验 → 发布 → App 消费 → 回滚」闭环。

**推进原则**：规范层只增不平行；兼容层有退场日；运行层不宣称 schema 已支持但未接的能力。

---

## 2. 三层边界（定死）

```text
┌─────────────────────────────────────────────────────────────┐
│ 规范层 Spec                                                  │
│ petContentPackTypes.ts · worldObject.ts                     │
│ docs/dev/moe-pet-content-pack.md · moe-pet-world-object.md  │
│ → 新字段/新类型只在这里定义；禁止平行 manifest 类型           │
├─────────────────────────────────────────────────────────────┤
│ 兼容层 Compatibility（过渡 · 有退场计划）                      │
│ petContentPack.ts LegacyFurniture* · types.ts 别名           │
│ 旧家具/装饰编辑器 · 分目录 manifest                          │
│ → 只负责 legacy → WorldObjectDef 适配；2026-Q4 前收敛         │
├─────────────────────────────────────────────────────────────┤
│ 运行层 Runtime                                               │
│ Flutter: pet_content_registry.dart · feature flags · fallback│
│ admin: exportUnifiedPetPack · validatePackManifest           │
│ → 只消费规范层；能力以 PetContentRuntimeCapability 为准       │
└─────────────────────────────────────────────────────────────┘
```

| 层 | 允许 | 禁止 |
|----|------|------|
| **规范** | 扩展 `PetContentPackManifestV*` · `WorldObjectDef` · `validatePackManifest` | 在 pages/ 或 Flutter 手写平行 JSON 结构 |
| **兼容** | `furnitureItemsToObjects` · `types.ts` re-export | 新功能只写 legacy manifest、不进统一 pack |
| **运行** | 读统一 pack · flag 回退 · 声明已实现 capability | UI/文案宣称 pickup/inventory/scenePresets 已官方可用 |

---

## 3. 官方标准 / 现状实现 / 待补齐项

| 能力域 | 官方标准（目标） | 现状实现 | 待补齐 | 可进正式流程？ |
|--------|------------------|----------|--------|----------------|
| **Pack 结构** | 单一 `manifest.json`：`avatar` + `objects` (+ v2 `scenePresets`) | admin 可导出 zip；Flutter **未**读根 manifest | Flutter `PetContentRegistry.load()` · assets 落盘 | 导出侧 ✅ · App 侧 ⏳ |
| **类型 SSOT** | `petContentPackTypes.ts` + `worldObject.ts` | ✅ 已收拢；`types.ts` 为 legacy 别名 | 删除 `LegacyFurnitureManifest` 直连页面（改读 objects） | ✅ 规范已冻结 |
| **Avatar 生产** | 分层 walk/idle sheet · 每 id 独立路径 | admin MVP · compose 预览 · zip | 锚点官方模型 / Spine 正式美术 · 发布 hash | 生产工具 ✅ · 正式美术 ⏳ |
| **Avatar 消费** | manifest compose · 任意槽位组合 | `petMoeAvatar` + `PetMoeAvatarComposer` | 锚点模型为正式路径时切 flag 策略 | 格线 sheet ✅ · 锚点 ⏳ |
| **World Object 定义** | `WorldObjectDef` kind/scenes/transform/interaction | admin 合并进 pack · schema 完整 | App `WorldObjectRegistry` | 数据层 ✅ · runtime ⏳ |
| **家具摆放** | draggable/rotate/scale 读 manifest 默认 | `PetFurniture` + `PetRoomGame` 布置模式 | 默认值从 registry 读，非硬编码 | 部分 ✅ |
| **scenePresets** | v2 官方房间 preset · 场景编辑器产出 | 类型已预留 · **无**编辑器 | `PetSceneEditorPage` P2 | ❌ 预研 |
| **interaction 字段** | pickupable · useAction · collision · dropTo | schema 有 · export 写默认 false | App pickup/inventory/useAction | ❌ 预研 |
| **发布 publish** | version · builtAt · contentHash · minAppVersion · rollbackFrom | export 写 version/builtAt · hash 轻量 | OSS · 签名校验 · 强制回滚链路 | ❌ P4 |
| **校验** | 导出前 `validatePackManifest` 失败即阻断 | ✅ admin 导出已强制校验 | Flutter 启动校验 hash | 导出 ✅ · App ⏳ |
| **兼容回退** | Spine → Moe → LPC → PNG 锚点 | ✅ `resolvePetAvatarBackend` | 文档与 flag 策略统一 | ✅ |
| **codegraph** | 自动生成 · 只读 · 不参与 runtime | ✅ scripts/codegraph · admin 只读页 | — | ✅ 内部工具 |
| **Legacy types.ts** | 过渡别名 · 指向 SSOT | ✅ 仅 re-export | **2026-12-31** 前移除 DecorManifest 平行定义 | 过渡中 |

**图例**：✅ 可用 · ⏳ 进行中 · ❌ 不可宣称已完成

---

## 4. 什么能算「官方标准流程」

| 阶段 | 准入条件 |
|------|----------|
| **内部生产** | admin 导出 zip · `validatePackManifest` 通过 · 解压至 `assets/pet/moe_content/` |
| **App 内测** | Flutter 读 avatar 子包 **或** 统一 manifest（二选一需文档写明）· analyze 通过 |
| **对外官方包** | publish.contentHash · minAppVersion · 回滚脚本 · **且** runtime capability 与 manifest 字段一致 |
| **可交互世界物件** | `WorldObjectRegistry` + pickup/inventory **落地后** 才可对外 |

当前最高级别：**内部生产 + avatar 格线消费**。

---

## 5. 兼容层退场计划

| 项 | 退场动作 | 目标日 |
|----|----------|--------|
| `types.ts` `FurnitureManifest` | 家具页改 type alias → 直接 `LegacyFurnitureManifest` from pack 或读 unified | 2026-12-31 |
| 分目录 `furniture/manifest.json` | 家具编辑器写 `objects` 节或 unified manifest | 2026-12-31 |
| `LegacyFurnitureItem` | 仅保留 import 适配函数 | 2027-Q1 删除类型 |
| 格线 sheet avatar | 锚点/Spine 正式资源就绪后降级为过渡工具 | 美术就绪 |

---

## 6. 运行层 capability（与代码同步）

实现见：

- Admin：`petContentPackCapabilities.ts` → `PET_CONTENT_RUNTIME_CAPABILITIES`
- Flutter：`lib/game/pet/pet_content_registry.dart` → `PetContentRuntimeCapability`

**规则**：产品/UI 不得宣传 capability 矩阵中 `supported: false` 的项为「官方已支持」。

---

## 7. 下一步（按优先级）

| # | 任务 | 层 |
|---|------|-----|
| 1 | Flutter 读统一 `manifest.json` + `WorldObjectRegistry` 只读 | 运行 |
| 2 | 家具布置读 object.transform / interaction 默认值 | 运行 |
| 3 | export 阻断无效 manifest（已完成）+ contentHash | 规范/运行 |
| 4 | 场景编辑器 MVP → scenePresets v2 | 规范 + admin |
| 5 | pickup / inventory / useAction | 运行 |
| 6 | OSS 发布 + 回滚 | 规范 |

---

## 8. 相关文档

- [moe-pet-content-pack.md](./moe-pet-content-pack.md)
- [moe-pet-world-object.md](./moe-pet-world-object.md)
- [moe-avatar-admin.md](./moe-avatar-admin.md)
- [pet-layered-avatar.md](./pet-layered-avatar.md)
