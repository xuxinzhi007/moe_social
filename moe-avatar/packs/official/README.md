# 官方包产出目录

将编辑器导出的官方包放在此目录，结构示例：

```text
official/
├── manifest.json
├── layers/
└── thumbs/
```

接入 App：

```text
复制到 moe-social/assets/pet/moe_content/avatar/
```

Flutter 的 `PetMoeAvatarComposer` 已读取 `assets/pet/moe_content/avatar/manifest.json`；`assets/pet/lpc/` 仅保留为短跑原型回退。
