# 萌农场素材生成提示词（Asset Prompts）

> 配套「QQ 农场玩法」模块：`lib/game/farm/` + `lib/pages/pet/farm_page.dart`
> 素材目录：`assets/farm/`，代码引用路径定义在 `lib/models/farm_crop_config.dart` 的 `FarmArt` / `FarmCropConfig.assetOf`。
>
> 所有图片需本地处理成 **透明底 PNG** 后，按下表文件名放入对应目录。
> 缺失素材时代码有程序化回落渲染（不影响运行），补齐后自动生效。

## 统一风格基准

所有 prompt 均包含以下风格关键词，保证全套素材风格一致：

```
kawaii cute cartoon style, soft pastel colors, thick soft outlines,
centered single object, plain white background, mobile farm game sprite
```

- 风格：卡通萌系（kawaii），柔和马卡龙色系，粗软描边
- 构图：单个物体居中，白色纯色背景（方便抠图）
- 尺寸建议：1024×1024，导出后缩到 256×256 左右即可（tile 尺寸 128 逻辑像素）

---

## 一、作物素材（15 张）→ `assets/farm/crops/`

命名规则：`{作物id}_{阶段}.png`，阶段 = `seed` / `sprout` / `ripe`。
作物 id：`radish` / `carrot` / `cabbage` / `sunflower` / `strawberry`。

### ✅ 全部已生成（15 张）

| 作物 | seed | sprout | ripe |
|------|------|--------|------|
| radish | ✅ | ✅ | ✅ |
| carrot | ✅ | ✅ | ✅ |
| cabbage | ✅ | ✅ | ✅ |
| sunflower | ✅ | ✅ | ✅ |
| strawberry | ✅ | ✅ | ✅ |

如需重新生成某张，使用下方对应提示词：

#### cabbage_ripe.png

```
Cute cartoon game sprite of a fully ripe cabbage: big round plump layered green cabbage head sitting on soil with outer leaves, small sparkles around it, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### sunflower_seed.png

```
Cute cartoon game sprite of a small seed sprout mound in soil: tiny striped sunflower seed with two small green leaves just emerging from dark soil, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### sunflower_sprout.png

```
Cute cartoon game sprite of a young sunflower plant: tall green stem with pairs of leaves and a small closed green bud at top growing from soil, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### sunflower_ripe.png

```
Cute cartoon game sprite of a fully bloomed sunflower: big bright yellow sunflower with brown center on tall green stem with leaves, cute smiley face on flower, small sparkles around it, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### strawberry_seed.png

```
Cute cartoon game sprite of a small seed sprout mound in soil: tiny brown seed with two small green leaves just emerging from dark soil, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### strawberry_sprout.png

```
Cute cartoon game sprite of a young strawberry plant: low bushy green strawberry plant with small white flowers and tiny green unripe berries growing from soil, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

#### strawberry_ripe.png

```
Cute cartoon game sprite of a ripe strawberry plant: low green bush with several big glossy red strawberries with tiny seeds, small sparkles around them, kawaii style, soft pastel colors, thick soft outlines, centered single object, plain white background, mobile farm game asset
```

---

## 二、地块素材（3 张）→ `assets/farm/tiles/` ✅ 已全部生成

| 文件名 | 用途 | 状态 |
|--------|------|------|
| `soil_dry.png` | 干土地块（默认） | ✅ |
| `soil_wet.png` | 浇水后的湿润地块 | ✅ |
| `grass_tile.png` | 农田外围草地 | ✅ |

如需重新生成，使用下方对应提示词：

#### soil_dry.png

```
Cute cartoon game tile sprite of dry farm soil: square patch of warm brown tilled soil with subtle furrow lines, soft rounded corners, kawaii style, soft pastel colors, top-down view, plain white background, mobile farm game tile asset
```

#### soil_wet.png

```
Cute cartoon game tile sprite of wet farm soil: square patch of dark moist brown tilled soil with subtle furrow lines and tiny water shine spots, soft rounded corners, kawaii style, top-down view, plain white background, mobile farm game tile asset
```

#### grass_tile.png

```
Cute cartoon game tile sprite of grass ground: square patch of soft light green grass with tiny grass blade details and small flowers, kawaii style, soft pastel colors, top-down view, plain white background, mobile farm game tile asset
```

---

## 三、UI 素材（2 张）→ `assets/farm/ui/` ✅ 已全部生成

| 文件名 | 用途 | 状态 |
|--------|------|------|
| `coin.png` | HUD 金币图标 | ✅ 已完成 |
| `seed_bag.png` | 种子背包/商店图标 | ✅ 已完成 |

如需重新生成，使用下方对应提示词：

#### coin.png

```
Cute cartoon game icon of a shiny gold coin: round golden coin with star emblem in center, glossy highlight, thick soft outlines, kawaii style, soft pastel colors, centered single object, plain white background, mobile game UI icon
```

#### seed_bag.png

```
Cute cartoon game icon of a small burlap seed bag: tied little brown cloth sack with some seeds spilling out, thick soft outlines, kawaii style, soft pastel colors, centered single object, plain white background, mobile game UI icon
```

---

## 四、可选素材

#### farm_bg.png → `assets/farm/tiles/`（农场背景，缺失时用纯色回落）

```
Cute cartoon farm background illustration: soft pastel green meadow with gentle hills, blue sky with fluffy white clouds, tiny distant barn and trees, kawaii style, dreamy soft colors, mobile game background, no characters
```

---

## 当前进度与收尾步骤

✅ 素材已全部生成（20/20）：作物 15 + 地块 3 + UI 2，均已放入对应目录。
✅ `pubspec.yaml` 已注册 `assets/farm/crops/`、`assets/farm/tiles/`、`assets/farm/ui/`。

剩余步骤：
1. 所有图片本地抠成透明底 PNG（背景素材 farm_bg 除外），覆盖同名文件即可自动生效
2. 运行验证素材加载（宠物房间 → 更多 → 萌农场）
