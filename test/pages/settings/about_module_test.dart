import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/settings/modules/about_module.dart';
import 'package:moe_social/providers/device_info_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('about module exposes the official website entry',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DeviceInfoProvider>(
        create: (_) => DeviceInfoProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: AboutModule(),
          ),
        ),
      ),
    );

    expect(find.text('访问官网'), findsOneWidget);
    expect(find.text('了解 Moe Social 产品介绍与最新信息'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
