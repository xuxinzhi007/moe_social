import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_crop_config.dart';
import '../models/farm_state.dart';
import 'pet_provider.dart';

/// 单次收获结算结果（供页面层做 Juice 特效）。
class FarmHarvestResult {
  const FarmHarvestResult({
    required this.index,
    required this.config,
    required this.coins,
    required this.mutation,
    required this.combo,
    required this.isDailyFirst,
  });

  final int index;
  final FarmCropConfig config;
  final int coins;
  final FarmMutation mutation;
  final int combo;
  final bool isDailyFirst;
}

/// 农场业务 Provider（v1 纯本地，数据模型预留后端扩展）。
///
/// 金币与宠物系统共用：通过 [PetProvider.addCoins] / [PetProvider.spendCoins]。
class FarmProvider extends ChangeNotifier {
  FarmProvider({required PetProvider pet}) : _pet = pet;

  static const _prefsKey = 'farm_state_v1';

  /// 连收窗口：两次收获间隔小于该值则 combo 递增。
  static const comboWindowMs = 6000;

  /// 变异概率。
  static const goldenChance = 0.08;
  static const rainbowChance = 0.02;

  final PetProvider _pet;
  final math.Random _rng = math.Random();

  FarmState _state = FarmState.fresh();
  bool _loaded = false;
  Timer? _growTimer;
  Timer? _persistDebounce;

  FarmState get state => _state;
  bool get loaded => _loaded;
  int get coins => _pet.profile.coins;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _state = FarmState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        _state = FarmState.fresh();
      }
    }
    // 离线期间按真实时间补长（progressSeconds 模型天然支持）。
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final savedAt = prefs.getInt('${_prefsKey}_saved_at') ?? nowMs;
    final offlineSeconds = ((nowMs - savedAt) / 1000).clamp(0.0, 7 * 86400.0);
    if (offlineSeconds > 1) {
      _advanceAll(offlineSeconds);
    }
    _rollDailyReset();
    _loaded = true;
    notifyListeners();
    _ensureGrowTicker();
  }

  @override
  void dispose() {
    _growTimer?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- 生长

  void _ensureGrowTicker() {
    _growTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _advanceAll(1);
      _checkComboExpire();
    });
  }

  void _advanceAll(double seconds) {
    if (seconds <= 0) return;
    var changed = false;
    final plots = List<FarmPlot>.of(_state.plots);
    for (var i = 0; i < plots.length; i++) {
      final p = plots[i];
      if (p.isEmpty || p.isRipe) continue;
      plots[i] = p.copyWith(progressSeconds: p.progressSeconds + seconds);
      changed = true;
    }
    if (!changed) return;
    _state = _state.copyWith(plots: plots);
    notifyListeners();
    _debouncedPersist();
  }

  void _checkComboExpire() {
    if (_state.combo <= 0) return;
    if (DateTime.now().millisecondsSinceEpoch > _state.comboExpireMs) {
      _state = _state.copyWith(combo: 0, comboExpireMs: 0);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- 种植

  /// 从种子背包种植。
  FarmPlot? plantSeed(int index, String cropId) {
    if (index < 0 || index >= _state.plots.length) return null;
    final slot = _state.plots[index];
    if (!slot.isEmpty) return null;
    final count = _state.seedCountOf(cropId);
    if (count <= 0) return null;
    final bag = Map<String, int>.of(_state.seedBag);
    bag[cropId] = count - 1;
    if (bag[cropId]! <= 0) bag.remove(cropId);
    final planted = FarmPlot(
      index: index,
      cropId: cropId,
      plantedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final plots = List<FarmPlot>.of(_state.plots)..[index] = planted;
    _state = _state.copyWith(plots: plots, seedBag: bag);
    notifyListeners();
    _debouncedPersist();
    return planted;
  }

  /// 浇水：当前阶段剩余时间 -30%（最多 2 次）。
  FarmPlot? waterPlot(int index) {
    if (index < 0 || index >= _state.plots.length) return null;
    final slot = _state.plots[index];
    if (!slot.canWater) return null;
    final cfg = slot.config;
    // 当前阶段门槛区间：浇水只缩短当前阶段剩余时间的 30%。
    final stageEnd =
        slot.stage == FarmCropStage.seed ? cfg.seedSeconds : cfg.totalSeconds;
    final remaining = stageEnd - slot.progressSeconds;
    final boosted = slot.progressSeconds + remaining * 0.3;
    final watered = slot.copyWith(
      progressSeconds: boosted,
      waterCount: slot.waterCount + 1,
    );
    final plots = List<FarmPlot>.of(_state.plots)..[index] = watered;
    _state = _state.copyWith(plots: plots);
    notifyListeners();
    _debouncedPersist();
    return watered;
  }

  // ---------------------------------------------------------------- 收获

  /// 收获单块。返回结算结果（含 combo/变异/每日首收）。
  FarmHarvestResult? harvestPlot(int index) {
    if (index < 0 || index >= _state.plots.length) return null;
    final slot = _state.plots[index];
    if (!slot.isRipe) return null;
    return _doHarvest(index, slot);
  }

  /// 一键全收：所有成熟地块。
  List<FarmHarvestResult> harvestAll() {
    final results = <FarmHarvestResult>[];
    for (var i = 0; i < _state.plots.length; i++) {
      final slot = _state.plots[i];
      if (!slot.isRipe) continue;
      final r = _doHarvest(i, slot);
      if (r != null) results.add(r);
    }
    return results;
  }

  FarmHarvestResult? _doHarvest(int index, FarmPlot slot) {
    final cfg = slot.config;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // 连收 combo：窗口内续上则 +1，否则重置为 1。
    final combo = (nowMs <= _state.comboExpireMs)
        ? _state.combo + 1
        : 1;
    final comboMultiplier = 1.0 + 0.2 * math.min(combo - 1, 5);

    // 变异掷骰。
    final roll = _rng.nextDouble();
    final mutation = roll < rainbowChance
        ? FarmMutation.rainbow
        : (roll < rainbowChance + goldenChance
            ? FarmMutation.golden
            : FarmMutation.none);

    // 每日首收 ×2。
    final dayKey = _dayKey(now);
    final isDailyFirst = _state.lastHarvestDay != dayKey;
    final dailyMultiplier = isDailyFirst ? 2.0 : 1.0;

    final coins = (cfg.harvestCoins *
            comboMultiplier *
            mutation.rewardMultiplier *
            dailyMultiplier)
        .round();

    final plots = List<FarmPlot>.of(_state.plots)
      ..[index] = FarmPlot(index: index);
    _state = _state.copyWith(
      plots: plots,
      combo: combo,
      comboExpireMs: nowMs + comboWindowMs,
      lastHarvestDay: dayKey,
      dailyFirstHarvestDone: true,
      totalHarvests: _state.totalHarvests + 1,
      mutationCount: _state.mutationCount +
          (mutation == FarmMutation.none ? 0 : 1),
    );
    _pet.addCoins(coins);
    _pet.boostMood(cfg.moodReward);
    notifyListeners();
    _debouncedPersist();
    return FarmHarvestResult(
      index: index,
      config: cfg,
      coins: coins,
      mutation: mutation,
      combo: combo,
      isDailyFirst: isDailyFirst,
    );
  }

  // ---------------------------------------------------------------- 商店

  /// 购买种子入背包。
  bool buySeed(String cropId, {int count = 1}) {
    final cfg = FarmCropConfig.byId(cropId);
    final cost = cfg.seedPrice * count;
    if (!_pet.spendCoins(cost)) return false;
    final bag = Map<String, int>.of(_state.seedBag);
    bag[cropId] = (bag[cropId] ?? 0) + count;
    _state = _state.copyWith(seedBag: bag);
    notifyListeners();
    _debouncedPersist();
    return true;
  }

  /// 购买道具。
  bool buyItem(String itemId) {
    final cfg = FarmItemConfig.byId(itemId);
    if (!_pet.spendCoins(cfg.price)) return false;
    final items = Map<String, int>.of(_state.items);
    items[itemId] = (items[itemId] ?? 0) + 1;
    _state = _state.copyWith(items: items);
    notifyListeners();
    _debouncedPersist();
    return true;
  }

  /// 肥料：单块推进总时长 30%。
  bool useFertilizer(int index) {
    if (_state.itemCountOf('fertilizer') <= 0) return false;
    if (index < 0 || index >= _state.plots.length) return false;
    final slot = _state.plots[index];
    if (slot.isEmpty || slot.isRipe) return false;
    final boosted =
        slot.copyWith(progressSeconds: slot.progressSeconds +
            slot.config.totalSeconds * 0.3);
    final plots = List<FarmPlot>.of(_state.plots)..[index] = boosted;
    _state = _state.copyWith(
      plots: plots,
      items: _consumeItem(_state.items, 'fertilizer'),
    );
    notifyListeners();
    _debouncedPersist();
    return true;
  }

  /// 阳光瓶：全部生长中作物推进 20%。
  bool useSunshine() {
    if (_state.itemCountOf('sunshine') <= 0) return false;
    var used = false;
    final plots = List<FarmPlot>.of(_state.plots);
    for (var i = 0; i < plots.length; i++) {
      final p = plots[i];
      if (p.isEmpty || p.isRipe) continue;
      plots[i] = p.copyWith(
          progressSeconds: p.progressSeconds + p.config.totalSeconds * 0.2);
      used = true;
    }
    if (!used) return false;
    _state = _state.copyWith(
      plots: plots,
      items: _consumeItem(_state.items, 'sunshine'),
    );
    notifyListeners();
    _debouncedPersist();
    return true;
  }

  Map<String, int> _consumeItem(Map<String, int> items, String id) {
    final next = Map<String, int>.of(items);
    final left = (next[id] ?? 0) - 1;
    if (left <= 0) {
      next.remove(id);
    } else {
      next[id] = left;
    }
    return next;
  }

  // ---------------------------------------------------------------- 工具

  String _dayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  void _rollDailyReset() {
    final today = _dayKey(DateTime.now());
    if (_state.lastHarvestDay != today) {
      _state = _state.copyWith(dailyFirstHarvestDone: false);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_state.toJson()));
    await prefs.setInt(
      '${_prefsKey}_saved_at',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _debouncedPersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_persist());
    });
  }
}
