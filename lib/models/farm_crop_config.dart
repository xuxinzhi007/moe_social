// QQ 农场：作物配置表与素材路径。
//
// 设计决策（grilling 确认）：
// - 分档生长时间：小萝卜 ~1.5min → 草莓 ~2h，越贵越赚但越慢。
// - 浇水每次缩短当前阶段剩余时间 30%，最多 2 次。
// - 共用宠物 coins，不引入独立货币。
// - 渲染全 PNG 素材，不用 emoji；缺图时回落程序化绘制。

/// 作物生长阶段。
enum FarmCropStage {
  empty,
  seed,
  sprout,
  ripe,
}

/// 稀有变异档位（收获瞬间掷骰决定）。
enum FarmMutation {
  none,
  golden,
  rainbow,
}

extension FarmMutationX on FarmMutation {
  /// 变异收获金币倍率。
  double get rewardMultiplier => switch (this) {
        FarmMutation.none => 1.0,
        FarmMutation.golden => 3.0,
        FarmMutation.rainbow => 5.0,
      };

  String get label => switch (this) {
        FarmMutation.none => '',
        FarmMutation.golden => '金色变异',
        FarmMutation.rainbow => '彩虹变异',
      };
}

/// 单一作物的静态配置（不可变 SSOT）。
class FarmCropConfig {
  const FarmCropConfig({
    required this.id,
    required this.label,
    required this.seedPrice,
    required this.harvestCoins,
    required this.seedSeconds,
    required this.sproutSeconds,
    required this.tint,
    required this.moodReward,
  });

  final String id;
  final String label;

  /// 种子买价（宠物 coins）。
  final int seedPrice;

  /// 收获基础金币（变异/combo 另乘倍率）。
  final int harvestCoins;

  /// seed→sprout 秒数。
  final double seedSeconds;

  /// sprout→ripe 秒数。
  final double sproutSeconds;

  /// 程序化回落绘制与 UI 点缀色（0xAARRGGBB）。
  final int tint;

  /// 收获心情奖励。
  final int moodReward;

  double get totalSeconds => seedSeconds + sproutSeconds;

  /// 阶段门槛（秒）：到达即晋升下一阶段。
  double stageThreshold(FarmCropStage stage) => switch (stage) {
        FarmCropStage.sprout => seedSeconds,
        FarmCropStage.ripe => totalSeconds,
        _ => 0,
      };

  /// 素材路径（`assets/farm/crops/<id>_<stage>.png`）。
  String assetOf(FarmCropStage stage) =>
      'assets/farm/crops/${id}_${stage.name}.png';

  static const radish = FarmCropConfig(
    id: 'radish',
    label: '小萝卜',
    seedPrice: 5,
    harvestCoins: 12,
    seedSeconds: 30,
    sproutSeconds: 60,
    tint: 0xFFFF8FA3,
    moodReward: 4,
  );

  static const carrot = FarmCropConfig(
    id: 'carrot',
    label: '胡萝卜',
    seedPrice: 10,
    harvestCoins: 25,
    seedSeconds: 120,
    sproutSeconds: 300,
    tint: 0xFFFFA94D,
    moodReward: 6,
  );

  static const cabbage = FarmCropConfig(
    id: 'cabbage',
    label: '卷心菜',
    seedPrice: 20,
    harvestCoins: 50,
    seedSeconds: 300,
    sproutSeconds: 900,
    tint: 0xFF7BC96F,
    moodReward: 8,
  );

  static const sunflower = FarmCropConfig(
    id: 'sunflower',
    label: '向日葵',
    seedPrice: 50,
    harvestCoins: 130,
    seedSeconds: 900,
    sproutSeconds: 2700,
    tint: 0xFFFFD43B,
    moodReward: 12,
  );

  static const strawberry = FarmCropConfig(
    id: 'strawberry',
    label: '草莓',
    seedPrice: 100,
    harvestCoins: 280,
    seedSeconds: 1800,
    sproutSeconds: 5400,
    tint: 0xFFFF6B81,
    moodReward: 18,
  );

  static const all = [radish, carrot, cabbage, sunflower, strawberry];

  static FarmCropConfig byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return radish;
  }
}

/// 加速道具。
class FarmItemConfig {
  const FarmItemConfig({
    required this.id,
    required this.label,
    required this.price,
    required this.description,
    required this.tint,
  });

  final String id;
  final String label;
  final int price;
  final String description;
  final int tint;

  /// 肥料：目标作物立即推进总时长的 30%。
  static const fertilizer = FarmItemConfig(
    id: 'fertilizer',
    label: '速效肥料',
    price: 15,
    description: '立即推进一块作物 30% 总生长时间',
    tint: 0xFFB08968,
  );

  /// 阳光瓶：全部在长作物各推进 20%。
  static const sunshine = FarmItemConfig(
    id: 'sunshine',
    label: '阳光瓶',
    price: 60,
    description: '全部生长中作物各推进 20% 时间',
    tint: 0xFFFFD43B,
  );

  static const all = [fertilizer, sunshine];

  static FarmItemConfig byId(String id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return fertilizer;
  }
}

/// 农场美术路径助手（参照 PetArt 约定）。
class FarmArt {
  const FarmArt._();

  static const soilDry = 'assets/farm/tiles/soil_dry.png';
  static const soilWet = 'assets/farm/tiles/soil_wet.png';
  static const grassTile = 'assets/farm/tiles/grass_tile.png';
  static const farmBg = 'assets/farm/tiles/farm_bg.png';
  static const coinIcon = 'assets/farm/ui/coin.png';
  static const seedBagIcon = 'assets/farm/ui/seed_bag.png';

  static String crop(String cropId, FarmCropStage stage) =>
      'assets/farm/crops/${cropId}_${stage.name}.png';
}
