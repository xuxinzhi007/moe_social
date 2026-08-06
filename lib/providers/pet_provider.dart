import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_crop.dart';
import '../models/pet_state.dart';
import '../models/pet_care_item.dart';
import '../services/pet_career_config.dart';
import '../services/pet_service.dart';
import '../game/pet/pet_content_catalog.dart';
import '../game/pet/pet_content_registry.dart';

/// 养成状态：优先 API，失败本地持久化（保证可完整体验）。
enum PetSyncStatus { syncing, cloudSynced, localOnly }

class PetProvider extends ChangeNotifier {
  PetProvider({PetService? service}) : _service = service ?? PetService();

  static const _prefsKey = 'pet_life_sim_profile_v1';

  /// v2：4×3 网格地块（兼容读旧 v1，多出来的格补空）。
  static const _cropsKey = 'pet_yard_crops_v2';
  static const _cropsKeyLegacy = 'pet_yard_crops_v1';
  static const _msgHold = Duration(seconds: 2);

  final PetService _service;
  PetProfile _profile = PetProfile.fresh();
  List<PetCropSlot> _crops = PetCropSlot.freshPlots();
  String? _lastMessage;
  bool _busy = false;
  bool _loaded = false;
  PetSyncStatus _syncStatus = PetSyncStatus.syncing;
  Timer? _msgTimer;
  Timer? _furnitureSyncTimer;
  Timer? _boundarySyncTimer;
  Timer? _cropGrowTimer;

  PetProfile get profile => _profile;
  List<PetCropSlot> get crops => List.unmodifiable(_crops);
  String? get lastMessage => _lastMessage;
  bool get busy => _busy;
  bool get loaded => _loaded;
  PetSyncStatus get syncStatus => _syncStatus;

  /// Toast 文案短暂展示后自动清空，避免「换好啦！」等提示常驻。
  void _flashMessage(String msg) {
    _lastMessage = msg;
    notifyListeners();
    _msgTimer?.cancel();
    _msgTimer = Timer(_msgHold, () {
      if (_lastMessage == msg) {
        _lastMessage = null;
        notifyListeners();
      }
    });
  }

  Future<void> load() async {
    _busy = true;
    notifyListeners();
    // Paper 内容骨架（manifest / 构图 / 商店）；缺失静默回落。
    await PetContentCatalog.load();
    unawaited(PetContentRegistry.loadIfPresent());
    final remote = await _service.fetchState();
    if (remote != null) {
      _syncStatus = PetSyncStatus.cloudSynced;
      var furn = PetFurniture.sanitize(remote.furniture);
      if (furn.isEmpty) {
        furn = PetContentCatalog.starterFurniture();
      }
      _profile = remote.copyWith(furniture: furn);
    } else {
      _syncStatus = PetSyncStatus.localOnly;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _profile = PetProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } else {
        _profile = PetProfile.fresh().copyWith(
          furniture: PetContentCatalog.starterFurniture(),
        );
      }
    }
    // 清理超量 + 场景穿帮（旧存档院子里的台灯/木桌）。
    final beforeCount = _profile.furniture.length;
    var cleaned = PetContentCatalog.pruneFurnitureScenes(_profile.furniture);
    if (cleaned.isEmpty) {
      cleaned = PetContentCatalog.starterFurniture();
      _flashMessage('已为小家摆上起步家具');
    } else if (cleaned.length != beforeCount) {
      _flashMessage('已整理错放家具');
    }
    _profile = _profile.copyWith(furniture: cleaned);
    await _loadCrops();
    _loaded = true;
    _busy = false;
    notifyListeners();
    await _persist();
    _ensureCropGrowTicker();
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _furnitureSyncTimer?.cancel();
    _boundarySyncTimer?.cancel();
    _cropGrowTimer?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
  }

  Future<void> _loadCrops() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_cropsKey);
    raw ??= prefs.getString(_cropsKeyLegacy);
    if (raw == null || raw.isEmpty) {
      _crops = PetCropSlot.freshPlots();
      return;
    }
    try {
      final list = jsonDecode(raw);
      if (list is! List) {
        _crops = PetCropSlot.freshPlots();
        return;
      }
      final now = DateTime.now();
      final next = <PetCropSlot>[];
      for (var i = 0; i < PetCropSlot.plotCount; i++) {
        PetCropSlot slot = PetCropSlot(index: i, stage: PetCropStage.empty);
        if (i < list.length && list[i] is Map) {
          final parsed =
              PetCropSlot.fromJson(Map<String, dynamic>.from(list[i] as Map));
          slot = PetCropSlot(
            index: i,
            stage: parsed.stage,
            cropId: parsed.cropId,
            plantedAtMs: parsed.plantedAtMs,
            waterCount: parsed.waterCount,
          );
        }
        next.add(slot.advanced(now));
      }
      _crops = next;
      // 从旧 key 迁到网格存档。
      await _persistCrops();
    } catch (_) {
      _crops = PetCropSlot.freshPlots();
    }
  }

  Future<void> _persistCrops() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cropsKey,
      jsonEncode([for (final c in _crops) c.toJson()]),
    );
  }

  void _ensureCropGrowTicker() {
    _cropGrowTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      _tickCrops();
    });
  }

  void _tickCrops() {
    final now = DateTime.now();
    var changed = false;
    final next = <PetCropSlot>[];
    for (final c in _crops) {
      final advanced = c.advanced(now);
      if (advanced.stage != c.stage) changed = true;
      next.add(advanced);
    }
    if (!changed) return;
    _crops = next;
    notifyListeners();
    unawaited(_persistCrops());
  }

  /// 点空地：随机种一种菜。
  Future<PetCropSlot?> plantCrop(int index) async {
    if (index < 0 || index >= _crops.length) return null;
    final slot = _crops[index];
    if (!slot.isEmpty) return null;
    final kind = PetCropKind.all[math.Random().nextInt(PetCropKind.all.length)];
    final planted = PetCropSlot(
      index: index,
      stage: PetCropStage.seed,
      cropId: kind.id,
      plantedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _crops = [..._crops]..[index] = planted;
    _flashMessage('种下了${kind.label}！');
    notifyListeners();
    await _persistCrops();
    _ensureCropGrowTicker();
    return planted;
  }

  /// 浇水加速一档成长。
  Future<PetCropSlot?> waterCrop(int index) async {
    if (index < 0 || index >= _crops.length) return null;
    final slot = _crops[index];
    if (!slot.canWater || slot.waterCount >= 2) return null;
    final next =
        slot.copyWith(waterCount: slot.waterCount + 1).advanced(DateTime.now());
    _crops = [..._crops]..[index] = next;
    _flashMessage('浇水！长得更快啦');
    notifyListeners();
    await _persistCrops();
    return next;
  }

  /// 收获：硬币 + 心情，返回奖励（给 Juice 用）。
  Future<({int coins, int mood, PetCropKind kind, int comboHint})?> harvestCrop(
    int index, {
    int combo = 1,
  }) async {
    if (index < 0 || index >= _crops.length) return null;
    final slot = _crops[index];
    if (!slot.isRipe) return null;
    final kind = slot.kind;
    final comboBonus = math.min(8, (combo - 1) * 2);
    final coins = kind.coinReward + comboBonus;
    final mood = kind.moodReward;
    _crops = [..._crops]..[index] =
        PetCropSlot(index: index, stage: PetCropStage.empty);
    _profile = _profile.copyWith(
      coins: _profile.coins + coins,
      mood: math.min(100, _profile.mood + mood),
      labor: _profile.labor + (combo >= 3 ? 1 : 0),
      energy: math.max(0, _profile.energy - 2),
    );
    _flashMessage('收获${kind.label}！+$coins 币');
    notifyListeners();
    await _persist();
    await _persistCrops();
    return (coins: coins, mood: mood, kind: kind, comboHint: combo);
  }

  /// 金币增减公共入口（农场等衍生模块共用宠物 coins）。
  /// [spendCoins] 余额不足返回 false 且不扣款。
  void addCoins(int amount) {
    if (amount <= 0) return;
    _profile = _profile.copyWith(coins: _profile.coins + amount);
    notifyListeners();
    unawaited(_persist());
  }

  bool spendCoins(int amount) {
    if (amount <= 0 || _profile.coins < amount) return false;
    _profile = _profile.copyWith(coins: _profile.coins - amount);
    notifyListeners();
    unawaited(_persist());
    return true;
  }

  /// 心情小幅提升（农场收获等联动）。
  void boostMood(int amount) {
    if (amount <= 0) return;
    _profile = _profile.copyWith(
      mood: math.min(100, _profile.mood + amount),
    );
    notifyListeners();
    unawaited(_persist());
  }

  /// 本地落盘后异步写库（失败不影响本地布置）。
  Future<void> _syncFurnitureToServer() async {
    final localSnapshot = List<PetFurniture>.from(_profile.furniture);
    final remote = await _service.saveFurniture(localSnapshot);
    if (remote == null) return;
    _syncStatus = PetSyncStatus.cloudSynced;
    // 若拖放期间本地又变了，不要用旧回写覆盖，避免「复制/回跳」。
    if (!_furnitureListEquals(_profile.furniture, localSnapshot)) {
      await _persist();
      return;
    }
    final slots = PetFurniture.sanitize(
      remote.furniture.isNotEmpty ? remote.furniture : localSnapshot,
    );
    if (slots.isEmpty && _profile.furniture.isNotEmpty) return;
    if (_furnitureListEquals(_profile.furniture, slots)) {
      await _persist();
      return;
    }
    _profile = _profile.copyWith(furniture: slots);
    notifyListeners();
    await _persist();
  }

  bool _furnitureListEquals(List<PetFurniture> a, List<PetFurniture> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.scene != y.scene ||
          x.rotation != y.rotation ||
          (x.x - y.x).abs() > 0.0001 ||
          (x.y - y.y).abs() > 0.0001 ||
          (x.scale - y.scale).abs() > 0.0001) {
        return false;
      }
    }
    return true;
  }

  void _scheduleFurnitureServerSync() {
    _furnitureSyncTimer?.cancel();
    _furnitureSyncTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_syncFurnitureToServer());
    });
  }

  Future<void> _apply(
    PetProfile? remote,
    PetProfile local, {
    bool preferRemoteFurniture = false,
  }) async {
    if (remote == null) {
      _profile = local;
      _syncStatus = PetSyncStatus.localOnly;
    } else {
      final merged = local.assimilateCloud(
        remote,
        preferRemoteFurniture: preferRemoteFurniture,
      );
      _profile = merged.copyWith(
        furniture: PetContentCatalog.pruneFurnitureScenes(merged.furniture),
      );
      _syncStatus = PetSyncStatus.cloudSynced;
      // 服务端场景漂移时纠偏，避免下次冷启动又弹回客厅。
      if (remote.sceneId != local.sceneId &&
          const {'living', 'yard', 'bedroom'}.contains(local.sceneId)) {
        unawaited(_service.setScene(local.sceneId));
      }
    }
    _busy = false;
    notifyListeners();
    await _persist();
  }

  Future<void> feed(PetCareItem item) async {
    if (_busy) return;
    _busy = true;
    final local = _profile.copyWith(
      hunger: math.min(100, _profile.hunger + item.hungerGain),
      mood: math.min(100, _profile.mood + item.moodGain),
    );
    _profile = local;
    _flashMessage('好好吃！');
    notifyListeners();
    final remote = await _service.feed(item.id);
    await _apply(remote, local);
  }

  Future<void> care() async {
    if (_busy) return;
    _busy = true;
    final local = _profile.copyWith(
      mood: math.min(100, _profile.mood + 14),
      energy: math.min(100, _profile.energy + 6),
    );
    _profile = local;
    _flashMessage('最喜欢你了～');
    notifyListeners();
    final remote = await _service.care();
    await _apply(remote, local);
  }

  /// 点床睡觉：本地回精力（规则互动，不需要模型 / 专用 API）。
  Future<void> restAtBed() async {
    final local = _profile.copyWith(
      energy: math.min(100, _profile.energy + 18),
      mood: math.min(100, _profile.mood + 4),
    );
    _flashMessage('睡了一觉，精神好多了～');
    await _apply(null, local);
  }

  Future<void> setScene(String scene) async {
    const allowed = {'living', 'yard', 'bedroom'};
    if (!allowed.contains(scene) || scene == _profile.sceneId) return;
    // 本地先切：等网再改会表现为「点院子没反应」。
    final local = _profile.copyWith(sceneId: scene);
    _profile = local;
    _syncStatus = PetSyncStatus.syncing;
    notifyListeners();
    await _persist();
    final remote = await _service.setScene(scene);
    if (remote != null) {
      final mergedFurn =
          remote.furniture.isNotEmpty ? remote.furniture : local.furniture;
      // 云端缺字段时不回退场景；角色坐标服务端未存，保留本地。
      _profile = remote.copyWith(
        sceneId: scene,
        actorX: local.actorX,
        actorY: local.actorY,
        furniture: PetContentCatalog.pruneFurnitureScenes(mergedFurn),
        wearLayout: local.wearLayout,
      );
      _syncStatus = PetSyncStatus.cloudSynced;
    } else {
      _syncStatus = PetSyncStatus.localOnly;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> dress({
    String? hat,
    String? top,
    String? bottom,
    String? shoes,
    PetWearLayout? wearLayout,
  }) async {
    // 先本地生效；换衣间点「保存」时带 wearLayout。
    final local = _profile.copyWith(
      hatId: hat ?? _profile.hatId,
      topId: top ?? _profile.topId,
      bottomId: bottom ?? _profile.bottomId,
      shoesId: shoes ?? _profile.shoesId,
      wearLayout: wearLayout ?? _profile.wearLayout,
    );
    _profile = local;
    _flashMessage(wearLayout != null ? '穿着已保存' : '换好啦！');
    await _persist();
    final remote = await _service.dress(
      hat: local.hatId,
      top: local.topId,
      bottom: local.bottomId,
      shoes: local.shoesId,
      wearLayout: local.wearLayout,
    );
    if (remote == null) return;
    _profile = remote.copyWith(
      hatId: local.hatId,
      topId: local.topId,
      bottomId: local.bottomId,
      shoesId: local.shoesId,
      wearLayout: local.wearLayout,
    );
    notifyListeners();
    await _persist();
  }

  /// 换衣间保存：穿着 ID + 拖放布局一并落库/本地。
  Future<void> saveOutfit({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
    required PetWearLayout wearLayout,
  }) {
    return dress(
      hat: hatId,
      top: topId,
      bottom: bottomId,
      shoes: shoesId,
      wearLayout: wearLayout,
    );
  }

  Future<void> placeFurniture(PetFurniture item) async {
    final sceneItems =
        _profile.furniture.where((f) => f.scene == item.scene).toList();
    if (sceneItems.length >= PetFurniture.maxPerScene) {
      _flashMessage(
        '本房间最多 ${PetFurniture.maxPerScene} 件家具，请先移除一些',
      );
      return;
    }
    final sameId = sceneItems.where((f) => f.id == item.id).length;
    if (sameId >= PetFurniture.maxSameIdPerScene) {
      _flashMessage(
        '「同款」最多 ${PetFurniture.maxSameIdPerScene} 件，请先调整已有摆件',
      );
      return;
    }
    // 自动错开落点；默认尺度读 room_composition。
    final offset = sameId * 0.06;
    final defaultScale = PetContentCatalog.furnitureDefaultScale(item.id);
    final placed = item.copyWith(
      x: (item.x + offset).clamp(0.08, 0.92),
      y: (item.y + offset * 0.5).clamp(0.18, 0.92),
      scale: item.scale == 1.0 ? defaultScale : item.scale,
    );
    final next = [..._profile.furniture, placed];
    await _apply(null, _profile.copyWith(furniture: next));
    _flashMessage('已添加，可拖动 / 旋转摆放');
    _scheduleFurnitureServerSync();
  }

  /// 更新家具坐标 / 旋转 / 缩放（拖放 · 四角 · 旋转柄）。
  Future<void> moveFurniture(
    int index,
    double x,
    double y, {
    int? rotation,
    double? scale,
  }) async {
    if (index < 0 || index >= _profile.furniture.length) return;
    final list = List<PetFurniture>.from(_profile.furniture);
    final old = list[index];
    list[index] = old.copyWith(
      x: x.clamp(0.08, 0.92),
      y: y.clamp(0.18, 0.92),
      rotation: rotation ?? old.rotation,
      scale: (scale ?? old.scale).clamp(0.35, 2.2),
    );
    _profile = _profile.copyWith(furniture: list);
    notifyListeners();
    await _persist();
    _scheduleFurnitureServerSync();
  }

  Future<void> rotateFurniture(int index) async {
    if (index < 0 || index >= _profile.furniture.length) return;
    final old = _profile.furniture[index];
    await moveFurniture(
      index,
      old.x,
      old.y,
      rotation: (old.rotation + 90) % 360,
    );
    _flashMessage('已旋转 90°');
  }

  Future<void> removeFurniture(int index) async {
    if (index < 0 || index >= _profile.furniture.length) return;
    final list = List<PetFurniture>.from(_profile.furniture)..removeAt(index);
    await _apply(null, _profile.copyWith(furniture: list));
    _flashMessage('已移除家具');
    _scheduleFurnitureServerSync();
  }

  Future<void> moveActor(double x, double y) async {
    _profile = _profile.copyWith(
      actorX: x.clamp(0.12, 0.88),
      actorY: y.clamp(0.35, 0.88),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> saveRoomBoundaries(List<PetRoomBoundary> boundaries) async {
    final clean = PetRoomBoundary.sanitize(boundaries);
    _profile = _profile.copyWith(roomBoundaries: clean);
    notifyListeners();
    await _persist();
    _boundarySyncTimer?.cancel();
    _boundarySyncTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_syncRoomBoundariesToServer(clean));
    });
  }

  Future<void> _syncRoomBoundariesToServer(List<PetRoomBoundary> clean) async {
    final remote = await _service.saveRoomBoundaries(clean);
    if (remote == null) return;
    _syncStatus = PetSyncStatus.cloudSynced;
    // 拖墙期间本地可能已再改；只更新同步状态，避免用旧回写打断手感。
    if (!_boundaryListEquals(_profile.roomBoundaries, clean)) {
      await _persist();
      return;
    }
    final remoteBounds = remote.roomBoundaries;
    if (_boundaryListEquals(_profile.roomBoundaries, remoteBounds)) {
      await _persist();
      return;
    }
    _profile = remote.copyWith(
      furniture: _profile.furniture,
      roomBoundaries: remoteBounds,
      actorX: _profile.actorX,
      actorY: _profile.actorY,
      wearLayout: _profile.wearLayout,
    );
    notifyListeners();
    await _persist();
  }

  bool _boundaryListEquals(List<PetRoomBoundary> a, List<PetRoomBoundary> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.scene != y.scene ||
          (x.x - y.x).abs() > 0.0001 ||
          (x.y - y.y).abs() > 0.0001 ||
          (x.width - y.width).abs() > 0.0001 ||
          (x.height - y.height).abs() > 0.0001) {
        return false;
      }
    }
    return true;
  }

  Future<void> study(String subject) async {
    final cfg = await PetCareerConfig.load();
    if (_profile.ageYears < cfg.minSchoolAge) {
      _flashMessage('满 ${cfg.minSchoolAge} 岁才能上学');
      return;
    }
    final remote = await _service.study(subject);
    if (remote.profile != null) {
      _flashMessage(remote.message);
      await _apply(remote.profile, _profile);
      return;
    }
    if (_profile.energy < 15) {
      _flashMessage('太累了，先休息');
      return;
    }
    PetSubject? sub;
    for (final s in cfg.subjects) {
      if (s.id == subject) {
        sub = s;
        break;
      }
    }
    final gain = sub?.gain ?? 3;
    final label = sub?.name ?? subject;
    var p = _profile.copyWith(energy: _profile.energy - 12);
    switch (subject) {
      case 'virtue':
        p = p.copyWith(virtue: p.virtue + gain);
        break;
      case 'intel':
        p = p.copyWith(intel: p.intel + gain);
        break;
      case 'sport':
        p = p.copyWith(sport: p.sport + gain);
        break;
      case 'art':
        p = p.copyWith(art: p.art + gain);
        break;
      case 'labor':
        p = p.copyWith(labor: p.labor + gain);
        break;
    }
    _flashMessage('$label课 +$gain');
    await _apply(null, p);
  }

  Future<void> work({String jobId = 'clerk'}) async {
    final cfg = await PetCareerConfig.load();
    final remote = await _service.work();
    if (remote.profile != null) {
      _flashMessage(remote.message);
      await _apply(remote.profile, _profile);
      return;
    }
    if (_profile.ageYears < cfg.minWorkAge) {
      _flashMessage('满 ${cfg.minWorkAge} 岁才能打工');
      return;
    }
    PetJob? job;
    for (final j in cfg.jobs) {
      if (j.id == jobId) {
        job = j;
        break;
      }
    }
    job ??= cfg.jobs.isNotEmpty ? cfg.jobs.first : null;
    final minAvg = job?.minAvgStat ?? 15;
    final basePay = job?.basePay ?? 20;
    final avg = (_profile.virtue +
            _profile.intel +
            _profile.sport +
            _profile.art +
            _profile.labor) ~/
        5;
    if (avg < minAvg) {
      _flashMessage('能力不足，先去上学');
      return;
    }
    if (_profile.energy < 20) {
      _flashMessage('太累了');
      return;
    }
    final pay = basePay + avg;
    await _apply(
      null,
      _profile.copyWith(
        coins: _profile.coins + pay,
        energy: _profile.energy - 18,
        hunger: math.max(0, _profile.hunger - 8),
      ),
    );
    _flashMessage('${job?.name ?? '打工'}赚到 $pay 币');
  }

  Future<void> ageUp() async {
    final remote = await _service.ageUp();
    await _apply(remote, _profile.copyWith(ageYears: _profile.ageYears + 1));
    _flashMessage('长大一岁！现在 ${_profile.ageYears} 岁');
  }

  Future<void> addFriend(String id) async {
    final ok = await _service.addFriend(id);
    final list = {..._profile.friends, id}.toList();
    await _apply(ok ? null : null, _profile.copyWith(friends: list));
    // always local merge
    _profile = _profile.copyWith(friends: list);
    await _persist();
    _flashMessage('已添加好友 $id');
  }

  Future<void> marry(String spouseId) async {
    final cfg = await PetCareerConfig.load();
    if (_profile.ageYears < cfg.minMarryAge) {
      _flashMessage('满 ${cfg.minMarryAge} 岁才能结婚');
      return;
    }
    final remote = await _service.marry(spouseId);
    await _apply(remote, _profile.copyWith(spouseId: spouseId));
    _flashMessage('结婚成功！');
  }

  Future<void> haveBaby() async {
    if (_profile.spouseId.isEmpty) {
      _flashMessage('需要先结婚');
      return;
    }
    final remote = await _service.baby();
    await _apply(
      remote,
      _profile.copyWith(
        hasBaby: true,
        coins: math.max(0, _profile.coins - 50),
      ),
    );
    _flashMessage('家里添丁啦！');
  }

  /// 小院试炼结算。
  ///
  /// [forcedWin] 与舞台演出结果对齐，避免 UI 判胜但本地再掷一次。
  /// 返回是否完成结算（精力不足时为 false）。
  Future<bool> adventure({bool? forcedWin}) async {
    if (_profile.energy < 25) {
      _flashMessage('精力不足，先喂食或睡觉再出发');
      return false;
    }
    final remote = await _service.adventure();
    if (remote.profile != null) {
      _flashMessage(remote.message.isEmpty
          ? (remote.win ? '胜利！' : '惜败，休息后再来')
          : remote.message);
      await _apply(remote.profile, _profile);
      return true;
    }
    final power = _profile.sport + _profile.labor + (_profile.mood ~/ 10);
    final win = forcedWin ?? power >= 28;
    if (win) {
      final gain = 30 + _profile.sport;
      await _apply(
        null,
        _profile.copyWith(
          energy: math.max(0, _profile.energy - 20),
          coins: _profile.coins + gain,
          mood: math.min(100, _profile.mood + 8),
        ),
      );
      _flashMessage('胜利！+$gain 币');
    } else {
      await _apply(
        null,
        _profile.copyWith(
          energy: math.max(0, _profile.energy - 20),
          mood: math.max(0, _profile.mood - 6),
        ),
      );
      _flashMessage('惜败，休息后再来');
    }
    return true;
  }

  /// 连击小奖励：连击 ≥3 时额外心情（纯本地 Juice）。
  Future<void> juiceComboBonus(int streak) async {
    if (streak < 3) return;
    final bonus = math.min(6, 2 + (streak - 3));
    await _apply(
      null,
      _profile.copyWith(mood: math.min(100, _profile.mood + bonus)),
    );
    _flashMessage('连击×$streak！心情+$bonus');
  }

  Future<void> buySoft(String itemId) async {
    final remote = await _service.buy(itemId);
    if (remote != null) {
      _flashMessage('购买成功');
      await _apply(remote, _profile, preferRemoteFurniture: true);
      return;
    }
    const price = 40;
    if (_profile.coins < price) {
      _flashMessage('硬币不足');
      return;
    }
    var p = _profile.copyWith(coins: _profile.coins - price);
    if (itemId.startsWith('hat_')) {
      p = p.copyWith(hatId: itemId);
    } else if (itemId.startsWith('top_')) {
      p = p.copyWith(topId: itemId);
    } else {
      if (!PetContentCatalog.furnitureAllowedInScene(itemId, p.sceneId)) {
        _flashMessage('这件家具不能放在当前场景');
        return;
      }
      p = p.copyWith(
        furniture: [
          ...p.furniture,
          PetFurniture(id: itemId, x: 0.4, y: 0.65, scene: p.sceneId),
        ],
      );
    }
    _flashMessage('花 $price 币买下了');
    await _apply(null, p);
  }

  /// P4：真钱内购占位（当前用软通货模拟「去广告礼包」）。
  Future<void> purchaseIapPlaceholder() async {
    await buySoft('hat_vip_star');
    _flashMessage('内购占位：已用软通货模拟礼包（真钱需商店配置）');
  }
}
