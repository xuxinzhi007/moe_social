import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/arena_state.dart';
import '../../services/arena_service.dart';

enum ArenaView {
  lobby,
  home,
  formation,
  tower,
  summon,
  collection,
  character,
  battle
}

enum ArenaRarity {
  r,
  sr,
  ssr,
}

enum ArenaCardTargeting {
  singleEnemy,
  allEnemies,
  allyTeam,
}

extension ArenaRarityLabel on ArenaRarity {
  String get label {
    switch (this) {
      case ArenaRarity.r:
        return 'R';
      case ArenaRarity.sr:
        return 'SR';
      case ArenaRarity.ssr:
        return 'SSR';
    }
  }

  int get shardValue {
    switch (this) {
      case ArenaRarity.r:
        return 8;
      case ArenaRarity.sr:
        return 18;
      case ArenaRarity.ssr:
        return 40;
    }
  }
}

class ArenaHeroSkin {
  const ArenaHeroSkin({
    required this.id,
    required this.name,
    this.imageAsset,
    this.tint,
  });

  final String id;
  final String name;

  /// 整卡立绘资源；空则走色块占位。
  final String? imageAsset;

  /// 可选色调，用于同一资源做出第二套皮肤观感（异色）。
  final int? tint;
}

class ArenaHero {
  const ArenaHero({
    required this.id,
    required this.name,
    required this.title,
    required this.role,
    required this.faction,
    required this.rarity,
    required this.color,
    required this.level,
    required this.stars,
    required this.power,
    required this.favorite,
    required this.skillName,
    required this.skillDescription,
    this.imageAsset,
    this.skins = const [],
  });

  final String id;
  final String name;
  final String title;
  final String role;
  final String faction;
  final ArenaRarity rarity;
  final int color;
  final int level;
  final int stars;
  final int power;
  final int favorite;
  final String skillName;
  final String skillDescription;
  final String? imageAsset;
  final List<ArenaHeroSkin> skins;

  /// 可切换皮肤列表；未显式配置时用 [imageAsset] 生成「经典」。
  List<ArenaHeroSkin> get resolvedSkins {
    if (skins.isNotEmpty) return skins;
    return [
      ArenaHeroSkin(id: 'classic', name: '经典', imageAsset: imageAsset),
    ];
  }
}

class ArenaCard {
  const ArenaCard({
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    required this.damage,
    this.sourceHeroId,
    this.sourceHeroName = '队伍',
    this.targeting = ArenaCardTargeting.singleEnemy,
  });

  final String name;
  final String description;
  final int cost;
  final String icon;
  final int color;
  final int damage;
  final String? sourceHeroId;
  final String sourceHeroName;
  final ArenaCardTargeting targeting;
}

class ArenaSummonResult {
  const ArenaSummonResult({
    required this.hero,
    required this.isNew,
    required this.shards,
  });

  final ArenaHero hero;
  final bool isNew;
  final int shards;
}

class ArenaTowerNode {
  const ArenaTowerNode({
    required this.label,
    required this.kind,
    required this.description,
  });

  final String label;
  final String kind;
  final String description;
}

class ArenaViewModel extends ChangeNotifier {
  ArenaViewModel({
    Random? random,
    ArenaView initialView = ArenaView.lobby,
    ArenaService? service,
  })  : _random = random ?? Random(),
        _service = service ?? ArenaService(),
        _view = initialView {
    _ownedHeroIds.addAll(heroes.take(3).map((hero) => hero.id));
    _deck.addAll(_cardsForFormation());
  }

  static const int singleSummonCost = 300;
  static const int tenSummonCost = 2700;
  static const int formationSize = 3;
  static const int enemyCount = 3;
  static const int enemyMaxHp = 100;
  static const int towerClearReward = 120;
  static const int towerWinShardBonus = 4;
  static const int homeGiftCost = 80;
  static const int homeGiftBondGain = 5;
  static const int homeRestHpBonus = 5;
  static const int homeBondEnergyBonus = 1;
  static const String _localPrefsKey = 'arena_progress_v1';

  final Random _random;
  final ArenaService _service;
  bool _cloudSynced = false;
  bool _hydrating = false;

  bool get cloudSynced => _cloudSynced;
  bool get hydrating => _hydrating;

  ArenaView _view;
  int _selectedHero = 0;
  int _selectedFormationSlot = 0;
  int _energy = 6;
  int _playerHp = 100;
  int _playerMaxHp = 100;
  int _selectedEnemyIndex = 0;
  int _turn = 1;
  int _combo = 0;
  int _lastPlayedCardIndex = -1;
  bool _finished = false;
  bool _won = false;
  int _towerFloor = 1;
  int _selectedTowerNode = 2;
  int _starCrystals = 6280;
  String _battleMessage = '选择一张技能卡开始战斗';
  String _summonMessage = '十连召唤 9 折，并至少出现 1 名 SR 以上英雄。';
  String _homeMessage = '完成小家日常后，远征会获得初始生命与能量加成。';
  bool _restBuffReady = false;
  bool _bondBuffReady = false;
  final Set<String> _ownedHeroIds = <String>{};
  final Map<String, int> _heroShards = <String, int>{};
  final Map<String, int> _heroBondBonus = <String, int>{};
  final Map<String, int> _heroLevels = <String, int>{};
  final Map<String, int> _heroStars = <String, int>{};
  final Map<String, int> _heroPowers = <String, int>{};
  final Map<String, int> _heroFavorites = <String, int>{};
  final Map<String, String> _heroSkinIds = <String, String>{};
  final List<ArenaSummonResult> _summonResults = <ArenaSummonResult>[];
  final List<String> _formationHeroIds = <String>[
    'lanxing',
    'tutu',
    'maoying',
  ];
  final List<int> _enemyHps = List<int>.filled(enemyCount, enemyMaxHp);
  final List<ArenaCard> _deck = <ArenaCard>[];
  final List<ArenaCard> _rewardChoices = <ArenaCard>[];
  Timer? _formationSaveTimer;
  Timer? _metaSaveTimer;

  final heroes = const [
    ArenaHero(
      id: 'lanxing',
      name: '澜星',
      title: '晨潮星术士',
      role: '法师',
      faction: '潮汐',
      rarity: ArenaRarity.ssr,
      color: 0xFF69CFE3,
      level: 42,
      stars: 3,
      power: 19600,
      favorite: 72,
      skillName: '星潮回响',
      skillDescription: '对敌方后排造成魔法伤害，并为手牌中费用最高的技能减 1 费。',
      imageAsset: 'assets/arena/heroes/lanxing_001.jpg',
      skins: [
        ArenaHeroSkin(
          id: 'classic',
          name: '经典',
          imageAsset: 'assets/arena/heroes/lanxing_001.jpg',
        ),
        ArenaHeroSkin(
          id: 'starlight',
          name: '星辉誓约',
          imageAsset: 'assets/arena/heroes/lanxing_001.jpg',
          tint: 0xFFB8A0E8,
        ),
      ],
    ),
    ArenaHero(
      id: 'tutu',
      name: '兔突',
      title: '星辉剑士',
      role: '剑士',
      faction: '森林',
      rarity: ArenaRarity.ssr,
      color: 0xFFB88BCE,
      level: 38,
      stars: 3,
      power: 17200,
      favorite: 64,
      skillName: '闪耀突刺',
      skillDescription: '攻击敌方前排，若目标带有破甲则追加一次追击。',
    ),
    ArenaHero(
      id: 'maoying',
      name: '猫影',
      title: '月霜游侠',
      role: '射手',
      faction: '潮汐',
      rarity: ArenaRarity.sr,
      color: 0xFF82B8C7,
      level: 36,
      stars: 2,
      power: 14600,
      favorite: 52,
      skillName: '月霜箭',
      skillDescription: '造成单体伤害，并使目标下回合伤害降低。',
    ),
    ArenaHero(
      id: 'huhuo',
      name: '狐火',
      title: '焰纹导师',
      role: '法师',
      faction: '星辉',
      rarity: ArenaRarity.sr,
      color: 0xFFE79AB0,
      level: 34,
      stars: 2,
      power: 13900,
      favorite: 58,
      skillName: '狐火连印',
      skillDescription: '对一名敌人造成魔法伤害，并追加灼烧。',
    ),
    ArenaHero(
      id: 'linglan',
      name: '铃兰',
      title: '晨祷药师',
      role: '辅助',
      faction: '星辉',
      rarity: ArenaRarity.sr,
      color: 0xFFF0C878,
      level: 30,
      stars: 1,
      power: 10100,
      favorite: 41,
      skillName: '星愿守护',
      skillDescription: '恢复全队生命，并为前排添加一层护盾。',
    ),
    ArenaHero(
      id: 'yuebai',
      name: '月白',
      title: '银月骑士',
      role: '守卫',
      faction: '圣庭',
      rarity: ArenaRarity.r,
      color: 0xFFA7B7D8,
      level: 28,
      stars: 1,
      power: 9200,
      favorite: 36,
      skillName: '银盾誓约',
      skillDescription: '嘲讽前排敌人，并降低本回合受到的伤害。',
    ),
    ArenaHero(
      id: 'taoyin',
      name: '桃音',
      title: '花庭祈愿者',
      role: '辅助',
      faction: '森林',
      rarity: ArenaRarity.sr,
      color: 0xFFEFA8C8,
      level: 32,
      stars: 2,
      power: 12400,
      favorite: 46,
      skillName: '花语治愈',
      skillDescription: '为全队恢复生命，并提高下一张队伍技能的连携收益。',
      imageAsset: 'assets/arena/heroes/taoyin_001.jpg',
      skins: [
        ArenaHeroSkin(
          id: 'classic',
          name: '经典',
          imageAsset: 'assets/arena/heroes/taoyin_001.jpg',
        ),
        ArenaHeroSkin(
          id: 'blossom',
          name: '花庭夜宴',
          imageAsset: 'assets/arena/heroes/taoyin_001.jpg',
          tint: 0xFFFFB0D0,
        ),
      ],
    ),
    ArenaHero(
      id: 'xueli',
      name: '雪璃',
      title: '冰庭星使',
      role: '法师',
      faction: '圣庭',
      rarity: ArenaRarity.ssr,
      color: 0xFF9EC6EA,
      level: 40,
      stars: 3,
      power: 18800,
      favorite: 66,
      skillName: '霜晶星河',
      skillDescription: '对全体敌人造成冰霜伤害，并优先压低生命最高的目标。',
      imageAsset: 'assets/arena/heroes/xueli_001.jpg',
      skins: [
        ArenaHeroSkin(
          id: 'classic',
          name: '经典',
          imageAsset: 'assets/arena/heroes/xueli_001.jpg',
        ),
        ArenaHeroSkin(
          id: 'frost',
          name: '霜夜圣咏',
          imageAsset: 'assets/arena/heroes/xueli_001.jpg',
          tint: 0xFFA0D0FF,
        ),
      ],
    ),
    ArenaHero(
      id: 'ziyuan',
      name: '紫鸢',
      title: '秘仪占星师',
      role: '法师',
      faction: '星辉',
      rarity: ArenaRarity.sr,
      color: 0xFFB8A0E6,
      level: 35,
      stars: 2,
      power: 15100,
      favorite: 55,
      skillName: '星轨秘仪',
      skillDescription: '对单体敌人造成魔法伤害；若目标生命低于一半，伤害提高。',
      imageAsset: 'assets/arena/heroes/ziyuan_001.jpg',
      skins: [
        ArenaHeroSkin(
          id: 'classic',
          name: '经典',
          imageAsset: 'assets/arena/heroes/ziyuan_001.jpg',
        ),
        ArenaHeroSkin(
          id: 'oracle',
          name: '秘仪紫夜',
          imageAsset: 'assets/arena/heroes/ziyuan_001.jpg',
          tint: 0xFFD0B0FF,
        ),
      ],
    ),
  ];

  static const List<ArenaCard> _rewardPool = [
    ArenaCard(
      name: '潮涌连弹',
      description: '低费连携伤害',
      cost: 1,
      icon: '✧',
      color: 0xFF69CFE3,
      damage: 18,
      sourceHeroName: '肉鸽',
    ),
    ArenaCard(
      name: '星砂爆裂',
      description: '高伤害终结技',
      cost: 3,
      icon: '✹',
      color: 0xFFE6B64F,
      damage: 42,
      sourceHeroName: '肉鸽',
    ),
    ArenaCard(
      name: '月幕庇护',
      description: '恢复并稳住血线',
      cost: 2,
      icon: '☽',
      color: 0xFFB08BD1,
      damage: -24,
      sourceHeroName: '肉鸽',
      targeting: ArenaCardTargeting.allyTeam,
    ),
    ArenaCard(
      name: '霜痕追击',
      description: '中费稳定输出',
      cost: 2,
      icon: '❄',
      color: 0xFF79B9B0,
      damage: 30,
      sourceHeroName: '肉鸽',
    ),
    ArenaCard(
      name: '流星裁断',
      description: '全体爆发伤害',
      cost: 4,
      icon: '✦',
      color: 0xFFD47E9B,
      damage: 32,
      sourceHeroName: '肉鸽',
      targeting: ArenaCardTargeting.allEnemies,
    ),
  ];

  static const List<ArenaTowerNode> towerNodes = [
    ArenaTowerNode(
      label: '战斗',
      kind: '普通战',
      description: '进入一场基础战斗，胜利后可选择 1 张技能牌。',
    ),
    ArenaTowerNode(
      label: '休息',
      kind: '恢复点',
      description: '后续会用于恢复生命或升级一张技能牌。',
    ),
    ArenaTowerNode(
      label: '精英',
      kind: '高风险战',
      description: '更强敌人，奖励也更好。当前原型先进入普通战斗。',
    ),
    ArenaTowerNode(
      label: '商店',
      kind: '补给',
      description: '后续会用于购买技能牌、碎片或一次性道具。',
    ),
    ArenaTowerNode(
      label: '首领',
      kind: 'Boss',
      description: '章节终点。需要稳定构筑后再挑战。',
    ),
  ];

  ArenaView get view => _view;
  int get selectedHero => _selectedHero;
  int get selectedFormationSlot => _selectedFormationSlot;
  int get energy => _energy;
  int get playerHp => _playerHp;
  int get playerMaxHp => _playerMaxHp;
  int get enemyHp {
    final total = _enemyHps.fold<int>(0, (sum, hp) => sum + hp);
    return (total / (enemyCount * enemyMaxHp) * 100).round();
  }

  int get selectedEnemyIndex => _selectedEnemyIndex;
  int get turn => _turn;
  int get combo => _combo;
  int get lastPlayedCardIndex => _lastPlayedCardIndex;
  bool get finished => _finished;
  bool get won => _won;
  int get towerFloor => _towerFloor;
  int get selectedTowerNodeIndex => _selectedTowerNode;
  ArenaTowerNode get selectedTowerNode => towerNodes[_selectedTowerNode];
  int get starCrystals => _starCrystals;
  String get battleMessage => _battleMessage;
  String get battleObjective =>
      allEnemiesDefeated ? '目标：清场完成' : '目标：敌影 ${_selectedEnemyIndex + 1}';
  String get enemyIntent =>
      '敌意图：敌影 ${_selectedEnemyIndex + 1} 回合末 -${8 + _turn * 2}';
  String get summonMessage => _summonMessage;
  String get homeMessage => _homeMessage;
  bool get restBuffReady => _restBuffReady;
  bool get bondBuffReady => _bondBuffReady;
  List<ArenaCard> get cards => List.unmodifiable(_deck);
  List<ArenaCard> get rewardChoices => List.unmodifiable(_rewardChoices);
  bool get hasPendingReward => _rewardChoices.isNotEmpty;
  List<ArenaSummonResult> get summonResults =>
      List.unmodifiable(_summonResults);
  ArenaHero get activeHero => heroes[_selectedHero];
  List<ArenaHero> get ownedHeroes =>
      heroes.where((hero) => _ownedHeroIds.contains(hero.id)).toList();
  List<ArenaHero> get formationHeroes {
    final formation = <ArenaHero>[];
    for (final heroId in _formationHeroIds) {
      final hero = _heroById(heroId);
      if (hero != null && isOwned(hero)) {
        formation.add(hero);
      }
    }
    return formation;
  }

  int get ownedCount => _ownedHeroIds.length;
  int get teamPower =>
      formationHeroes.fold(0, (sum, hero) => sum + powerOf(hero));
  bool get allEnemiesDefeated => _enemyHps.every((hp) => hp <= 0);

  bool isOwned(ArenaHero hero) => _ownedHeroIds.contains(hero.id);

  int shardsOf(ArenaHero hero) => _heroShards[hero.id] ?? 0;

  int levelOf(ArenaHero hero) => _heroLevels[hero.id] ?? hero.level;

  int starsOf(ArenaHero hero) => _heroStars[hero.id] ?? hero.stars;

  int powerOf(ArenaHero hero) => _heroPowers[hero.id] ?? hero.power;

  int favoriteOf(ArenaHero hero) => _heroFavorites[hero.id] ?? hero.favorite;

  int bondOf(ArenaHero hero) =>
      (favoriteOf(hero) + (_heroBondBonus[hero.id] ?? 0)).clamp(0, 100);

  ArenaHeroSkin skinOf(ArenaHero hero) {
    final skins = hero.resolvedSkins;
    final id = _heroSkinIds[hero.id] ?? skins.first.id;
    return skins.firstWhere((s) => s.id == id, orElse: () => skins.first);
  }

  String? portraitAssetOf(ArenaHero hero) => skinOf(hero).imageAsset;

  int? portraitTintOf(ArenaHero hero) => skinOf(hero).tint;

  /// 切换英雄整卡皮肤（非部位换装）。
  Future<void> selectHeroSkin(ArenaHero hero, String skinId) async {
    if (!isOwned(hero)) return;
    final ok = hero.resolvedSkins.any((s) => s.id == skinId);
    if (!ok) return;
    _heroSkinIds[hero.id] = skinId;
    notifyListeners();
    await _persistLocal();
    final remote = await _service.saveSkin(heroId: hero.id, skinId: skinId);
    if (remote != null) applyState(remote);
  }

  @override
  void dispose() {
    _formationSaveTimer?.cancel();
    _metaSaveTimer?.cancel();
    super.dispose();
  }

  /// 送礼：耗星晶提升活跃英雄羁绊，并准备下场能量加成（优先云端）。
  Future<bool> giftAtHome() async {
    if (_starCrystals < homeGiftCost) {
      _homeMessage = '星晶不足，送礼还差 ${homeGiftCost - _starCrystals}。';
      notifyListeners();
      return false;
    }
    final hero = activeHero;
    final remote = await _service.homeGift(hero.id);
    if (remote != null) {
      applyState(remote);
      _bondBuffReady = true;
      _cloudSynced = true;
      _homeMessage =
          '送给 ${hero.name} 一份远征小礼，好感 +$homeGiftBondGain。下场战斗初始能量 +$homeBondEnergyBonus。';
      notifyListeners();
      await _persistLocal();
      return true;
    }

    _starCrystals -= homeGiftCost;
    _heroBondBonus[hero.id] = (_heroBondBonus[hero.id] ?? 0) + homeGiftBondGain;
    _bondBuffReady = true;
    _cloudSynced = false;
    _homeMessage =
        '送给 ${hero.name} 一份远征小礼，好感 +$homeGiftBondGain。下场战斗初始能量 +$homeBondEnergyBonus。';
    notifyListeners();
    await _persistLocal();
    return true;
  }

  /// 训练/休息：准备下场生命加成（优先云端）。
  Future<void> trainAtHome() async {
    final remote = await _service.homeTrain();
    if (remote != null) {
      applyState(remote);
      _cloudSynced = true;
      _homeMessage = '${activeHero.name} 完成出征前整理，下场战斗初始生命 +$homeRestHpBonus。';
      notifyListeners();
      await _persistLocal();
      return;
    }
    _restBuffReady = true;
    _cloudSynced = false;
    _homeMessage = '${activeHero.name} 完成出征前整理，下场战斗初始生命 +$homeRestHpBonus。';
    notifyListeners();
    await _persistLocal();
  }

  ArenaTowerNode towerNodeAt(int index) => towerNodes[index];

  int enemyHpAt(int index) {
    if (index < 0 || index >= _enemyHps.length) return 0;
    return _enemyHps[index];
  }

  ArenaHero? formationHeroAt(int index) {
    if (index < 0 || index >= _formationHeroIds.length) return null;
    final hero = _heroById(_formationHeroIds[index]);
    if (hero == null || !isOwned(hero)) return null;
    return hero;
  }

  void navigate(ArenaView view) {
    _view = view;
    notifyListeners();
  }

  void selectHero(int index) {
    if (index < 0 || index >= heroes.length) return;
    _selectedHero = index;
    notifyListeners();
  }

  void selectFormationSlot(int index) {
    if (index < 0 || index >= formationSize) return;
    _selectedFormationSlot = index;
    final hero = formationHeroAt(index);
    if (hero != null) {
      _selectedHero = heroes.indexWhere((candidate) => candidate.id == hero.id);
    }
    notifyListeners();
  }

  void assignHeroToFormation(int heroIndex) {
    if (heroIndex < 0 || heroIndex >= heroes.length) return;
    final hero = heroes[heroIndex];
    if (!isOwned(hero)) return;

    final existingSlot = _formationHeroIds.indexOf(hero.id);
    if (existingSlot == _selectedFormationSlot) {
      _selectedHero = heroIndex;
      notifyListeners();
      return;
    }

    if (existingSlot >= 0) {
      final currentHeroId = _formationHeroIds[_selectedFormationSlot];
      _formationHeroIds[existingSlot] = currentHeroId;
    }
    _formationHeroIds[_selectedFormationSlot] = hero.id;
    _selectedHero = heroIndex;
    _rebuildFormationDeck();
    notifyListeners();
    _scheduleFormationSave();
  }

  void selectTowerNode(int index) {
    if (index < 0 || index >= towerNodes.length) return;
    _selectedTowerNode = index;
    notifyListeners();
    _scheduleMetaSave();
  }

  void selectEnemy(int index) {
    if (_finished || index < 0 || index >= _enemyHps.length) return;
    if (_enemyHps[index] <= 0) {
      _battleMessage = '敌影 ${index + 1} 已倒下，选择仍在场的目标';
      notifyListeners();
      return;
    }
    _selectedEnemyIndex = index;
    _battleMessage = '已锁定敌影 ${index + 1}，选择技能牌发动攻击';
    notifyListeners();
  }

  /// 优先云端拉取存档；失败读本地缓存。
  Future<void> hydrate() async {
    _hydrating = true;
    notifyListeners();
    final remote = await _service.fetchState();
    if (remote != null) {
      applyState(remote);
      _cloudSynced = true;
      await _persistLocal();
    } else {
      final local = await _loadLocal();
      if (local != null) {
        applyState(local);
      }
      _cloudSynced = false;
    }
    _hydrating = false;
    notifyListeners();
  }

  void applyState(ArenaStateDto state) {
    _starCrystals = state.starCrystals;
    _towerFloor = state.towerFloor <= 0 ? 1 : state.towerFloor;
    _restBuffReady = state.restBuffReady;
    _bondBuffReady = state.bondBuffReady;
    if (state.selectedTowerNode >= 0 &&
        state.selectedTowerNode < towerNodes.length) {
      _selectedTowerNode = state.selectedTowerNode;
    }
    _ownedHeroIds
      ..clear()
      ..addAll(state.ownedHeroes.map((hero) => hero.heroId));
    _heroShards
      ..clear()
      ..addEntries(
        state.ownedHeroes.map(
          (hero) => MapEntry(hero.heroId, hero.shards),
        ),
      );
    _heroBondBonus
      ..clear()
      ..addEntries(
        state.ownedHeroes
            .where((hero) => hero.bond > 0)
            .map((hero) => MapEntry(hero.heroId, hero.bond)),
      );
    _heroLevels.clear();
    _heroStars.clear();
    _heroPowers.clear();
    _heroFavorites.clear();
    _heroSkinIds.clear();
    for (final owned in state.ownedHeroes) {
      final base = _heroById(owned.heroId);
      _heroLevels[owned.heroId] =
          owned.level > 0 ? owned.level : (base?.level ?? 1);
      _heroStars[owned.heroId] =
          owned.stars > 0 ? owned.stars : (base?.stars ?? 1);
      _heroPowers[owned.heroId] =
          owned.power > 0 ? owned.power : (base?.power ?? 0);
      _heroFavorites[owned.heroId] =
          owned.favorite > 0 ? owned.favorite : (base?.favorite ?? 0);
      if (owned.skinId.isNotEmpty) {
        _heroSkinIds[owned.heroId] = owned.skinId;
      }
    }
    if (state.formationHeroIds.length == formationSize &&
        state.formationHeroIds.every((id) => _ownedHeroIds.contains(id))) {
      _formationHeroIds
        ..clear()
        ..addAll(state.formationHeroIds);
    }
    if (state.deck.isNotEmpty) {
      _deck
        ..clear()
        ..addAll(state.deck.map(_cardFromDto));
    } else {
      _rebuildFormationDeck();
    }
  }

  Future<bool> syncFormation() async {
    final remote = await _service.setFormation(
      List<String>.of(_formationHeroIds),
    );
    if (remote == null) {
      _cloudSynced = false;
      notifyListeners();
      await _persistLocal();
      return false;
    }
    applyState(remote);
    final deckRemote = await _service.saveDeck(_deckDtos());
    if (deckRemote != null) {
      applyState(deckRemote);
    }
    _cloudSynced = true;
    notifyListeners();
    await _persistLocal();
    return true;
  }

  Future<bool> syncDeck() async {
    final remote = await _service.saveDeck(_deckDtos());
    if (remote == null) {
      _cloudSynced = false;
      await _persistLocal();
      return false;
    }
    applyState(remote);
    _cloudSynced = true;
    notifyListeners();
    await _persistLocal();
    return true;
  }

  Future<bool> summon(int count) async {
    final cost = count == 10 ? tenSummonCost : singleSummonCost;
    if (_starCrystals < cost) {
      _summonMessage = '星晶不足，还差 ${cost - _starCrystals}。';
      notifyListeners();
      return false;
    }

    final remote = await _service.summon(count);
    if (remote != null) {
      applyState(remote.state);
      _summonResults
        ..clear()
        ..addAll(remote.pulls.map(_resultFromPull));
      _summonMessage = remote.message.isNotEmpty
          ? remote.message
          : _summonSummaryMessage(_summonResults);
      _cloudSynced = true;
      notifyListeners();
      await _persistLocal();
      return true;
    }

    return _summonLocal(count);
  }

  bool _summonLocal(int count) {
    final cost = count == 10 ? tenSummonCost : singleSummonCost;
    if (_starCrystals < cost) {
      _summonMessage = '星晶不足，还差 ${cost - _starCrystals}。';
      notifyListeners();
      return false;
    }

    _starCrystals -= cost;
    _summonResults
      ..clear()
      ..addAll(List.generate(count, _pullHero));

    if (count == 10 &&
        !_summonResults.any((result) => result.hero.rarity != ArenaRarity.r)) {
      final guaranteed = _randomHero(minRarity: ArenaRarity.sr);
      _summonResults[_summonResults.length - 1] = _recordPull(guaranteed);
    }

    _summonMessage = _summonSummaryMessage(_summonResults);
    _cloudSynced = false;
    notifyListeners();
    unawaited(_persistLocal());
    return true;
  }

  String _summonSummaryMessage(List<ArenaSummonResult> results) {
    final newCount = results.where((result) => result.isNew).length;
    final shards = results.fold<int>(0, (sum, result) => sum + result.shards);
    return newCount > 0
        ? '获得 $newCount 名新英雄，重复角色转化为 $shards 个碎片。'
        : '本次获得 $shards 个英雄碎片。';
  }

  ArenaSummonResult _resultFromPull(ArenaSummonPullDto pull) {
    final hero = _heroById(pull.heroId) ?? heroes.first;
    return ArenaSummonResult(
      hero: hero,
      isNew: pull.isNew,
      shards: pull.shards,
    );
  }

  void closeSummonResults() {
    _summonResults.clear();
    notifyListeners();
  }

  ArenaSummonResult _pullHero(int _) => _recordPull(_randomHero());

  ArenaSummonResult _recordPull(ArenaHero hero) {
    final isNew = !_ownedHeroIds.contains(hero.id);
    if (isNew) {
      _ownedHeroIds.add(hero.id);
      _heroLevels[hero.id] = hero.level;
      _heroStars[hero.id] = hero.stars;
      _heroPowers[hero.id] = hero.power;
      _heroFavorites[hero.id] = hero.favorite;
      return ArenaSummonResult(hero: hero, isNew: true, shards: 0);
    }

    final shards = hero.rarity.shardValue;
    _heroShards[hero.id] = shardsOf(hero) + shards;
    return ArenaSummonResult(hero: hero, isNew: false, shards: shards);
  }

  ArenaHero _randomHero({ArenaRarity? minRarity}) {
    final roll = _random.nextDouble();
    ArenaRarity rarity;
    if (roll < .08) {
      rarity = ArenaRarity.ssr;
    } else if (roll < .38) {
      rarity = ArenaRarity.sr;
    } else {
      rarity = ArenaRarity.r;
    }

    if (minRarity == ArenaRarity.sr && rarity == ArenaRarity.r) {
      rarity = ArenaRarity.sr;
    }

    final pool = heroes.where((hero) {
      if (rarity == ArenaRarity.ssr) return hero.rarity == ArenaRarity.ssr;
      if (rarity == ArenaRarity.sr) return hero.rarity == ArenaRarity.sr;
      return hero.rarity == ArenaRarity.r;
    }).toList();
    return pool[_random.nextInt(pool.length)];
  }

  void startBattle() {
    _view = ArenaView.battle;
    _playerMaxHp = 100;
    _energy = 6;
    final buffNotes = <String>[];
    if (_restBuffReady) {
      _playerMaxHp += homeRestHpBonus;
      _restBuffReady = false;
      buffNotes.add('休息充分 生命+$homeRestHpBonus');
    }
    if (_bondBuffReady) {
      _energy += homeBondEnergyBonus;
      _bondBuffReady = false;
      buffNotes.add('羁绊整理 能量+$homeBondEnergyBonus');
    }
    _playerHp = _playerMaxHp;
    for (var index = 0; index < _enemyHps.length; index++) {
      _enemyHps[index] = enemyMaxHp;
    }
    _selectedEnemyIndex = 0;
    _turn = 1;
    _combo = 0;
    _lastPlayedCardIndex = -1;
    _finished = false;
    _won = false;
    _rewardChoices.clear();
    final buffSuffix = buffNotes.isEmpty ? '' : ' · ${buffNotes.join(' / ')}';
    _battleMessage =
        '第 $_towerFloor 层 · ${selectedTowerNode.kind}：规划能量与连携$buffSuffix';
    notifyListeners();
    unawaited(_persistConsumedBuffs());
  }

  Future<void> _persistConsumedBuffs() async {
    final remote = await _service.saveMeta(clearBuffs: true);
    if (remote != null) {
      // 只同步 buff 标记，避免开战瞬间被旧节点等覆盖观感。
      _restBuffReady = remote.restBuffReady;
      _bondBuffReady = remote.bondBuffReady;
      _cloudSynced = true;
    } else {
      _cloudSynced = false;
    }
    await _persistLocal();
  }

  void _scheduleFormationSave() {
    _formationSaveTimer?.cancel();
    _formationSaveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(syncFormation());
    });
  }

  void _scheduleMetaSave() {
    _metaSaveTimer?.cancel();
    _metaSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_syncMeta());
    });
  }

  Future<void> _syncMeta() async {
    final remote = await _service.saveMeta(
      selectedTowerNode: _selectedTowerNode,
    );
    if (remote != null) {
      applyState(remote);
      _cloudSynced = true;
      notifyListeners();
      await _persistLocal();
      return;
    }
    _cloudSynced = false;
    await _persistLocal();
  }

  void playCard(int index) {
    if (_finished || index < 0 || index >= cards.length) return;
    _selectFirstAliveEnemyIfNeeded();
    final card = cards[index];
    if (_energy < card.cost) {
      _battleMessage = '能量不足，先结束回合恢复能量';
      notifyListeners();
      return;
    }
    _lastPlayedCardIndex = index;
    _combo++;
    _energy -= card.cost;
    if (card.damage < 0) {
      _playerHp = (_playerHp - card.damage).clamp(0, _playerMaxHp);
      _battleMessage =
          '${card.sourceHeroName}发动${card.name}：全队恢复 ${-card.damage} 点生命';
    } else if (card.targeting == ArenaCardTargeting.allEnemies) {
      for (var enemyIndex = 0; enemyIndex < _enemyHps.length; enemyIndex++) {
        _enemyHps[enemyIndex] =
            (_enemyHps[enemyIndex] - card.damage).clamp(0, enemyMaxHp);
      }
      _battleMessage =
          '${card.sourceHeroName}发动${card.name}：对全体敌人造成 ${card.damage} 点伤害';
    } else {
      final target = _selectedEnemyIndex;
      _enemyHps[target] =
          (_enemyHps[target] - card.damage).clamp(0, enemyMaxHp);
      _battleMessage =
          '${card.sourceHeroName}发动${card.name}：对敌影 ${target + 1} 造成 ${card.damage} 点伤害';
    }
    if (allEnemiesDefeated) {
      _finished = true;
      _won = true;
      // 星晶/层数/碎片结算走 clearTower（云端优先），避免与服务端双计。
      _rewardChoices
        ..clear()
        ..addAll(_rollRewardChoices());
      _battleMessage = '胜利！选择 1 张技能加入本轮牌组';
    }
    _selectFirstAliveEnemyIfNeeded();
    notifyListeners();
  }

  void endTurn() {
    if (_finished) return;
    _playerHp = (_playerHp - (8 + _turn * 2)).clamp(0, _playerMaxHp);
    _energy = 6;
    _turn++;
    _combo = 0;
    _lastPlayedCardIndex = -1;
    if (_playerHp <= 0) {
      _finished = true;
      _won = false;
      _battleMessage = '队伍倒下了，调整阵容后再试一次';
    } else {
      _battleMessage = '敌方行动结束，轮到你了';
    }
    notifyListeners();
  }

  Future<void> chooseRewardCard(int index) async {
    if (index < 0 || index >= _rewardChoices.length) return;
    final card = _rewardChoices[index];
    _deck.add(card);
    _rewardChoices.clear();
    await _settleTowerWin(
      message: '获得「${card.name}」，下一层会用更强构筑继续挑战',
    );
  }

  Future<void> skipReward() async {
    if (_rewardChoices.isEmpty) return;
    _rewardChoices.clear();
    await _settleTowerWin(message: '跳过奖励，保持当前牌组进入下一层');
  }

  Future<void> _settleTowerWin({required String message}) async {
    final remote = await _service.clearTower(
      won: true,
      bonusHeroId: activeHero.id,
      deck: _deckDtos(),
    );
    if (remote != null) {
      applyState(remote.state);
      _cloudSynced = true;
      _battleMessage = message;
      notifyListeners();
      await _persistLocal();
      return;
    }
    _starCrystals += towerClearReward;
    _heroShards[activeHero.id] = shardsOf(activeHero) + towerWinShardBonus;
    _towerFloor++;
    _cloudSynced = false;
    _battleMessage = message;
    notifyListeners();
    await _persistLocal();
  }

  List<ArenaDeckCardDto> _deckDtos() =>
      _deck.map(_dtoFromCard).toList(growable: false);

  ArenaDeckCardDto _dtoFromCard(ArenaCard card) {
    return ArenaDeckCardDto(
      name: card.name,
      description: card.description,
      cost: card.cost,
      icon: card.icon,
      color: card.color,
      damage: card.damage,
      sourceHeroId: card.sourceHeroId,
      sourceHeroName: card.sourceHeroName,
      targeting: switch (card.targeting) {
        ArenaCardTargeting.allEnemies => 'all_enemies',
        ArenaCardTargeting.allyTeam => 'ally_team',
        ArenaCardTargeting.singleEnemy => 'single_enemy',
      },
    );
  }

  ArenaCard _cardFromDto(ArenaDeckCardDto dto) {
    return ArenaCard(
      name: dto.name,
      description: dto.description,
      cost: dto.cost,
      icon: dto.icon,
      color: dto.color,
      damage: dto.damage,
      sourceHeroId: dto.sourceHeroId,
      sourceHeroName: dto.sourceHeroName,
      targeting: switch (dto.targeting) {
        'all_enemies' => ArenaCardTargeting.allEnemies,
        'ally_team' => ArenaCardTargeting.allyTeam,
        _ => ArenaCardTargeting.singleEnemy,
      },
    );
  }

  ArenaStateDto _snapshot() {
    return ArenaStateDto(
      userId: '',
      starCrystals: _starCrystals,
      towerFloor: _towerFloor,
      formationHeroIds: List<String>.of(_formationHeroIds),
      ownedHeroes: _ownedHeroIds.map((id) {
        final base = _heroById(id);
        return ArenaOwnedHeroDto(
          heroId: id,
          shards: _heroShards[id] ?? 0,
          bond: _heroBondBonus[id] ?? 0,
          level: _heroLevels[id] ?? base?.level ?? 1,
          stars: _heroStars[id] ?? base?.stars ?? 1,
          power: _heroPowers[id] ?? base?.power ?? 0,
          favorite: _heroFavorites[id] ?? base?.favorite ?? 0,
          skinId: _heroSkinIds[id] ??
              (base?.resolvedSkins.isNotEmpty == true
                  ? base!.resolvedSkins.first.id
                  : 'classic'),
        );
      }).toList(),
      deck: _deckDtos(),
      restBuffReady: _restBuffReady,
      bondBuffReady: _bondBuffReady,
      selectedTowerNode: _selectedTowerNode,
    );
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localPrefsKey, jsonEncode(_snapshot().toJson()));
    } catch (_) {}
  }

  Future<ArenaStateDto?> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return ArenaStateDto.fromJson(map);
      if (map is Map) {
        return ArenaStateDto.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return null;
  }

  List<ArenaCard> _rollRewardChoices() {
    final pool = List<ArenaCard>.of(_rewardPool)..shuffle(_random);
    return pool.take(3).toList();
  }

  void _rebuildFormationDeck() {
    _deck
      ..clear()
      ..addAll(_cardsForFormation());
  }

  List<ArenaCard> _cardsForFormation() {
    final cards = <ArenaCard>[];
    for (final hero in formationHeroes) {
      cards.add(_cardForHero(hero));
    }
    cards.add(
      const ArenaCard(
        name: '流光合击',
        description: '队伍连携单体伤害',
        cost: 2,
        icon: '☾',
        color: 0xFFD47E9B,
        damage: 30,
        sourceHeroName: '队伍',
      ),
    );
    return cards;
  }

  ArenaCard _cardForHero(ArenaHero hero) {
    switch (hero.id) {
      case 'lanxing':
        return ArenaCard(
          name: hero.skillName,
          description: '单体魔法伤害',
          cost: 2,
          icon: '✦',
          color: hero.color,
          damage: 26,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
        );
      case 'tutu':
        return ArenaCard(
          name: hero.skillName,
          description: '前排爆发突击',
          cost: 2,
          icon: '⚔',
          color: hero.color,
          damage: 32,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
        );
      case 'maoying':
        return ArenaCard(
          name: hero.skillName,
          description: '单体伤害并虚弱',
          cost: 3,
          icon: '❄',
          color: hero.color,
          damage: 36,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
        );
      case 'linglan':
        return ArenaCard(
          name: hero.skillName,
          description: '全队恢复生命',
          cost: 1,
          icon: '◇',
          color: hero.color,
          damage: -18,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
          targeting: ArenaCardTargeting.allyTeam,
        );
      case 'taoyin':
        return ArenaCard(
          name: hero.skillName,
          description: '全队恢复生命',
          cost: 1,
          icon: '✿',
          color: hero.color,
          damage: -20,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
          targeting: ArenaCardTargeting.allyTeam,
        );
      case 'xueli':
        return ArenaCard(
          name: hero.skillName,
          description: '全体冰霜伤害',
          cost: 4,
          icon: '❆',
          color: hero.color,
          damage: 34,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
          targeting: ArenaCardTargeting.allEnemies,
        );
      case 'ziyuan':
        return ArenaCard(
          name: hero.skillName,
          description: '单体魔法斩杀',
          cost: 2,
          icon: '✶',
          color: hero.color,
          damage: 31,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
        );
      default:
        return ArenaCard(
          name: hero.skillName,
          description: '${hero.role}技能',
          cost: 2,
          icon: '✧',
          color: hero.color,
          damage: 28,
          sourceHeroId: hero.id,
          sourceHeroName: hero.name,
        );
    }
  }

  void _selectFirstAliveEnemyIfNeeded() {
    if (_enemyHps[_selectedEnemyIndex] > 0 || allEnemiesDefeated) return;
    final nextIndex = _enemyHps.indexWhere((hp) => hp > 0);
    if (nextIndex >= 0) {
      _selectedEnemyIndex = nextIndex;
    }
  }

  ArenaHero? _heroById(String id) {
    for (final hero in heroes) {
      if (hero.id == id) return hero;
    }
    return null;
  }
}
