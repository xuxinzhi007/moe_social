# Moe Avatar Spec v1

> **版本**：1.0-draft · 2026-08-01  
> **状态**：草案 · 消费端仍用 LPC 短跑验证，本 Spec 为正式官方包目标形态

## 1. 设计目标

1. **一套模板** — 所有官方 / 后续社区包共用同一网格与槽位，App 只写一次合成器。
2. **软 Q 版画风** — 与 `assets/pet/character/` 现有分层一致；**不**强制 LPC 像素硬边。
3. **可导入自定义图** — 用户 / 美术在编辑器里导入 PNG，**对齐人偶模板** 后导出，而非随意贴纸。
4. **协议自有** — 不依赖 ULPC 素材与 CC-BY-SA 链。

## 2. 画布与格（Sheet Grid）

### 2.1 逻辑格（与 LPC 同工作流，分辨率可升级）

| 字段 | v1 默认值 | 说明 |
|------|-----------|------|
| `cellSize` | **128** | 每帧宽高（像素）；LPC 原型用 64，正式 Moe 建议 128 以容纳软边 Q 版 |
| `directions` | 4 | 行序固定：**up → left → down → right**（与 LPC 一致，便于迁移） |
| `animations.walk` | 9 列 × 4 行 | 576×512 总画布（128 格） |
| `animations.idle` | 2 列 × 4 行 | 256×512 |
| `colorMode` | RGBA | 透明底；禁止预乘错误黑底 |

> v1 **仅强制** walk + idle；run / hurt 等列为 v2 扩展，manifest 里用 `animations` 声明即可。

### 2.2 锚点（整 sheet 共用）

所有层、所有单品在 **同一 cell 坐标系** 内绘制：

| 锚点 | 位置（相对 cell） | 用途 |
|------|-------------------|------|
| `origin` | 脚底中心 ≈ (64, 124) @ cell 128 | 对齐地面、小家 wander |
| `headCenter` | ≈ (64, 36) | 帽/发/脸对齐 |
| `torsoCenter` | ≈ (64, 72) | 上衣对齐 |

编辑器导出时校验：每层 **down 方向 idle 第 0 帧** 的 `origin` 偏差 ≤ 2px（可配置）。

## 3. 槽位与 z 序

与商品 id 域对齐（`hat_id` / `top_id` / …）：

```text
z 小 ──────────────────────────────► z 大

body → bottom → top → shoes → head → face → hat → hair
```

| 槽位 | manifest 键 | 可空 | 说明 |
|------|-------------|------|------|
| 身体底 | `base.body` | 否 | 肤色躯干，无脸 |
| 裤/裙 | `slots.bottom.{id}` | 是 | 空 id = 不穿 |
| 上衣 | `slots.top.{id}` | 是 | |
| 鞋 | `slots.shoes.{id}` | 是 | |
| 头型 | `base.head` | 否 | 脸型轮廓 |
| 表情 | `base.face` | 否 | 眼嘴 |
| 帽 | `slots.hat.{id}` | 是 | |
| 发型 | `base.hair` 或 `slots.hair.{id}` | 否/可扩展 | v1 发型放 base |

## 4. 资源文件命名

```text
packs/official/
├── manifest.json
├── layers/
│   ├── base/
│   │   ├── body_walk.png
│   │   ├── body_idle.png
│   │   └── …
│   └── slots/
│       ├── top_basic_walk.png
│       └── top_basic_idle.png
└── thumbs/
    ├── top_basic.png          # 换衣间列表：仅该部件（idle · down · 帧0）
    └── …
```

## 5. manifest.json（概要）

完整示例见 [../schema/manifest-v1.example.json](../schema/manifest-v1.example.json)。

| 顶字段 | 含义 |
|--------|------|
| `specVersion` | `"1"` |
| `packId` | 如 `moe-official-chibi-v1` |
| `cellSize` | 128 |
| `base` | 不可替换或默认替换的底模层 |
| `slots` | 商品 id → `{ walk, idle, thumb? }` |
| `composeOrder` | z 序字符串数组 |

## 6. 与 LPC 短跑差异

| 项 | LPC 短跑（现状） | Moe Avatar v1 |
|----|------------------|---------------|
| 格大小 | 64 | **128（推荐）** |
| 画风 | ULPC 像素 | **软 Q 版** |
| 配置 | `lpc_catalog.json` | `manifest.json` |
| 缩略图 | 运行时整身合成 | **manifest.thumbs 或单层裁格** |
| 协议 | CC-BY 等 | **自有** |

## 7. 消费端（moe-social）

| 阶段 | 行为 |
|------|------|
| 现在 | `FeatureFlags.petLpcPrototype` + `lpc_catalog.json` |
| 迁移 | 读 `assets/pet/moe_content/avatar/manifest.json`，composer 按本 Spec 叠层 |
| 回滚 | Flag 关 → PNG A 方案（`avatar_stack.json`） |
