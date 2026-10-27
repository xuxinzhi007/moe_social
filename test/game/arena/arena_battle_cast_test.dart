import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/arena/arena_battle_cast.dart';
import 'package:moe_social/game/arena/arena_view_model.dart';
import 'package:moe_social/models/arena_state.dart';
import 'package:moe_social/services/arena_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ArenaViewModel model;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    model = ArenaViewModel(
      random: _FixedRandom(),
      service: _OfflineArenaService(),
    );
    model.startBattle();
  });

  test('raising one card then confirming plays it at the commit point', () {
    final cast = ArenaBattleCast(model);
    final index = _affordableIndex(model);
    final card = model.hand[index];

    final raised = cast.onHandTap(index, animating: false);
    expect(raised.rebuild, isTrue);
    expect(cast.playQueue.single, same(card));

    final castUpdate = cast.confirmQueue(animating: false);
    expect(castUpdate.duration, ArenaBattleCast.singleCast);
    expect(cast.playQueue, isEmpty);

    cast.onCastTick(0.41);
    expect(model.hand, contains(card));
    cast.onCastTick(0.42);
    expect(model.hand, isNot(contains(card)));
    expect(model.strike, isNotNull);
  });

  test('two queued cards cast together instead of one by one', () {
    final cast = ArenaBattleCast(model);
    final first = _affordableIndex(model);
    final second = _affordableIndex(model, skip: first);
    cast.onHandTap(first, animating: false);
    final queued = cast.onHandTap(second, animating: false);
    expect(queued.rebuild, isTrue);
    expect(cast.playQueue, hasLength(2));

    final combo = cast.confirmQueue(animating: false);
    expect(combo.duration, ArenaBattleCast.comboCast);
    expect(cast.comboCards, hasLength(2));

    final before = model.hand.length;
    cast.onCastTick(0.74);
    expect(cast.comboResolved, isTrue);
    expect(model.hand.length, lessThan(before));
    expect(cast.takeStrike(), isFalse);
  });
}

int _affordableIndex(ArenaViewModel model, {int skip = -1}) {
  var spent = 0;
  if (skip >= 0) spent = model.hand[skip].cost;
  for (var index = 0; index < model.hand.length; index++) {
    if (index == skip) continue;
    if (model.hand[index].cost + spent <= model.energy) return index;
  }
  fail('starter hand has no affordable card');
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;
}

class _OfflineArenaService extends ArenaService {
  @override
  Future<ArenaStateDto?> fetchState() async => null;

  @override
  Future<ArenaStateDto?> setFormation(List<String> heroIds) async => null;

  @override
  Future<ArenaStateDto?> saveMeta({
    int? selectedTowerNode,
    bool clearBuffs = false,
    int crystalDelta = 0,
  }) async =>
      null;

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
  Future<ArenaClearTowerResultDto?> clearTower({
    required bool won,
    String? bonusHeroId,
    List<ArenaDeckCardDto>? deck,
  }) async =>
      null;
}
