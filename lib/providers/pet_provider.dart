import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_state.dart';
import '../services/pet_career_config.dart';
import '../services/pet_service.dart';
import '../game/pet/pet_content_registry.dart';

/// 养成状态：优先 API，失败本地持久化（保证可完整体验）。
class PetProvider extends ChangeNotifier {
  PetProvider({PetService? service}) : _service = service ?? PetService();

  static const _prefsKey = 'pet_life_sim_profile_v1';
  static const _msgHold = Duration(seconds: 2);

  final PetService _service;
  PetProfile _profile = PetProfile.fresh();
  String? _lastMessage;
  bool _busy = false;
  bool _loaded = false;
  Timer? _msgTimer;

  PetProfile get profile => _profile;
  String? get lastMessage => _lastMessage;
  bool get busy => _busy;
  bool get loaded => _loaded;

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
    // P1：统一 manifest 只读加载；缺失时静默 legacy 路径。
    unawaited(PetContentRegistry.loadIfPresent());
    final remote = await _service.fetchState();
    if (remote != null) {
      _profile = remote.copyWith(
        furniture: PetFurniture.sanitize(remote.furniture),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _profile = PetProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } else {
        _profile = PetProfile.fresh();
      }
    }
    // 清理历史刷爆的家具
    final cleaned = PetFurniture.sanitize(_profile.furniture);
    if (cleaned.length != _profile.furniture.length) {
      _profile = _profile.copyWith(furniture: cleaned);
      _flashMessage('已整理超量家具');
    }
    _loaded = true;
    _busy = false;
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
  }

  /// 本地落盘后异步写库（失败不影响本地布置）。
  Future<void> _syncFurnitureToServer() async {
    final remote = await _service.saveFurniture(_profile.furniture);
    if (remote == null) return;
    // 保留本地 actor 坐标与穿着；家具以服务端回写为准（已 sanitize）。
    final slots = PetFurniture.sanitize(
      remote.furniture.isNotEmpty ? remote.furniture : _profile.furniture,
    );
    // 若服务端只回 furniture_json 字符串，fromJson 已解析；空则保持本地。
    if (slots.isNotEmpty || _profile.furniture.isEmpty) {
      _profile = _profile.copyWith(furniture: slots.isEmpty ? _profile.furniture : slots);
      await _persist();
    }
  }

  Future<void> _apply(PetProfile? remote, PetProfile local) async {
    _profile = remote ?? local;
    _busy = false;
    notifyListeners();
    await _persist();
  }

  Future<void> feed() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    final remote = await _service.feed();
    final local = _profile.copyWith(
      hunger: math.min(100, _profile.hunger + 18),
      mood: math.min(100, _profile.mood + 4),
    );
    _flashMessage('好好吃！');
    await _apply(remote, local);
  }

  Future<void> care() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    final remote = await _service.care();
    final local = _profile.copyWith(
      mood: math.min(100, _profile.mood + 14),
      energy: math.min(100, _profile.energy + 6),
    );
    _flashMessage('最喜欢你了～');
    await _apply(remote, local);
  }

  Future<void> setScene(String scene) async {
    final remote = await _service.setScene(scene);
    await _apply(remote, _profile.copyWith(sceneId: scene));
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
    final sameId =
        sceneItems.where((f) => f.id == item.id).length;
    if (sameId >= PetFurniture.maxSameIdPerScene) {
      _flashMessage(
        '「同款」最多 ${PetFurniture.maxSameIdPerScene} 件，请先调整已有摆件',
      );
      return;
    }
    // 自动错开落点，避免叠在同一坐标。
    final offset = sameId * 0.06;
    final placed = item.copyWith(
      x: (item.x + offset).clamp(0.08, 0.92),
      y: (item.y + offset * 0.5).clamp(0.18, 0.92),
    );
    final next = [..._profile.furniture, placed];
    await _apply(null, _profile.copyWith(furniture: next));
    _flashMessage('已添加，可拖动 / 旋转摆放');
    await _syncFurnitureToServer();
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
    await _syncFurnitureToServer();
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
    await _syncFurnitureToServer();
  }

  Future<void> moveActor(double x, double y) async {
    _profile = _profile.copyWith(
      actorX: x.clamp(0.12, 0.88),
      actorY: y.clamp(0.35, 0.88),
    );
    notifyListeners();
    await _persist();
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

  Future<void> adventure() async {
    final remote = await _service.adventure();
    if (remote.profile != null) {
      _flashMessage(remote.message);
      await _apply(remote.profile, _profile);
      return;
    }
    if (_profile.energy < 25) {
      _flashMessage('精力不足');
      return;
    }
    final power = _profile.sport + _profile.labor + (_profile.mood ~/ 10);
    final win = power >= 28;
    if (win) {
      final gain = 30 + _profile.sport;
      await _apply(
        null,
        _profile.copyWith(
          energy: _profile.energy - 20,
          coins: _profile.coins + gain,
          mood: math.min(100, _profile.mood + 8),
        ),
      );
      _flashMessage('胜利！+$gain 币');
    } else {
      await _apply(
        null,
        _profile.copyWith(
          energy: _profile.energy - 20,
          mood: math.max(0, _profile.mood - 6),
        ),
      );
      _flashMessage('惜败，休息后再来');
    }
  }

  Future<void> buySoft(String itemId) async {
    final remote = await _service.buy(itemId);
    if (remote != null) {
      _flashMessage('购买成功');
      await _apply(remote, _profile);
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
