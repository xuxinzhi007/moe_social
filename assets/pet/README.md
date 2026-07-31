# Pet Life Sim 美术资源

规范：竖屏概念；PNG 透明分层；统一 Q 版；运行时路径用**英文蛇形**。

## 源素材 → 运行时映射

你补齐的源目录：`assets/avatars/flutter角色图/`（中文文件名，保留不动）。

已同步到养成运行时目录（Room / Adventure 读取这里）：

| 源文件（放 `assets/pet/` 根目录即可） | 运行时路径 |
|--------|------------|
| `body.png` / `角色模型.png` | `character/body.png`（当前用角色模型）+ `character/model.png` |
| `baby_head.png` | `character/baby_head.png` |
| 耳朵.png | `character/ear.png` |
| 衣服.png | `clothes/top_basic.png` |
| 裤子.png | `clothes/bottom_basic.png` |
| 鞋子.png | `clothes/shoes_basic.png` |
| 帽子.png | `clothes/hat_cap.png` |
| 床.png | `furniture/bed_basic.png` |
| 桌子.png | `furniture/table_wood.png` |
| 台灯.png | `furniture/lamp_basic.png` |
| 地毯.png | `furniture/rug_basic.png` |
| 窗户.png | `furniture/window_lace.png` |
| 货币.png | `ui/coin.png` |
| 怪物头.png | `adventure/monster_head.png` |
| 客厅.png | `room/living_bg.png` |

实测：分层图 **1600×2848**，四角 **A=0**（真透明）；客厅底图 1535×2732。

## 场景底图

| 路径 | 状态 |
|------|------|
| `room/living_bg.png` | 已接入（由 `客厅.png` 移入，约 1535×2732） |
| `room/yard_bg.png` | 仍缺（1×1 占位 → Canvas） |
| `room/bedroom_bg.png` | 仍缺（1×1 占位 → Canvas） |

## 仍缺（P0）

| 路径 | 说明 |
|------|------|
| 服装变体 ×6 | 现仅各 1 套基础款；装扮面板其它 ID 回落 `*_basic` / `hat_cap` |
| `head` / `face` 独立层 | 现合并在 `body` + `ear` |

## 缺图策略

`PetArt.loadImage`：失败或 1×1 占位 → Flame 用 Canvas 几何回退，不阻断试玩。

换图：覆盖 `assets/pet/...` 同名文件即可；若只更新中文源目录，需再同步拷贝一次。

## 透明通道注意

角色/家具分层图须为 **真透明 PNG（Alpha）**。若导出时带棋盘格或白底（A=255），叠在客厅上会盖成大方块。请用去底后的分层图覆盖 `character/`、`clothes/`、`furniture/`。
