import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/commerce/vip_benefit_catalog.dart';

void main() {
  test('formatVipExpiryLabel drops seconds and uses a compact date', () {
    expect(
      formatVipExpiryLabel('2026-06-23 19:43:44'),
      '2026.06.23 19:43',
    );
  });

  test('formatVipExpiryLabel keeps unparseable text', () {
    expect(formatVipExpiryLabel('未知'), '未知');
    expect(formatVipExpiryLabel(null), '有效期待同步');
    expect(formatVipExpiryLabel('  '), '有效期待同步');
  });

  testWidgets('benefit panel fits a narrow phone width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(320, 640)),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: VipBenefitPanel(),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('签到经验'), findsOneWidget);
    expect(find.text('每日赠送 $vipDailyStarCrystals'), findsOneWidget);
    expect(find.text('接入中'), findsNothing);
  });

  test('daily crystal grant matches one summon', () {
    final crystal = vipMembershipBenefits.singleWhere(
      (item) => item.title == '星辉结晶',
    );
    expect(crystal.pending, isFalse);
    expect(crystal.detail, '每日赠送 $vipDailyStarCrystals');
    expect(vipDailyStarCrystals, 300);
  });
}
