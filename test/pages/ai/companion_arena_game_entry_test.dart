import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/ai/companion_hub_page.dart';

void main() {
  test('companion daily panels are hidden while arena prototype is active', () {
    expect(
      shouldShowCompanionDailyPanels(arenaGamePrototype: true),
      isFalse,
    );
    expect(
      shouldShowCompanionDailyPanels(arenaGamePrototype: false),
      isTrue,
    );
  });

  testWidgets('arena game entry is visible and tappable', (tester) async {
    var opened = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompanionArenaGameEntry(
            onOpen: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('星辉远征'), findsOneWidget);
    expect(find.text('卡牌小队冒险，进入后切换横屏'), findsOneWidget);
    expect(find.text('试玩'), findsOneWidget);
    expect(
      find.bySemanticsLabel('进入星辉远征'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('进入星辉远征'));
    await tester.pump();

    expect(opened, isTrue);
    semantics.dispose();
  });
}
