# 官方包生产与接入（管理台优先）

> **编辑器入口**：`moe-admin` → `/biz/pet/avatar`  
> **SSOT**：本目录 Spec · [docs/dev/moe-avatar-admin.md](../../docs/dev/moe-avatar-admin.md)

## 1. 目标态

```text
moe-admin 角色装扮编辑器
    │ 选槽 · Canvas 预览 · 导出 zip
    ▼
moe-avatar/packs/official/     （版本归档）
    │ 拷贝
    ▼
moe-social/assets/pet/moe_content/avatar/
    │ FeatureFlags.petMoeAvatar（规划）
    ▼
Flutter 换衣间 + 小家
```

## 2. 日常流程（当前 MVP）

1. `cd moe-admin && npm run dev`
2. 运营 → **角色装扮编辑器**
3. 调整装扮预览 → **导出官方包 zip**
4. 解压覆盖 `assets/pet/moe_content/avatar/`（与 `public/pet/moe_content/avatar/` 结构一致）
5. Flutter hot restart（composer 接入后）

## 3. 开发用资源同步

管理台 dev 资源在：

`moe-admin/public/pet/moe_content/avatar/layers/`

与 Flutter 原型层同步：

```powershell
Copy-Item assets\pet\moe_content\avatar\layers\*.png moe-admin\public\pet\moe_content\avatar\layers\  # 按命名规则
```

正式美术应在编辑器内维护，不再依赖 `export_lpc_layers.ps1`（LPC 短跑脚本仅过渡）。

## 4. 导出物结构

```text
{moe-official-prototype-v1}.zip
├── manifest.json
├── layers/base/*.png
├── layers/slots/*.png
├── thumbs/{item_id}.png
└── baked/hero_walk.png · hero_idle.png   （当前预览装扮）
```

## 5. 阶段

| 阶段 | 内容 |
|------|------|
| **MVP（当前）** | admin Canvas 编辑器 + zip 导出 |
| **P1** | 导入 PNG · 锚点校验 · 128 格正式包 |
| **P2** | admin API 上传 pack · App 远端拉 manifest |
| **P3** | 社区包同 spec 校验 |

## 6. 旧流程（LPC 短跑 ·  deprecated）

~~本地 ULPC `npm run dev` + `scripts/pet/export_lpc_layers.ps1` + 手改 `lpc_catalog.json`~~

仍可用于 Flutter `petLpcPrototype` 验证，**官方包以本编辑器为准**。
