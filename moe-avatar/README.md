# Moe Avatar — 官方角色模板与资源包

> **状态**：Spec v1 草案 · 编辑器独立仓库规划中  
> **消费端**：`moe-social` Flutter（`PetLpcComposer` → 将迁移为读本 manifest）  
> **参考实现**：`C:\Users\ZhuanZ1\Desktop\Universal-LPC-Spritesheet-Character-Generator`（只借鉴工作流，不绑素材与协议）

## 是什么

Moe Social 养成域的 **自研角色模板 + 官方资源包**，替代长期依赖 Universal LPC 素材/CC 协议。

| 概念 | 说明 |
|------|------|
| **Spec（模板）** | 画布格数、方向、动画、槽位、z 序、锚点 — 技术契约 |
| **官方包（Official Pack）** | 符合 Spec 的 `manifest.json` + 层 PNG + 缩略图 |
| **编辑器（远期独立仓）** | 选部件 / 导入自定义图 → 对齐模板 → 导出官方包 |

## 文档

| 文件 | 内容 |
|------|------|
| [spec/moe-avatar-spec-v1.md](spec/moe-avatar-spec-v1.md) | 模板契约 v1 |
| [spec/image-authoring.md](spec/image-authoring.md) | **图片怎么画 / 怎么导入才能套上模板** |
| [spec/editor-vision.md](spec/editor-vision.md) | **编辑器愿景 · 与 ULPC 对照 · MVP 清单** |
| [spec/workflow.md](spec/workflow.md) | 官方包生产与接入 moe-social |
| [reference/ulpc-mapping.md](reference/ulpc-mapping.md) | 与 ULPC 概念对照 |
| [reference/ulpc-repo-notes.md](reference/ulpc-repo-notes.md) | **本地 clone 阅读笔记（路径/导出/代码入口）** |
| [schema/manifest-v1.example.json](schema/manifest-v1.example.json) | manifest 示例 |

## 目录

```text
moe-avatar/
├── spec/           # SSOT 文档
├── schema/         # manifest 示例 / 未来 JSON Schema
├── packs/official/ # 官方包产出目录（zip 或拷贝到 assets）
└── reference/      # ULPC 等外部参考笔记
```

## 编辑器（moe-admin）

**入口**：`/ops/biz/pet/avatar`（旧 `/biz/pet/lpc` 已重定向）

实现：`moe-admin/src/features/moe-avatar/` · 文档 [spec/editor-vision.md](spec/editor-vision.md) · [docs/dev/moe-avatar-admin.md](../docs/dev/moe-avatar-admin.md)

## 与 moe-social 的关系

```text
moe-avatar/packs/official/  ──拷贝/CI──►  assets/pet/moe_avatar/
                                              lib/game/pet/（消费 manifest）
moe-admin                     ──维护 catalog / 上传包版本──►  同上
```

LPC 短跑（`assets/pet/lpc/`、`lpc_catalog.json`）视为 **Spec 验证原型**；正式画风走本目录定义的 **软 Q 版 + 更高分辨率格**。

## 风格说明（重要）

**不要求像素风。** Spec 约束的是 **网格、锚点、分层、动画帧布局**，不是 1:1 像素硬边。见 [image-authoring.md](spec/image-authoring.md)。
