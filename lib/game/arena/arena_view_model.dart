import 'dart:math';

import 'package:flutter/foundation.dart';

enum ArenaView {
  lobby,
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
}

class ArenaCard {
  const ArenaCard({
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    required this.damage,
  });

  final String name;
  final String description;
  final int cost;
  final String icon;
  final int color;
  final int damage;
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

class ArenaViewModel extends ChangeNotifier {
  ArenaViewModel({Random? random}) : _random = random ?? Random() {
    _ownedHeroIds.addAll(heroes.take(3).map((hero) => hero.id));
  }

  static const int singleSummonCost = 300;
  static const int tenSummonCost = 2700;

  final Random _random;

  ArenaView _view = ArenaView.lobby;
  int _selectedHero = 0;
  int _energy = 6;
  int _playerHp = 100;
  int _enemyHp = 100;
  int _turn = 1;
  int _combo = 0;
  int _lastPlayedCardIndex = -1;
  bool _finished = false;
  bool _won = false;
  int _starCrystals = 6280;
  String _battleMessage = '选择一张技能卡开始战斗';
  String _summonMessage = '十连召唤 9 折，并至少出现 1 名 SR 以上英雄。';
  final Set<String> _ownedHeroIds = <String>{};
  final Map<String, int> _heroShards = <String, int>{};
  final List<ArenaSummonResult> _summonResults = <ArenaSummonResult>[];

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
  ];

  final cards = const [
    ArenaCard(
      name: '星潮回响',
      description: '伤害后排并减费',
      cost: 2,
      icon: '✦',
      color: 0xFF69CFE3,
      damage: 26,
    ),
    ArenaCard(
      name: '星愿守护',
      description: '全队恢复生命',
      cost: 1,
      icon: '◇',
      color: 0xFFB08BD1,
      damage: -18,
    ),
    ArenaCard(
      name: '月霜箭',
      description: '造成伤害并虚弱',
      cost: 3,
      icon: '❄',
      color: 0xFF79B9B0,
      damage: 36,
    ),
    ArenaCard(
      name: '流光合击',
      description: '连携造成大量伤害',
      cost: 2,
      icon: '☾',
      color: 0xFFD47E9B,
      damage: 30,
    ),
  ];

  ArenaView get view => _view;
  int get selectedHero => _selectedHero;
  int get energy => _energy;
  int get playerHp => _playerHp;
  int get enemyHp => _enemyHp;
  int get turn => _turn;
  int get combo => _combo;
  int get lastPlayedCardIndex => _lastPlayedCardIndex;
  bool get finished => _finished;
  bool get won => _won;
  int get starCrystals => _starCrystals;
  String get battleMessage => _battleMessage;
  String get summonMessage => _summonMessage;
  List<ArenaSummonResult> get summonResults =>
      List.unmodifiable(_summonResults);
  ArenaHero get activeHero => heroes[_selectedHero];
  List<ArenaHero> get ownedHeroes =>
      heroes.where((hero) => _ownedHeroIds.contains(hero.id)).toList();
  int get ownedCount => _ownedHeroIds.length;
  int get teamPower =>
      ownedHeroes.take(3).fold(0, (sum, hero) => sum + hero.power);

  bool isOwned(ArenaHero hero) => _ownedHeroIds.contains(hero.id);

  int shardsOf(ArenaHero hero) => _heroShards[hero.id] ?? 0;

  void navigate(ArenaView view) {
    _view = view;
    notifyListeners();
  }

  void selectHero(int index) {
    if (index < 0 || index >= heroes.length) return;
    _selectedHero = index;
    notifyListeners();
  }

  bool summon(int count) {
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

    final newCount = _summonResults.where((result) => result.isNew).length;
    final shards =
        _summonResults.fold<int>(0, (sum, result) => sum + result.shards);
    _summonMessage = newCount > 0
        ? '获得 $newCount 名新英雄，重复角色转化为 $shards 个碎片。'
        : '本次获得 $shards 个英雄碎片。';
    notifyListeners();
    return true;
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
    _energy = 6;
    _playerHp = 100;
    _enemyHp = 100;
    _turn = 1;
    _combo = 0;
    _lastPlayedCardIndex = -1;
    _finished = false;
    _won = false;
    _battleMessage = '选择一张技能卡开始战斗';
    notifyListeners();
  }

  void playCard(int index) {
    if (_finished || index < 0 || index >= cards.length) return;
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
      _playerHp = (_playerHp - card.damage).clamp(0, 100);
      _battleMessage = '${card.name}：全队恢复 ${-card.damage} 点生命';
    } else {
      _enemyHp = (_enemyHp - card.damage).clamp(0, 100);
      _battleMessage = '${card.name}：造成 ${card.damage} 点伤害';
    }
    if (_enemyHp <= 0) {
      _finished = true;
      _won = true;
      _battleMessage = '胜利！获得星砂与英雄碎片';
    }
    notifyListeners();
  }

  void endTurn() {
    if (_finished) return;
    _playerHp = (_playerHp - (8 + _turn * 2)).clamp(0, 100);
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
}
