/// 院子菜地格子（本地养成爽感循环，不依赖后端契约）。
enum PetCropStage {
  empty,
  seed,
  sprout,
  ripe,
}

class PetCropKind {
  const PetCropKind({
    required this.id,
    required this.label,
    required this.emoji,
    required this.coinReward,
    required this.moodReward,
  });

  final String id;
  final String label;
  final String emoji;
  final int coinReward;
  final int moodReward;

  static const carrot = PetCropKind(
    id: 'carrot',
    label: '小胡萝卜',
    emoji: '🥕',
    coinReward: 10,
    moodReward: 4,
  );
  static const radish = PetCropKind(
    id: 'radish',
    label: '水萝卜',
    emoji: '🧅',
    coinReward: 12,
    moodReward: 5,
  );
  static const cabbage = PetCropKind(
    id: 'cabbage',
    label: '卷心菜',
    emoji: '🥬',
    coinReward: 14,
    moodReward: 6,
  );

  static const all = [carrot, radish, cabbage];

  static PetCropKind byId(String id) {
    for (final k in all) {
      if (k.id == id) return k;
    }
    return carrot;
  }
}

class PetCropSlot {
  const PetCropSlot({
    required this.index,
    required this.stage,
    this.cropId = '',
    this.plantedAtMs = 0,
    this.waterCount = 0,
  });

  final int index;
  final PetCropStage stage;
  final String cropId;
  final int plantedAtMs;
  final int waterCount;

  /// QQ 农场式网格：列 × 行。
  static const gridCols = 4;
  static const gridRows = 3;
  static const plotCount = gridCols * gridRows;

  static int colOf(int index) => index % gridCols;
  static int rowOf(int index) => index ~/ gridCols;

  /// 各阶段成长秒数（偏短，保证「种完就能爽」）。
  static const seedSeconds = 3.5;
  static const sproutSeconds = 4.5;
  static const waterBonusSeconds = 2.2;

  PetCropKind get kind => PetCropKind.byId(cropId);

  bool get isEmpty => stage == PetCropStage.empty;
  bool get isRipe => stage == PetCropStage.ripe;
  bool get canWater =>
      stage == PetCropStage.seed || stage == PetCropStage.sprout;

  PetCropSlot copyWith({
    PetCropStage? stage,
    String? cropId,
    int? plantedAtMs,
    int? waterCount,
  }) =>
      PetCropSlot(
        index: index,
        stage: stage ?? this.stage,
        cropId: cropId ?? this.cropId,
        plantedAtMs: plantedAtMs ?? this.plantedAtMs,
        waterCount: waterCount ?? this.waterCount,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'stage': stage.name,
        'crop_id': cropId,
        'planted_at_ms': plantedAtMs,
        'water_count': waterCount,
      };

  factory PetCropSlot.fromJson(Map<String, dynamic> json) {
    final stageName = '${json['stage'] ?? 'empty'}';
    final stage = PetCropStage.values.firstWhere(
      (e) => e.name == stageName,
      orElse: () => PetCropStage.empty,
    );
    return PetCropSlot(
      index: (json['index'] as num?)?.toInt() ?? 0,
      stage: stage,
      cropId: '${json['crop_id'] ?? ''}',
      plantedAtMs: (json['planted_at_ms'] as num?)?.toInt() ?? 0,
      waterCount: (json['water_count'] as num?)?.toInt() ?? 0,
    );
  }

  static List<PetCropSlot> freshPlots() => [
        for (var i = 0; i < plotCount; i++)
          PetCropSlot(index: i, stage: PetCropStage.empty),
      ];

  /// 根据种植时间推进阶段。
  PetCropSlot advanced(DateTime now) {
    if (isEmpty || isRipe || plantedAtMs <= 0) return this;
    final elapsed = (now.millisecondsSinceEpoch - plantedAtMs) / 1000.0;
    final bonus = waterCount * waterBonusSeconds;
    final t = elapsed + bonus;
    if (t >= seedSeconds + sproutSeconds) {
      return copyWith(stage: PetCropStage.ripe);
    }
    if (t >= seedSeconds) {
      return copyWith(stage: PetCropStage.sprout);
    }
    return copyWith(stage: PetCropStage.seed);
  }
}
