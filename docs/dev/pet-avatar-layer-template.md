# Pet Avatar · 分层 Sheet 生产模板（SSOT）

> **日期**：2026-08-01  
> **状态**：模板 v1 冻结 · admin 校验/预览对齐中  
> **配置**：`assets/pet/config/avatar_layer_template.json`  
> **关系**：[moe-avatar/spec/image-authoring.md](../../moe-avatar/spec/image-authoring.md) · [pet-layered-avatar.md](./pet-layered-avatar.md)

---

## 1. 问题（为什么「只有一个预览」不够）

| 现状 | 问题 |
|------|------|
| 单帧缩略图 + 智能裁剪 | 看不出 9×4 / 2×4 **每一格**是否对齐 |
| LPC 底模 `body_*.png` | 是 **ULPC 像素人**，不是官方软 Q |
| 误传整图 / 非衣服图 | 尺寸匹配仍会通过，叠层穿模 |
| 无分槽绘制区 | 美术不知道 **上衣只能画哪块** |

**结论**：必须先冻结 **模板规则**（格线 + 锚点 + 每槽 paintRect），再谈 Fooocus / 后端 / 批量生成。否则永远是半成品。

---

## 2. 模板定义什么

```text
avatar_layer_template.json
├── cellSize / animations     → walk 9×4 · idle 2×4 · 方向行序
├── anchors                   → origin · headCenter · torsoCenter（cell 内坐标）
├── layerRules.{key}          → 每 base/槽位 allowed paintRect（相对 cell 0~1）
├── baseStyle                 → 官方 mannequin 路径 · 禁止 LPC 底
└── pipeline                  → 谁负责校验 / 生成 / 发布
```

### 2.1 每层 sheet 是什么

- **不是**整身一张图，而是 **同格线上一张透明 PNG**。
- 每个 **64×64 格** 内，该层 **只允许在 paintRect 内出现不透明像素**（导出校验）。
- 预览必须像 `top_hoodie` 展开那样：**整 sheet + 格线 + 允许区 overlay**。

### 2.0 单图绑定（推荐）

单张 PNG → admin 绑定官方底模 → 自动生成 walk/idle 格线关键帧。完整 sheet 上传为高级路径。

### 2.2 与锚点模型（A 方案）关系

| 模式 | 用途 |
|------|------|
| **Sheet 模板（本文）** | walk/idle 动画 · admin 生产 · 格线对齐 |
| **avatar_stack.json** | 单 pose 锚点穿搭 · 官方 head/torso/legs |

正式路线：**官方软 Q 在模板上重绘 sheet** → 或 Spine。LPC 仅过渡，不得标为正式包。

---

## 3. 能力分工（Go / Py / Fooocus / Admin）

| 环节 | 负责 | 说明 |
|------|------|------|
| **模板 SSOT** | JSON + 本文 | 先定死，不并行 |
| **校验 / 预览** | moe-admin | 格线 overlay · paintRect 告警 · 全格预览 |
| **批量对齐** | Python 本地脚本 | 单图 → 套模板 · 切 walk/idle（可选） |
| **AI 出图** | Fooocus 本地 | 出 **软 Q 单部件** → 再进 admin 对齐模板；**不**直接进 App |
| **发布 / 版本** | Go 后端 P4 | 存 pack · hash · 回滚；**不做**像素合成 |

> Fooocus 路径示例：`D:\xuxinzhi\Fooocus_win64_2-5-0` — 接在模板冻结 **之后**，用于生成 `top_xxx` 等部件 **参考图**，仍需 admin 校验导出。

---

## 4. 正式 vs 过渡 pack

| 项 | 过渡（现在） | 正式（目标） |
|----|--------------|--------------|
| 底模 | LPC 64px base | `assets/pet/character/` 软 Q · 或 128 格重绘 |
| cellSize | 64 | 128（见 moe-avatar-spec-v1） |
| packId | `moe-official-prototype-v1` | `moe-official-chibi-v1` |
| App flag | `petMoeAvatar=true` | 正式 manifest 就绪后切换 |

**当前 base 层仍是 LPC 导入** — 换衣预览才会是像素红发男。要官方模型：换 base sheet 或 `petMoeAvatar=false` 走锚点 stack。

---

## 5. 生产 checklist（导出前）

- [ ] walk 576×256 · idle 128×256 · RGBA 透明底
- [ ] 每层 idle·down·帧0 锚点偏差 ≤ 2px
- [ ] 槽位层 opaque 像素 **落在 paintRect 内**（admin 校验）
- [ ] 每单品独立路径（不共用 `top_basic_*`）
- [ ] 缩略图 = idle·down·帧0 单层裁格
- [ ] 非 LPC 底模（正式包）

---

## 6. 相关文件

| 文件 | 职责 |
|------|------|
| `assets/pet/config/avatar_layer_template.json` | 模板 SSOT |
| `moe-admin/.../layerTemplate.ts` | 读取规则 · 模板下载 overlay |
| `moe-admin/.../SheetGridPreview.tsx` | 整 sheet + 格线 + 允许区 |
| `scripts/pet/align_layer_to_template.py` | 本地批量对齐（占位） |

---

## 7. 下一步

1. admin 生产区 **默认整 sheet 格线预览**（与 hoodie 展开一致）  
2. 上传后 **paintRect 校验**（超出允许区 → 警告）  
3. 按槽下载 **带 overlay 的格线模板**  
4. 用官方 character 重绘 base 层，替换 LPC 底模  
5. P4 再接 Go 发布；Fooocus 仅作可选输入源  
