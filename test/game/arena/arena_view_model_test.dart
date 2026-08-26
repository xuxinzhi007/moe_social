import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/arena/arena_view_model.dart';

void main() {
  test('starts with three owned heroes and the first real portrait hero', () {
    final model = ArenaViewModel(random: _FixedRandom());

    expect(model.ownedCount, 3);
    expect(model.heroes.first.name, '澜星');
    expect(
        model.heroes.first.imageAsset, 'assets/arena/heroes/lanxing_001.jpg');
    expect(model.isOwned(model.heroes.first), isTrue);
  });

  test('single summon spends crystals and records a result', () {
    final model =
        ArenaViewModel(random: _FixedRandom(doubles: [.2], ints: [0]));

    final success = model.summon(1);

    expect(success, isTrue);
    expect(model.starCrystals, 6280 - ArenaViewModel.singleSummonCost);
    expect(model.summonResults, hasLength(1));
  });

  test('ten summon spends discounted cost and keeps sr or above guarantee', () {
    final model = ArenaViewModel(
      random: _FixedRandom(
        doubles: List<double>.filled(11, .8),
        ints: List<int>.filled(11, 0),
      ),
    );

    final success = model.summon(10);

    expect(success, isTrue);
    expect(model.starCrystals, 6280 - ArenaViewModel.tenSummonCost);
    expect(model.summonResults, hasLength(10));
    expect(
      model.summonResults.any((result) => result.hero.rarity != ArenaRarity.r),
      isTrue,
    );
  });

  test('duplicate owned hero turns into shards', () {
    final model =
        ArenaViewModel(random: _FixedRandom(doubles: [.01], ints: [0]));

    final success = model.summon(1);

    expect(success, isTrue);
    expect(model.summonResults.single.hero.id, 'lanxing');
    expect(model.summonResults.single.isNew, isFalse);
    expect(model.summonResults.single.shards, ArenaRarity.ssr.shardValue);
    expect(model.shardsOf(model.heroes.first), ArenaRarity.ssr.shardValue);
  });

  test('playing a card records combo feedback and clears it next turn', () {
    final model = ArenaViewModel(random: _FixedRandom());

    model.startBattle();
    model.playCard(0);

    expect(model.combo, 1);
    expect(model.lastPlayedCardIndex, 0);

    model.endTurn();

    expect(model.combo, 0);
    expect(model.lastPlayedCardIndex, -1);
  });

  test('insufficient crystals keeps previous summon results untouched', () {
    final model =
        ArenaViewModel(random: _FixedRandom(doubles: [.01], ints: [0]));

    expect(model.summon(10), isTrue);
    expect(model.summon(10), isTrue);
    expect(model.summon(10), isFalse);
    expect(model.summonResults, isNotEmpty);
    expect(model.starCrystals, 880);
  });
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
