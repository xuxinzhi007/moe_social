import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/models/ai_agent.dart';
import 'package:moe_social/pages/ai/agent_editor_page.dart';
import 'package:moe_social/providers/loading_provider.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/llm_api_config_test.dart' show config, envelope, view;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.setToken('site-jwt');
  });
  tearDown(() => ApiService.setToken(null));

  for (final outcome in [
    'save-only',
    'create',
    'ready',
    'unknown',
    'failed',
    'unbound'
  ]) {
    testWidgets(
        'editor $outcome saves first, never overwrites server binding and restores loading',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loading = LoadingProvider();
      addTearDown(loading.dispose);
      final calls = <String>[];
      var saved = <String, dynamic>{};
      var writeCount = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: loading,
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                          body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => AgentEditorPage(
                                      agent: outcome == 'create'
                                          ? null
                                          : AiAgent(
                                              id: 'card/一',
                                              name: 'Display Name',
                                              description: 'test',
                                              systemPrompt: 'be kind',
                                              modelName: 'moe-private-1',
                                              createdAt: DateTime(2026)),
                                    ))),
                        child: const Text('open'),
                      )))),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (outcome == 'create') {
          await tester.enterText(find.byType(TextFormField).first, '新卡');
          await tester.enterText(find.byType(TextFormField).at(2), 'base');
        }
        if (outcome != 'save-only') {
          await tester.ensureVisible(find.text('高级选项'));
          await tester.tap(find.text('高级选项'));
          await tester.pumpAndSettle();
          final toggle = outcome == 'create' ? '【可选】创建本人专属模型' : '创建 / 同步本人模型';
          await tester.ensureVisible(find.text(toggle));
          await tester.tap(find.text(toggle));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(outcome == 'create' ? '保存角色卡' : '保存修改'));
        await tester.pumpAndSettle();
        expect(writeCount, outcome == 'save-only' ? 0 : 1);
        expect(calls.where((e) => e == 'save').length, 1);
        if (outcome != 'save-only') {
          expect(calls.indexOf('save'), lessThan(calls.indexOf('sync')));
          if (outcome != 'failed') expect(calls.last, 'refresh');
        }
        expect(loading.isOperationLoading(LoadingKeys.saveAgent), false);
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                final path = request.url.path;
                if (path == '/api/llm/config') return config();
                if (path == '/api/llm/model-prompt') {
                  return envelope({'system_prompt': 'be kind'});
                }
                if (path == '/api/llm/models') {
                  return envelope({
                    'models': [
                      {'name': 'base'},
                      {'name': 'moe-private-1'}
                    ]
                  });
                }
                if (path == '/api/llm/managed-models') {
                  return envelope({
                    'success': true,
                    'models': outcome == 'create' ? [] : [view()]
                  });
                }
                if (path == '/api/ai/agents') {
                  if (request.method == 'POST') {
                    calls.add('save');
                    saved = jsonDecode(
                        (jsonDecode(request.body) as Map)['payload_json']
                            as String) as Map<String, dynamic>;
                    return envelope({'success': true});
                  }
                  calls.add('refresh');
                  return envelope({
                    'items': [
                      {
                        'id': saved['id'],
                        'payload_json':
                            jsonEncode({...saved, 'model_name': 'server-bound'})
                      }
                    ]
                  });
                }
                if (path == '/api/llm/agents') {
                  calls.add('sync');
                  writeCount++;
                  final body = jsonDecode(request.body) as Map;
                  expect(body['agent_id'], saved['id']);
                  expect(body['base_model'], 'base');
                  expect(body['request_id'], isNotEmpty);
                  expect(body.containsKey('name'), false);
                  if (outcome == 'failed') {
                    return http.Response(
                        '{"message":"mock sync rejected"}', 409);
                  }
                  return envelope({
                    ...view(
                        state: outcome == 'unknown' ? 'unknown' : 'ready',
                        binding: outcome != 'unbound'),
                    'agent_id': saved['id']
                  });
                }
                if (path.startsWith('/api/ai/')) return envelope({'items': []});
                throw StateError(
                    'Unexpected mock request: ${request.method} $path');
              }));
    });
  }
}
