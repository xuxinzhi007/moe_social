import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/arena/arena_view_model.dart';
import 'package:moe_social/models/arena_state.dart';
import 'package:moe_social/pages/arena/arena_page.dart';
import 'package:moe_social/services/arena_service.dart';

void main() {
  testWidgets('arena prototype tabs render in phone landscape constraints',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = ArenaViewModel(service: _OfflineArenaService());
    addTearDown(model.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(modelForTesting: model),
      ),
    );
    await tester.pump();

    for (final label in ['编队', '小家', '图鉴', '召唤', '爬塔', '战斗']) {
      expect(find.text(label), findsWidgets, reason: '底部 tag 应显示：$label');
    }
    expect(find.text('退出游戏'), findsOneWidget);
    expect(find.text('本周目标'), findsOneWidget);
    expect(find.text('澜星 UP'), findsOneWidget);
    expect(find.text('十连召唤 · 至少 SR'), findsOneWidget);
    expect(find.textContaining('爬塔第 1 层'), findsOneWidget);

    await tester.tap(find.text('小家').last);
    await tester.pump();
    expect(find.text('星辉小家'), findsOneWidget);
    expect(find.text('今日陪伴'), findsOneWidget);
    expect(find.text('远征加成'), findsOneWidget);
    expect(find.text('当前皮肤'), findsOneWidget);
    expect(find.text('更换皮肤'), findsOneWidget);
    expect(find.textContaining('整卡替换立绘'), findsOneWidget);
    expect(find.text('送礼 · 80'), findsOneWidget);
    expect(find.text('训练'), findsOneWidget);
    expect(find.text('出发'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '小家');

    await tester.tap(find.text('编队').last);
    await tester.pump();
    expect(find.text('编队'), findsWidgets);
    expect(find.text('阵容思路'), findsOneWidget);
    expect(find.textContaining('正在编辑'), findsOneWidget);
    expect(find.text('澜星'), findsWidgets);
    expect(find.text('兔突'), findsWidgets);
    expect(find.text('猫影'), findsWidgets);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('保存并挑战'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('返回大厅'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '编队');

    await tester.tap(find.text('图鉴').last);
    await tester.pump();
    expect(find.text('英雄图鉴'), findsOneWidget);
    expect(find.textContaining('总览所有英雄'), findsOneWidget);
    expect(find.textContaining('已收集'), findsWidgets);
    expect(find.text('澜星'), findsWidgets);
    expect(find.text('桃音 · 未解锁'), findsOneWidget);
    expect(find.text('雪璃 · 未解锁'), findsOneWidget);
    expect(find.text('紫鸢 · 未解锁'), findsOneWidget);
    expect(find.text('潮汐'), findsWidgets);
    expect(find.text('法师'), findsWidgets);
    expect(find.textContaining('星潮回响'), findsWidgets);
    expect(tester.takeException(), isNull, reason: '图鉴');

    await tester.tap(find.text('澜星').first);
    await tester.pump();
    expect(find.text('皮肤'), findsOneWidget);
    expect(find.textContaining('整卡替换角色立绘'), findsOneWidget);
    expect(find.text('经典'), findsWidgets);
    expect(find.text('养成路线'), findsOneWidget);
    expect(find.text('碎片升星'), findsOneWidget);
    expect(find.text('技能升级'), findsOneWidget);
    expect(find.text('装备槽位'), findsOneWidget);
    expect(find.text('资源转化'), findsOneWidget);
    expect(find.text('武器'), findsOneWidget);
    expect(find.text('饰品'), findsOneWidget);
    expect(find.text('圣印'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '角色详情');

    await tester.tap(find.text('召唤').last);
    await tester.pump();
    expect(find.text('星辉召唤'), findsOneWidget);
    expect(find.text('星轨巡礼'), findsOneWidget);
    expect(find.text('卡池预览'), findsOneWidget);
    await tester.tap(find.text('卡池预览'));
    await tester.pump();
    expect(find.text('当前召唤池'), findsOneWidget);
    expect(find.text('澜星 · 本期UP'), findsOneWidget);
    expect(find.text('桃音'), findsWidgets);
    await tester.tap(find.text('×'));
    await tester.pump();
    expect(find.text('单抽 · 300'), findsOneWidget);
    expect(find.text('十连 · 2700'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '召唤');

    await tester.tap(find.text('爬塔').last);
    await tester.pump();
    expect(find.text('爬塔 · 星砂回廊'), findsOneWidget);
    expect(find.textContaining('路线分支'), findsOneWidget);
    await tester.tap(find.text('战斗').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('战斗 · 普通战'), findsOneWidget);
    expect(find.text('开始冒险'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '爬塔');

    await tester.tap(find.text('召唤').last);
    await tester.pump();
    await tester.tap(find.text('十连 · 2700'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: '十连结果弹层');

    await tester.tap(find.text('确认'));
    await tester.pump();
    await tester.tap(find.text('战斗').last);
    await tester.pump();
    expect(find.text('我方战力  51400'), findsOneWidget);
    expect(find.text('敌方战力  16,240'), findsOneWidget);
    expect(find.textContaining('目标：敌影 1'), findsOneWidget);
    expect(find.textContaining('敌意图'), findsOneWidget);
    expect(find.text('意图 -10'), findsOneWidget);
    expect(find.text('我方生命'), findsOneWidget);
    expect(find.text('敌方生命'), findsOneWidget);
    expect(find.text('本局手牌'), findsOneWidget);
    expect(find.text('星潮回响'), findsOneWidget);
    expect(find.text('澜星技'), findsOneWidget);
    expect(find.text('兔突技'), findsOneWidget);
    expect(find.text('猫影技'), findsOneWidget);
    await tester.tap(find.text('敌影 2'));
    await tester.pump();
    expect(find.textContaining('目标：敌影 2'), findsOneWidget);
    await tester.tap(find.text('闪耀突刺'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.textContaining('连携 1'), findsWidgets);
    expect(find.text('兔突 · 闪耀突刺'), findsOneWidget);
    expect(find.textContaining('敌影 2'), findsWidgets);
    expect(tester.takeException(), isNull, reason: '战斗出牌反馈');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('battle units and cards use the edited formation heroes',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = ArenaViewModel(
      random: _FixedRandom(doubles: [.2], ints: [1]),
      service: _OfflineArenaService(),
    );
    addTearDown(model.dispose);

    expect(await model.summon(1), isTrue);
    final foxIndex = model.heroes.indexWhere((hero) => hero.id == 'huhuo');
    model.selectFormationSlot(1);
    model.assignHeroToFormation(foxIndex);
    model.startBattle();

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(modelForTesting: model),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('狐火'), findsOneWidget);
    expect(find.text('狐火技'), findsOneWidget);
    expect(find.text('兔突技'), findsNothing);
    expect(tester.takeException(), isNull, reason: '战斗应使用编辑后的编队');
  });
}

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
