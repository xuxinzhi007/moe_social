import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/settings/modules/about_module.dart';
import 'package:moe_social/providers/device_info_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('about module shows the packaged version without build metadata',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Moe Social Dev',
      packageName: 'com.example.moe_social.dev',
      version: '1.0.0',
      buildNumber: '42',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});

    final provider = DeviceInfoProvider();
    await provider.init();

    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<DeviceInfoProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: AboutModule(),
            ),
          ),
        ),
      );

      expect(find.text('v1.0.0（开发版）'), findsOneWidget);
      expect(find.text('v1.0.0+42 Dev'), findsNothing);
      expect(provider.buildNumber, '42');
      expect(tester.takeException(), isNull);
    } finally {
      provider.dispose();
    }
  });

  testWidgets('feedback entry opens the redesigned feedback panel',
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

    await tester.tap(find.text('意见反馈'));
    await tester.pumpAndSettle();

    expect(find.text('让每一条体验，都有机会被听见'), findsOneWidget);
    expect(find.text('反馈类型'), findsOneWidget);
    expect(find.text('问题描述'), findsOneWidget);
    expect(find.text('提交反馈'), findsOneWidget);
    expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('让每一条体验，都有机会被听见'), findsNothing);
  });

  testWidgets('feedback panel adapts its category layout on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.tap(find.text('意见反馈'));
    await tester.pumpAndSettle();

    expect(find.text('提交反馈'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
