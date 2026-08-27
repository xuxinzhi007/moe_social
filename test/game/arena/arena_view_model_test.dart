import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/arena/arena_view_model.dart';
import 'package:moe_social/models/arena_state.dart';
import 'package:moe_social/services/arena_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ArenaViewModel localModel({
    Random? random,
  }) {
    return ArenaViewModel(
      random: random ?? _FixedRandom(),
      service: _OfflineArenaService(),
    );
  }

  test('starts with three owned heroes and the first real portrait hero', () {
    final model = localModel();

    expect(model.ownedCount, 3);
    expect(model.heroes, hasLength(9));
    expect(model.heroes.first.name, '澜星');
    expect(
        model.heroes.first.imageAsset, 'assets/arena/heroes/lanxing_001.jpg');
    expect(model.isOwned(model.heroes.first), isTrue);
  });

  test('new grok image heroes are included in the arena roster', () {
    final model = localModel();

    expect(
      model.heroes
          .where((hero) =>
              hero.imageAsset?.startsWith('assets/arena/heroes/') ?? false)
          .map((hero) => hero.imageAsset),
      containsAll([
        'assets/arena/heroes/taoyin_001.jpg',
        'assets/arena/heroes/xueli_001.jpg',
        'assets/arena/heroes/ziyuan_001.jpg',
      ]),
    );
    expect(
        model.heroes.map((hero) => hero.name), containsAll(['桃音', '雪璃', '紫鸢']));
  });

  test('single summon spends crystals and records a result', () async {
    final model = localModel(
      random: _FixedRandom(doubles: [.2], ints: [0]),
    );

    final success = await model.summon(1);

    expect(success, isTrue);
    expect(model.starCrystals, 6280 - ArenaViewModel.singleSummonCost);
    expect(model.summonResults, hasLength(1));
  });

  test('ten summon spends discounted cost and keeps sr or above guarantee',
      () async {
    final model = localModel(
      random: _FixedRandom(
        doubles: List<double>.filled(11, .8),
        ints: List<int>.filled(11, 0),
      ),
    );

    final success = await model.summon(10);

    expect(success, isTrue);
    expect(model.starCrystals, 6280 - ArenaViewModel.tenSummonCost);
    expect(model.summonResults, hasLength(10));
    expect(
      model.summonResults.any((result) => result.hero.rarity != ArenaRarity.r),
      isTrue,
    );
  });

  test('duplicate owned hero turns into shards', () async {
    final model = localModel(
      random: _FixedRandom(doubles: [.01], ints: [0]),
    );

    final success = await model.summon(1);

    expect(success, isTrue);
    expect(model.summonResults.single.hero.id, 'lanxing');
    expect(model.summonResults.single.isNew, isFalse);
    expect(model.summonResults.single.shards, ArenaRarity.ssr.shardValue);
    expect(model.shardsOf(model.heroes.first), ArenaRarity.ssr.shardValue);
  });

  test('playing a card records combo feedback and clears it next turn', () {
    final model = localModel();

    model.startBattle();
    model.playCard(0);

    expect(model.combo, 1);
    expect(model.lastPlayedCardIndex, 0);

    model.endTurn();

    expect(model.combo, 0);
    expect(model.lastPlayedCardIndex, -1);
  });

  test('starter deck is generated from the current formation heroes', () {
    final model = localModel();

    expect(model.formationHeroes.map((hero) => hero.name), [
      '澜星',
      '兔突',
      '猫影',
    ]);
    expect(model.cards.map((card) => card.sourceHeroName), [
      '澜星',
      '兔突',
      '猫影',
      '队伍',
    ]);
  });

  test('formation slot can be edited without duplicate heroes', () async {
    final model = localModel(
      random: _FixedRandom(doubles: [.2], ints: [1]),
    );

    await model.summon(1);
    final foxIndex = model.heroes.indexWhere((hero) => hero.id == 'huhuo');

    expect(model.isOwned(model.heroes[foxIndex]), isTrue);

    model.selectFormationSlot(1);
    model.assignHeroToFormation(foxIndex);

    expect(model.formationHeroAt(1)?.id, 'huhuo');
    expect(model.formationHeroes.map((hero) => hero.id).toSet(), hasLength(3));
    expect(model.cards.any((card) => card.sourceHeroName == '狐火'), isTrue);
  });

  test('selected enemy target receives card damage', () {
    final model = localModel();

    model.startBattle();
    model.selectEnemy(1);
    model.playCard(1);

    expect(model.selectedEnemyIndex, 1);
    expect(model.enemyHpAt(0), ArenaViewModel.enemyMaxHp);
    expect(model.enemyHpAt(1), ArenaViewModel.enemyMaxHp - 32);
    expect(model.battleMessage, contains('敌影 2'));
  });

  test('winning battle offers three roguelite card rewards', () async {
    final model = localModel(random: _FixedRandom(ints: [0, 1, 2]));

    model.startBattle();
    _winBattle(model);

    expect(model.finished, isTrue);
    expect(model.won, isTrue);
    expect(model.hasPendingReward, isTrue);
    expect(model.rewardChoices, hasLength(3));

    final deckSize = model.cards.length;
    final floor = model.towerFloor;
    final reward = model.rewardChoices.first;

    await model.chooseRewardCard(0);

    expect(model.hasPendingReward, isFalse);
    expect(model.cards, hasLength(deckSize + 1));
    expect(model.cards.last.name, reward.name);
    expect(model.towerFloor, floor + 1);
    expect(
      model.starCrystals,
      6280 + ArenaViewModel.towerClearReward,
    );
  });

  test('tower node tap only changes selected node description', () {
    final model = localModel();

    expect(model.view, ArenaView.lobby);

    model.navigate(ArenaView.tower);
    model.selectTowerNode(0);

    expect(model.view, ArenaView.tower);
    expect(model.selectedTowerNode.label, '战斗');
  });

  test('insufficient crystals keeps previous summon results untouched',
      () async {
    final model = localModel(
      random: _FixedRandom(doubles: [.01], ints: [0]),
    );

    expect(await model.summon(10), isTrue);
    expect(await model.summon(10), isTrue);
    expect(await model.summon(10), isFalse);
    expect(model.summonResults, isNotEmpty);
    expect(model.starCrystals, 880);
  });

  test('home gift and train apply battle buffs once', () async {
    final model = localModel();
    final beforeBond = model.bondOf(model.activeHero);

    expect(await model.giftAtHome(), isTrue);
    expect(model.starCrystals, 6280 - ArenaViewModel.homeGiftCost);
    expect(model.bondOf(model.activeHero),
        beforeBond + ArenaViewModel.homeGiftBondGain);
    expect(model.bondBuffReady, isTrue);

    await model.trainAtHome();
    expect(model.restBuffReady, isTrue);

    model.startBattle();
    expect(model.playerMaxHp, 100 + ArenaViewModel.homeRestHpBonus);
    expect(model.playerHp, model.playerMaxHp);
    expect(model.energy, 6 + ArenaViewModel.homeBondEnergyBonus);
    expect(model.restBuffReady, isFalse);
    expect(model.bondBuffReady, isFalse);
    expect(model.battleMessage, contains('休息充分'));
    expect(model.battleMessage, contains('羁绊整理'));
  });

  test('selectHeroSkin switches whole-card portrait tint', () async {
    SharedPreferences.setMockInitialValues({});
    final model = localModel();
    final hero = model.heroes.firstWhere((h) => h.id == 'lanxing');

    expect(model.skinOf(hero).id, 'classic');
    expect(model.portraitTintOf(hero), isNull);

    await model.selectHeroSkin(hero, 'starlight');

    expect(model.skinOf(hero).id, 'starlight');
    expect(model.portraitTintOf(hero), isNotNull);
    expect(model.portraitAssetOf(hero), hero.imageAsset);
  });
}

void _winBattle(ArenaViewModel model) {
  var safety = 0;
  while (!model.finished && safety < 20) {
    model.playCard(1);
    model.playCard(3);
    if (!model.finished) {
      model.endTurn();
    }
    safety++;
  }
}

/// 强制走本地回退，避免测试依赖网络。
class _OfflineArenaService extends ArenaService {
  @override
  Future<ArenaStateDto?> fetchState() async => null;

  @override
  Future<ArenaStateDto?> setFormation(List<String> heroIds) async => null;

  @override
  Future<ArenaStateDto?> saveDeck(List<ArenaDeckCardDto> cards) async => null;

  @override
  Future<ArenaSummonResultDto?> summon(int count) async => null;

  @override
  Future<ArenaStateDto?> homeGift(String heroId) async => null;

  @override
  Future<ArenaStateDto?> homeTrain() async => null;

  @override
  Future<ArenaStateDto?> saveSkin({
    required String heroId,
    required String skinId,
  }) async =>
      null;

  @override
  Future<ArenaStateDto?> saveMeta({
    int? selectedTowerNode,
    bool clearBuffs = false,
  }) async =>
      null;

  @override
  Future<ArenaClearTowerResultDto?> clearTower({
    required bool won,
    String? bonusHeroId,
    List<ArenaDeckCardDto>? deck,
  }) async =>
      null;
}

class _FixedRandom implements Random {
  _FixedRandom({
    List<double> doubles = const [.5],
    List<int> ints = const [0],
  })  : _doubles = doubles,
        _ints = ints;

  final List<double> _doubles;
  final List<int> _ints;
  int _doubleIndex = 0;
  int _intIndex = 0;

  @override
  bool nextBool() => nextDouble() >= .5;

  @override
  double nextDouble() {
    final value = _doubles[_doubleIndex % _doubles.length];
    _doubleIndex++;
    return value;
  }

  @override
  int nextInt(int max) {
    final value = _ints[_intIndex % _ints.length];
    _intIndex++;
    return value % max;
  }
}
