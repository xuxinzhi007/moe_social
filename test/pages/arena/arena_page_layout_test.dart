import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/arena/arena_page.dart';

void main() {
  testWidgets('arena prototype tabs render in phone landscape constraints',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ArenaPage(),
      ),
    );
    await tester.pump();

    for (final label in ['编队', '图鉴', '召唤', '爬塔']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: label);
    }

    await tester.tap(find.text('召唤').last);
    await tester.pump();
    await tester.tap(find.text('十连 · 2700'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '十连结果弹层');

    await tester.tap(find.text('确认'));
    await tester.pump();
    await tester.tap(find.text('战斗').last);
    await tester.pump();
    await tester.tap(find.text('星潮回响'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.takeException(), isNull, reason: '战斗出牌反馈');
  });
}
