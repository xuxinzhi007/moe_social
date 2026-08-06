import 'farm_crop_config.dart';

/// 农场网格尺寸（6×8 起步，预留扩地字段）。
class FarmGrid {
  const FarmGrid._();

  static const cols = 6;
  static const rows = 8;
  static const plotCount = cols * rows;

  /// 单格世界像素（逻辑坐标 → 像素乘数）。
  static const tileSize = 128.0;

  static const double worldWidth = cols * tileSize;
  static const double worldHeight = rows * tileSize;

  static int colOf(int index) => index % cols;
  static int rowOf(int index) => index ~/ cols;
  static int indexOf(int col, int row) => row * cols + col;
  static bool inBounds(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows;
}

/// 单个田块状态。
///
/// 生长推进采用「累计有效秒数」模型：
/// [progressSeconds] 随时间/浇水/道具增长，与配置表门槛比较决定阶段。
/// 该模型天然支持后端重放校验（v2 同步时只需对齐 plantedAtMs）。
class FarmPlot {
  const FarmPlot({
    required this.index,
    this.cropId = '',
    this.progressSeconds = 0,
    this.plantedAtMs = 0,
    this.waterCount = 0,
    this.pendingMutation = FarmMutation.none,
  });

  final int index;

  /// 空地为 ''。
  final String cropId;

  /// 已累积的有效生长秒数（含浇水/道具加速折算）。
  final double progressSeconds;

  /// 种植时间戳（后端扩展预留）。
  final int plantedAtMs;

  /// 已浇水次数（上限 2）。
  final int waterCount;

  /// 收获时掷出的变异档（ripe 后展示用）。
  final FarmMutation pendingMutation;

  FarmCropConfig get config => FarmCropConfig.byId(cropId);

  bool get isEmpty => cropId.isEmpty;
  bool get isRipe =>
      !isEmpty && progressSeconds >= config.totalSeconds;
  FarmCropStage get stage {
    if (isEmpty) return FarmCropStage.empty;
    if (progressSeconds >= config.totalSeconds) return FarmCropStage.ripe;
    if (progressSeconds >= config.seedSeconds) return FarmCropStage.sprout;
    return FarmCropStage.seed;
  }

  /// 当前阶段剩余秒数（ripe 时为 0）。
  double get remainingSeconds =>
      isEmpty ? 0 : (config.totalSeconds - progressSeconds).clamp(0.0, 1e9);

  bool get canWater => !isEmpty && !isRipe && waterCount < maxWater;
  static const maxWater = 2;

  /// 剩余时间可读文案（如 "1分20秒"）。
  String get remainingLabel {
    if (isEmpty) return '';
    final s = remainingSeconds.ceil();
    if (s <= 0) return '可收获';
    if (s < 60) return '$s秒';
    final m = s ~/ 60;
    final rs = s % 60;
    if (m < 60) return rs == 0 ? '$m分钟' : '$m分$rs秒';
    final h = m ~/ 60;
    final rm = m % 60;
    return rm == 0 ? '$h小时' : '$h小时$rm分';
  }

  FarmPlot copyWith({
    String? cropId,
    double? progressSeconds,
    int? plantedAtMs,
    int? waterCount,
    FarmMutation? pendingMutation,
  }) =>
      FarmPlot(
        index: index,
        cropId: cropId ?? this.cropId,
        progressSeconds: progressSeconds ?? this.progressSeconds,
        plantedAtMs: plantedAtMs ?? this.plantedAtMs,
        waterCount: waterCount ?? this.waterCount,
        pendingMutation: pendingMutation ?? this.pendingMutation,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'crop_id': cropId,
        'progress_seconds': progressSeconds,
        'planted_at_ms': plantedAtMs,
        'water_count': waterCount,
        'mutation': pendingMutation.name,
      };

  factory FarmPlot.fromJson(Map<String, dynamic> json) {
    final mutationName = '${json['mutation'] ?? 'none'}';
    return FarmPlot(
      index: (json['index'] as num?)?.toInt() ?? 0,
      cropId: '${json['crop_id'] ?? ''}',
      progressSeconds: (json['progress_seconds'] as num?)?.toDouble() ?? 0,
      plantedAtMs: (json['planted_at_ms'] as num?)?.toInt() ?? 0,
      waterCount: (json['water_count'] as num?)?.toInt() ?? 0,
      pendingMutation: FarmMutation.values.firstWhere(
        (m) => m.name == mutationName,
        orElse: () => FarmMutation.none,
      ),
    );
  }

  static List<FarmPlot> fresh() => [
        for (var i = 0; i < FarmGrid.plotCount; i++) FarmPlot(index: i),
      ];
}

/// 农场整体存档（本地 JSON；字段为后端契约预留）。
class FarmState {
  const FarmState({
    required this.plots,
    required this.seedBag,
    required this.items,
    required this.combo,
    required this.comboExpireMs,
    required this.lastHarvestDay,
    required this.dailyFirstHarvestDone,
    required this.totalHarvests,
    required this.mutationCount,
  });

  final List<FarmPlot> plots;

  /// 种子背包：cropId → 数量。
  final Map<String, int> seedBag;

  /// 道具背包：itemId → 数量。
  final Map<String, int> items;

  /// 当前连收计数（超 [comboExpireMs] 未续则归零）。
  final int combo;
  final int comboExpireMs;

  /// 每日首收：日期串 yyyy-MM-dd。
  final String lastHarvestDay;
  final bool dailyFirstHarvestDone;

  final int totalHarvests;
  final int mutationCount;

  int seedCountOf(String cropId) => seedBag[cropId] ?? 0;
  int itemCountOf(String itemId) => items[itemId] ?? 0;

  int get ripeCount => plots.where((p) => p.isRipe).length;

  FarmState copyWith({
    List<FarmPlot>? plots,
    Map<String, int>? seedBag,
    Map<String, int>? items,
    int? combo,
    int? comboExpireMs,
    String? lastHarvestDay,
    bool? dailyFirstHarvestDone,
    int? totalHarvests,
    int? mutationCount,
  }) =>
      FarmState(
        plots: plots ?? this.plots,
        seedBag: seedBag ?? this.seedBag,
        items: items ?? this.items,
        combo: combo ?? this.combo,
        comboExpireMs: comboExpireMs ?? this.comboExpireMs,
        lastHarvestDay: lastHarvestDay ?? this.lastHarvestDay,
        dailyFirstHarvestDone:
            dailyFirstHarvestDone ?? this.dailyFirstHarvestDone,
        totalHarvests: totalHarvests ?? this.totalHarvests,
        mutationCount: mutationCount ?? this.mutationCount,
      );

  /// 新手礼包：5 萝卜种子 + 2 肥料。
  factory FarmState.fresh() => FarmState(
        plots: FarmPlot.fresh(),
        seedBag: {'radish': 5, 'carrot': 2},
        items: {'fertilizer': 2},
        combo: 0,
        comboExpireMs: 0,
        lastHarvestDay: '',
        dailyFirstHarvestDone: false,
        totalHarvests: 0,
        mutationCount: 0,
      );

  Map<String, dynamic> toJson() => {
        'plots': [for (final p in plots) p.toJson()],
        'seed_bag': seedBag,
        'items': items,
        'combo': combo,
        'combo_expire_ms': comboExpireMs,
        'last_harvest_day': lastHarvestDay,
        'daily_first_harvest_done': dailyFirstHarvestDone,
        'total_harvests': totalHarvests,
        'mutation_count': mutationCount,
      };

  factory FarmState.fromJson(Map<String, dynamic> json) {
    final rawPlots = json['plots'];
    final plots = FarmPlot.fresh();
    if (rawPlots is List) {
      for (final e in rawPlots) {
        if (e is! Map) continue;
        final p = FarmPlot.fromJson(Map<String, dynamic>.from(e));
        if (p.index >= 0 && p.index < plots.length) {
          plots[p.index] = FarmPlot(
            index: p.index,
            cropId: p.cropId,
            progressSeconds: p.progressSeconds,
            plantedAtMs: p.plantedAtMs,
            waterCount: p.waterCount,
            pendingMutation: p.pendingMutation,
          );
        }
      }
    }
    Map<String, int> intMap(dynamic raw) {
      final out = <String, int>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          final count = (v as num?)?.toInt() ?? 0;
          if (count > 0) out['$k'] = count;
        });
      }
      return out;
    }

    return FarmState(
      plots: plots,
      seedBag: intMap(json['seed_bag']),
      items: intMap(json['items']),
      combo: (json['combo'] as num?)?.toInt() ?? 0,
      comboExpireMs: (json['combo_expire_ms'] as num?)?.toInt() ?? 0,
      lastHarvestDay: '${json['last_harvest_day'] ?? ''}',
      dailyFirstHarvestDone:
          (json['daily_first_harvest_done'] as bool?) ?? false,
      totalHarvests: (json['total_harvests'] as num?)?.toInt() ?? 0,
      mutationCount: (json['mutation_count'] as num?)?.toInt() ?? 0,
    );
  }
}
