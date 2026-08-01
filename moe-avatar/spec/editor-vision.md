# Moe Avatar Editor — 产品愿景与 ULPC 对照

> **ULPC clone**：`C:\Users\ZhuanZ1\Desktop\Universal-LPC-Spritesheet-Character-Generator`  
> **目标**：类似 LPC 的 **选层 → 预览 → 导出**，但更贴合 Moe 养成：**软 Q 版 · 商品 id · 一键官方包 · 导入自定义图并对齐模板**

## 1. 你的理解（确认）

| 点 | 结论 |
|----|------|
| 我们做 **一种编辑器** | 是，独立 Web 工具（远期独立仓库，现 SSOT 在 `moe-avatar/`） |
| 和 LPC **类似但不完全一样** | 是：同 **分层 + 动画格 + z 序** 工作流；不同 **画风、manifest、导出目标、商品域** |
| **更丰富** | 是：对准 Moe 槽位/id、缩略图、锚点校验、官方包 zip、可选预烘焙 |
| **编辑器里调完直接导出就能用** | 是：导出 = `manifest.json` + `layers/` + `thumbs/` → 拷贝进 App，无需再跑 ULPC 脚本 |

**不必是像素风**；必须是 **Moe Avatar Spec v1** 的格与锚点（见 [moe-avatar-spec-v1.md](moe-avatar-spec-v1.md)）。

---

## 2. ULPC 仓库架构（已读）

技术栈：**Vite 8 · Mithril · TypeScript · Canvas 2D · JSZip**

```text
sources/
├── main.ts                    # 入口
├── install-item-metadata.ts   # 并行加载 5 份生成 metadata
├── state/
│   ├── catalog.ts             # 部件 catalog（item / layer / palette / credits）
│   ├── constants.ts           # FRAME_SIZE=64, ANIMATION_CONFIGS, DIRECTIONS
│   ├── zip.ts                 # ZIP 导出（按动画 / 按 item / 按帧）
│   └── json.ts                # character.json 序列化（层清单 + hash）
├── canvas/
│   ├── renderer.ts            # 核心：z 序 drawCalls → 叠层绘制
│   ├── download.ts            # 整 sheet PNG 下载
│   └── palette-recolor.ts     # 调色板换色
└── components/
    ├── tree/CategoryTree.ts   # 左侧分类选部件
    ├── preview/AnimationPreview.ts
    ├── download/Download.ts   # 导出按钮区
    └── advanced/AdvancedTools.ts  # 自定义 PNG 上传（仅 overlay + 手填 z）
```

构建时生成（非手改）：

- `index-metadata.js` — 分类树、索引  
- `item-metadata.js` — 数千 LPC 部件 lite 元数据  
- `layers-metadata.js` — 每 item 的 layerNum、zPos、动画支持  
- `credits-metadata.js` — CC 署名链  
- `spritesheets/**` — 巨量 PNG 素材  

### ULPC 导出能力（Download 面板）

| 按钮 | 产出 |
|------|------|
| Spritesheet (PNG) | 整张合成 sheet |
| ZIP: Split by animation | 按 walk/idle/… 分子目录 PNG |
| ZIP: Split by item | **每层 item 单独 PNG**（接近我们要的 layer 导出） |
| ZIP: Split by animation and item | 更细 |
| character.json + credits | 层 manifest + **必须署名** |

核心合成逻辑：`renderer.ts` 的 `runRenderCharacter` → `drawCalls[]` → Canvas 按 `zPos` 绘制。

---

## 3. ULPC 的短板（相对 Moe 需求）

| ULPC 有 | Moe 需要 | 差距 |
|---------|----------|------|
| 64px 像素 + 全动画 | 128 软 Q + v1 仅 walk/idle | Spec 不同 |
| 部件 id = LPC 内部 itemId | `top_hoodie` 等 **商品 id** | 需映射层 |
| 导出 ZIP + credits | **官方包 manifest + thumbs** | 需定制导出器 |
| AdvancedTools 上传整图 + 手填 z | **导入对齐人偶模板 + 槽位校验** | ULPC 几乎没做 |
| 面向 RPG 全品类 | 帽/衣/裤/鞋 + 官方画风 | UI 要收窄 |
| CC 协议链 | 自有协议 | 不继承 credits |

所以：**借 ULPC 的 renderer / zip / 预览思路，不 fork 整仓。**

---

## 4. Moe Avatar Editor — 比 LPC 「多」什么

```text
┌─────────────────────────────────────────────────────────┐
│  Moe Avatar Editor                                      │
├──────────────┬──────────────────────────────────────────┤
│ 槽位面板      │  动画预览（walk / idle · 4 方向）          │
│ 帽/衣/裤/鞋   │  + 人偶锚点 overlay（origin / head）      │
│ + base 发型   │                                          │
├──────────────┴──────────────────────────────────────────┤
│ 导入：PNG → 对齐模板 → 归属槽位 + itemId                  │
│ 校验：格尺寸 / 透明 / 锚点偏差 / 叠层穿模                 │
├─────────────────────────────────────────────────────────┤
│ 导出官方包（一键）：                                       │
│   manifest.json                                         │
│   layers/**_{walk,idle}.png                             │
│   thumbs/{item_id}.png   ← 换衣间列表只用部件              │
│   [可选] baked/hero_{walk,idle}.png  ← App 免 runtime 合成│
└─────────────────────────────────────────────────────────┘
         │
         ▼  「拷贝到 moe-social」或 CI
  assets/pet/moe_avatar/
```

| 能力 | ULPC | Moe Editor |
|------|------|------------|
| 分类树选 thousands 部件 | ✓ | ✗（官方包 curated 列表） |
| 实时 Canvas 预览 | ✓ | ✓ |
| 按 item 导出 layer PNG | ✓（ZIP split by item） | ✓（且命名对齐 manifest） |
| 商品 id / admin 域 | ✗ | ✓ |
| 部件缩略图 auto | ✗ | ✓ |
| 导入自定义图 + 模板对齐 | 弱（AdvancedTools） | ✓ **核心** |
| 导出即可被 Flutter 读 | 需再转换 | ✓ |
| 预烘焙整身 sheet | 可下 PNG | ✓ 可选 |
| Credits / CC | ✓ | ✗（官方自有图） |

---

## 5. 建议借用的 ULPC 模块（实现 Editor 时）

| 文件 | 借鉴内容 |
|------|----------|
| `sources/canvas/renderer.ts` | drawCalls、z 序、按动画 yPos 切 sheet |
| `sources/state/constants.ts` | DIRECTIONS 行序、ANIMATION_CONFIGS 帧循环（v1 只留 walk+idle） |
| `sources/state/zip.ts` | `exportSplitItemSheets`、`renderSingleItem` |
| `sources/canvas/canvas-utils.ts` | canvas → blob |
| `sources/components/preview/AnimationPreview.ts` | 预览循环播放 |

| 不搬 | 原因 |
|------|------|
| 整个 `spritesheets/` + item-metadata | 体积 + 协议 |
| credits / license 过滤器 | Moe 官方包不需要 |
| palette-recolor（v1） | 可 v2 再加 |
| Bulma 全站 UI | 换 Moe admin 风或简洁 React |

---

## 6. Editor MVP 功能清单（建议排期）

### P0 — 能替换现在手工脚本

- [x] 加载 **Moe 官方底模**（base body/head/face/hair）— `public/pet/moe_avatar/`
- [x] 四槽选择 + **Canvas** 预览 walk/idle（idle 循环）
- [x] 导出 **官方包 zip**（manifest + layers + thumbs + baked）
- [x] 管理台页面 `/biz/pet/avatar`（双 Tab：编辑 | manifest）
- [ ] 解压说明一键复制到 Flutter `assets/pet/moe_avatar/`（composer 未接）

### P1 — 比 ULPC 好用

- [ ] 导入 PNG：**snap 锚点**、缩放进 cell
- [ ] 导出前 **校验报告**（尺寸/透明/锚点）
- [ ] 绑定 **商品 id**（`top_hoodie`）与 manifest 字段
- [ ] 可选 **预烘焙** hero_walk / hero_idle

### P2 — 丰富

- [ ] 多 base（女/童）
- [ ] 更多动画 run / emote
- [ ] 与 moe-admin 联调上传 pack 版本
- [ ] 社区包校验（同 spec，签名）

---

## 7. 仓库策略

| 方案 | 建议 |
|------|------|
| **放进 moe-admin（推荐 MVP）** | 运营/美术已登录管理台；Vite+React 现成；与 catalog 同页；导出 zip 纯前端即可 |
| `moe-avatar/`（moe-social 内） | Spec + schema + 官方包目录 SSOT；**不含**完整 UI |
| 独立 `moe-avatar-editor` 开源仓 | 等编辑器稳定、要对外开源时再拆；core 可从 admin 抽 `packages/composer` |

### 7.1 为何 admin 优先

- 已有入口：`/biz/pet/lpc` → 可演进为 **养成 · 角色装扮编辑器**
- 编辑器是 **内部生产力工具**，不是 App 用户功能 → 符合管理台定位
- 不必 fork ULPC 整站；只把 `renderer` / zip 思路 **移植到 React + Canvas**
- 导出：浏览器 **下载官方包 zip**（与现「下载 catalog」一致）；后端上传 OSS 可二期

### 7.2 admin 内建议目录

```text
moe-admin/src/features/moe-avatar/
├── composer/          # 叠层（从 ULPC renderer 移植，128 格 walk/idle）
├── components/        # 预览 Canvas、槽位面板、导入对话框
├── export/            # manifest + layers + thumbs → JSZip
└── types/             # 对齐 moe-avatar/schema/manifest-v1
public/pet/moe_avatar/ # 开发用底模 layer（与 Flutter assets 同步）
```

**不要**：iframe 嵌 `localhost:5173` ULPC；**不要**把 ULPC 的 `spritesheets/` 打进 admin 包。
