# Pet 装扮 C 方案：Spine 骨骼角色

> **日期**：2026-08-01  
> **状态**：远期可选（主路径已改为 A：分层插槽，见 `pet-layered-avatar.md`）  
> **范围**：仅养成域小家 / 换衣间，**不**改 Companion 决策 13（Companion 仍不做 Live2D）

## 1. 选型结论

| 选项 | 结论 |
|------|------|
| **Spine + `flame_spine`** | **主选**：官方 Flame 桥接，换装用 Skin / Slot 附件，遮挡由骨骼深度解决 |
| Live2D | 不做：Companion 已否决形象大厅；Flame 生态弱于 Spine |
| Rive（仓库已有 `rive`） | **备选**：无 Spine 编辑器授权时可走；换装模型与 Spine 不同，需单独美术规范 |

**许可证**：`flame_spine` / `spine_flutter` 受 [Spine Runtime License](https://esotericsoftware.com/spine-runtimes-license) 约束，需有效 **Spine Editor** 授权后再上生产依赖。

## 2. 目标体验

- 衣服「穿在身上」：领口/袖子/帽子相对头、臂有正确前后遮挡  
- 换装切换 Skin 或 Slot attachment，而不是整图贴纸叠在 `model.png` 上  
- 喂食/idle/walk 等少量动画由 Spine 动画轨驱动  
- 无 Spine 资源或 Flag 关闭时，**完整回退**现有 PNG + `wear_layout` 路径

## 3. 资源约定

```
assets/pet/spine/
  moe_pet.atlas          # 图集
  moe_pet.skel 或 .json  # 骨骼（与 spine_flutter 大版本一致，当前目标 4.3.x）
  skins/                 # 可选：分皮肤导出说明
```

### 皮肤 / 槽位命名（美术 SSOT）

| Slot（示例） | Skin 附件 | 对应产品槽 |
|--------------|-----------|------------|
| `hat` | `hat_cap`, `hat_beret`, … | `hat_id` |
| `top` | `top_basic`, `top_coat`, … | `top_id` |
| `bottom` | `bottom_basic`, … | `bottom_id` |
| `shoes` | `shoes_basic`, … | `shoes_id` |

- 空帽：`hat` slot 设为空附件或 `hat_none`  
- **禁止**再为上衣导出「盖住整头的一张 PNG」当唯一附件；前后片由 Spine 绑定完成  
- 导出：Binary `.skel` + `.atlas` + `.png`；Editor 主版本对齐 `spine_flutter`（见 pub）

## 4. 工程分期

| 期 | 内容 | 验收 |
|----|------|------|
| **C0** | Flag + 文档 + 资源目录；运行时仍 PNG | 无回归 |
| **C1** | 接入 `flame_spine`；小家角色可播 idle（固定 Skin） | 有授权 + 样例骨骼可跑 |
| **C2** | `hat/top/bottom/shoes` ↔ Skin/Slot；服务端 ID 不变 | 换装遮挡正确 |
| **C3** | 换衣间改为预览 Spine（或烘焙预览）；废弃贴纸拖放为主路径 | 预览=舞台 |
| **C4** | 照料/走动动画；PNG 仅作缺省回退 | 动画闭环 |

后端契约：**暂不改** `hat_id` / `top_id` / …；`outfit_json` 在 Spine 模式下可忽略位移，或仅存非骨骼附件微调。

## 5. 依赖接入（C1，有授权后再执行）

```bash
cd <repo>
flutter pub add flame_spine
# 会拉取匹配的 spine_flutter；确认与 Spine Editor 4.3.x 一致
```

`main` / Pet 入口：

```dart
await initSpineFlutter();
```

小家：`SpineComponent.fromAssets(...)`，换装：

```dart
skeleton.setSkinByName(skinName);
skeleton.setSlotsToSetupPose();
```

（具体 API 以所用 `flame_spine` 版本文档为准。）

## 6. Flag

- `FeatureFlags.petSpineAvatar`：默认 `false`  
- `true` 且资源存在 → Spine 路径  
- 否则 → PNG `_PetActor`（现网）

## 7. 明确不做

- Companion 聊天页嵌 Live2D / Spine（决策 13）  
- 无授权时把 Spine Runtime 打进生产包  
- 同时维护三套主形象（PNG 贴纸微调 + Spine + Live2D）——贴纸仅回退

## 8. 回滚

`petSpineAvatar = false` 或删除 `assets/pet/spine/*` → 自动 PNG。

## 9. 下一步（人工）

1. 确认 Spine Editor 授权与版本（4.3.x）  
2. 导出最小 `moe_pet`（idle + 1 套衣帽）到 `assets/pet/spine/`  
3. 开 C1：加依赖 + `_PetSpineActor` 替换小家绘制
