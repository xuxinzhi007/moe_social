# Pet LPC 流水线

> **日期**：2026-08-01  
> **状态**：短跑 1 可玩 · 短跑 2 规划  
> **Flag**：`FeatureFlags.petLpcPrototype`  
> **定位**：个人非商用；LPC **就是**同画布角色模板（64×64 网格 + z 层）  
> **正式方案 SSOT**：[`moe-avatar/`](../../moe-avatar/README.md)（软 Q 版 · 128 格 · 自有 manifest · 非像素强制）

## 1. 脸不见了？（常见坑）

合成 sheet 时若**漏掉**以下层，会出现「只有头发、身体无脸」：

| 层 | 路径示例 |
|----|----------|
| 头型 | `head/heads/human/male/walk.png` |
| 表情 | `head/faces/male/neutral/walk.png` |

修复：运行 `scripts/pet/compose_lpc_hero.ps1`（已含上述层），或 Generator 导出完整 sheet 后覆盖 `assets/pet/lpc/hero_*.png`。

## 2. 短跑 1（已实现）

- 小家：LPC sheet + **自主闲逛** + **拖拽打断**
- 换衣间（LPC 模式）：预览当前 sheet + 跳转在线生成器（衣柜暂为占位，改装在 Generator）
- 资源：`hero_walk.png`（576×256）、`hero_idle.png`（128×256）

## 3. 在线 vs 本地 vs 管理台

| 方式 | 适合 | 做法 |
|------|------|------|
| **在线生成器**（推荐日常） | 个人改装扮、试效果 | 打开 [LPC Generator](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/) → 选部件 → Export PNG → 裁/切 walk+idle → 覆盖 `assets/pet/lpc/` |
| **本地 Generator** | 离线、改 `sheet_definitions`、加新部件 | 见 §4 |
| **管理台配置**（短跑 3，未做） | 运营上传官方模板、多 preset | `moe-admin` 页：上传 sheet / 填 preset URL → 后端存 OSS → App 拉配置；**不要**在管理台内嵌整站 Generator（太重） |

**建议路径**：现在用 **在线 + 脚本落盘**；本地服务仅开发新部件时用；管理台等要「官方多套 preset」再上。

App **不内嵌** Generator 整站（WebView 太重、离线差）；换衣间提供 **外链 + 预览** 即可。竖切 2 再做 catalog 换层。

## 4. 本地 Generator 启动

仓库路径（示例）：

`C:\Users\ZhuanZ1\Downloads\Universal-LPC-Spritesheet-Character-Generator-master`

```powershell
cd C:\Users\ZhuanZ1\Downloads\Universal-LPC-Spritesheet-Character-Generator-master
npm install
npm run dev
# 浏览器 http://localhost:5173
# 或 npm run serve:open
```

导出后：

1. 保存 walk / idle 动画 PNG（或整 sheet 再切）  
2. 覆盖 `assets/pet/lpc/hero_walk.png`、`hero_idle.png`  
3. 或改 `assets/pet/config/lpc_prototype.json` 层列表 → 跑合成脚本：

```powershell
$env:LPC_ROOT = "C:\Users\ZhuanZ1\Downloads\Universal-LPC-Spritesheet-Character-Generator-master"
.\scripts\pet\compose_lpc_hero.ps1
```

## 5. 模型 = LPC 模板？

**是。** Universal LPC 的约定就是产品要的「官方角色编辑器模板」：

- 同画布 64×64，部件按 **z 序** 叠（见 Generator 内 `sheet_definitions`）  
- 新增衣服 = 按 LPC 规范画片 + 写 definition → Generator 可选 → 合成进 sheet  
- App 侧短跑只读 **合成后的 walk/idle**；竖切 2 再读 **层 catalog** 动态合成  

萌宠 PNG 分层（A 方案）可保留作 Flag 回滚；正式推进 LPC 时不删 A 代码。

## 6. 代码

| 模块 | 路径 |
|------|------|
| Flag | `FeatureFlags.petLpcPrototype` |
| Sheet | `lib/game/pet/pet_lpc_sheet.dart` |
| 小家闲逛 | `lib/game/pet/pet_room_game.dart` |
| 换衣间 LPC | `lib/pages/pet/pet_dressing_page.dart` |
| 层配置 | `assets/pet/config/lpc_prototype.json` |
| 合成脚本 | `scripts/pet/compose_lpc_hero.ps1` |

## 7. 短跑 2 / 3（规划）

- **2**：`catalog` 映射 帽/衣/裤/鞋 ↔ LPC 层；换衣间选单品 → 运行时合成 sheet  
- **3**：管理台上传 preset sheet + 默认 preset ID；App 启动拉取  

## 8. 许可

LPC 素材多 CC-BY / CC-BY-SA，需署名。个人非商用压力小；上架须审 Credits 与许可证。
