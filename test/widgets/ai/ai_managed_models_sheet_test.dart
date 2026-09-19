import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/providers/ai_managed_models_viewmodel.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/widgets/ai/ai_managed_models_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/llm_api_config_test.dart' show config, envelope, view;

Future<void> mount(WidgetTester tester, AiManagedModelsViewModel vm) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
    child: ChangeNotifierProvider.value(
        value: vm, child: const AiManagedModelsSheet()),
  ))));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.setToken('jwt');
  });
  tearDown(() => ApiService.setToken(null));

  testWidgets('actual sheet handles initial loading in scrollable constraints',
      (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => AiManagedModelsSheet.show(context),
                        child: const Text('manage')),
                  ))));
      await tester.tap(find.text('manage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      response.complete(envelope({'success': true, 'models': []}));
      await tester.pumpAndSettle();
      expect(find.text('暂无本人模型'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => response.future));
  });

  testWidgets('orphan model stays visible; deletion requires confirmation',
      (tester) async {
    var deletes = 0;
    final vm = AiManagedModelsViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(() async {
      await vm.load();
      await mount(tester, vm);
      expect(find.text('moe-private-1'), findsOneWidget);
      expect(find.text('角色卡 ID：card/一'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '删除本人模型'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(find.text('确认删除'), findsOneWidget);
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('状态：已删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/api/llm/config') return config();
              if (request.method == 'DELETE') {
                deletes++;
                return envelope(view(state: 'deleted'));
              }
              return envelope({
                'success': true,
                'models': [view()]
              });
            }));
  });

  testWidgets('unknown disables delete and explicit reconcile resolves it',
      (tester) async {
    var reconciles = 0;
    final vm = AiManagedModelsViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(() async {
      await vm.load();
      await mount(tester, vm);
      expect(find.text('状态：结果未知'), findsOneWidget);
      final delete =
          tester.widget<TextButton>(find.widgetWithText(TextButton, '删除本人模型'));
      expect(delete.onPressed, isNull);
      await tester.tap(find.text('重查'));
      await tester.pumpAndSettle();
      expect(reconciles, 1);
      expect(find.text('状态：已就绪'), findsOneWidget);
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '删除本人模型'))
              .onPressed,
          isNotNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/api/llm/config') return config();
              if (request.url.path.endsWith('/reconcile')) {
                reconciles++;
                return envelope(view());
              }
              return envelope({
                'success': true,
                'models': [view(state: 'unknown')]
              });
            }));
  });

  testWidgets('empty and retryable error states; narrow layout fits',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var fail = true;
    final vm = AiManagedModelsViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(() async {
      await vm.load();
      await mount(tester, vm);
      expect(vm.error, isNotNull);
      expect(vm.busy, false);
      fail = false;
      await tester.tap(find.text('刷新列表'));
      await tester.pumpAndSettle();
      expect(find.text('暂无本人模型'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => fail
            ? http.Response('{"message":"offline"}', 503)
            : envelope({'success': true, 'models': []})));
  });

  test('lost delete response blocks repeated intent until reconcile', () async {
    var deletes = 0;
    final vm = AiManagedModelsViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(() async {
      await vm.load();
      await vm.delete(vm.models.single);
      expect(vm.models.single.state, 'unknown');
      expect(vm.busy, false);
      await vm.delete(vm.models.single);
      expect(deletes, 1);
    },
        () => MockClient((request) async {
              if (request.url.path == '/api/llm/config') return config();
              if (request.method == 'DELETE') {
                deletes++;
                throw TimeoutException('lost response');
              }
              return envelope({
                'success': true,
                'models': [view()]
              });
            }));
  });

  test('account change clears list and refuses further mutations', () async {
    final vm = AiManagedModelsViewModel();
    addTearDown(vm.dispose);
    var requests = 0;
    await http.runWithClient(() async {
      await vm.load();
      ApiService.setToken('other-user');
      await vm.reconcile(vm.models.single);
      expect(vm.models, isEmpty);
      expect(vm.error, isNotNull);
      expect(requests, 1);
      expect(vm.busy, false);
    },
        () => MockClient((_) async {
              requests++;
              return envelope({
                'success': true,
                'models': [view()]
              });
            }));
  });
}
