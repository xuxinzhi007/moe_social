# QQ 农场玩法实现方案

## 决策总览

| 决策项 | 结论 |
|--------|------|
| 页面形态 | 独立全屏页面，从宠物房间按钮跳转 |
| 网格系统 | 6×8 / 128×128 tile / (col,row) 逻辑坐标 / Camera 拖拽缩放 |
| 交互模式 | 点击即触发 + 长按详情 + 种子选择面板 |
| 生长时间 | 分档：小萝卜 1.5min → 草莓 2h |
| 爽感机制 | Combo + 一键全收 + 生长可视化 + 稀有变异 + 加速道具 + 收获弹跳 + 每日首收 |
| 经济系统 | 共用宠物 coins，种子买卖循环 |
| 持久化 | v1 本地 JSON，预留后端扩展 |
| 代码架构 | `lib/game/farm/` 独立模块 |
| 素材 | 卡通萌系 PNG，AI 生成 + 本地处理透明底 |

## 实施阶段

### Phase 1: 数据模型与配置
- `lib/models/farm_crop_config.dart` — 作物配置表（5种作物、生长时间、价格、素材路径）
- `lib/models/farm_state.dart` — 农场状态（格子、种子背包、道具、combo 计数）

### Phase 2: 业务 Provider
- `lib/providers/farm_provider.dart` — 农场状态管理（种植/浇水/收获/商店/持久化）

### Phase 3: Flame 游戏层
- `lib/game/farm/farm_game.dart` — FlameGame 主类（世界/相机/输入）
- `lib/game/farm/farm_tile_grid.dart` — 网格渲染 + tile 坐标系统
- `lib/game/farm/farm_crop_sprite.dart` — 作物组件（生长动画/状态渲染）
- `lib/game/farm/farm_effects.dart` — 爽感特效（Combo/变异/弹跳/粒子）
- `lib/game/farm/farm_hud.dart` — 游戏内 HUD

### Phase 4: 页面与路由
- `lib/pages/pet/farm_page.dart` — 全屏农场页面
- 宠物房间增加"进入农场"按钮入口

### Phase 5: 素材生成
- 5 种作物 × 3 阶段 = 15 张作物图
- 土地状态 × 3 张
- 背景/UI 素材

### Phase 6: 注册资源与验证
- `pubspec.yaml` 注册 `assets/farm/` 路径
- `flutter analyze` 编译验证

## 作物经济表

| 作物 | 种子价格 | 收获金币 | 净利润 | 生长总时间 |
|------|---------|---------|--------|-----------|
| 小萝卜 | 5 | 12 | +7 | ~1.5min |
| 胡萝卜 | 10 | 25 | +15 | ~7min |
| 卷心菜 | 20 | 50 | +30 | ~20min |
| 向日葵 | 50 | 130 | +80 | ~1h |
| 草莓 | 100 | 280 | +180 | ~2h |

## 文件结构

```
lib/
├── game/farm/
│   ├── farm_game.dart
│   ├── farm_tile_grid.dart
│   ├── farm_crop_sprite.dart
│   ├── farm_effects.dart
│   └── farm_hud.dart
├── models/
│   ├── farm_state.dart
│   └── farm_crop_config.dart
├── providers/
│   └── farm_provider.dart
└── pages/pet/
    └── farm_page.dart
assets/
└── farm/
    ├── crops/       (作物素材)
    ├── tiles/       (地块素材)
    └── ui/          (UI素材)
```
