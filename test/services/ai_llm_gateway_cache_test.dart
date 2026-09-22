import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/models/ai_agent.dart';
import 'package:moe_social/models/ai_provider_profile.dart';
import 'package:moe_social/services/ai_agent_cloud_service.dart';
import 'package:moe_social/services/ai_chat_gateway_service.dart';
import 'package:moe_social/services/ai_models_cache_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/services/llm_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_api_config_test.dart' show config, envelope, view;

Future<void> switchAccount(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('auth_token', 'jwt-$id');
  await prefs.setString('user_id', id);
  await AuthService.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = AiProviderProfile.builtinBackend();
  final cache = AiModelsCacheService();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await switchAccount('1');
  });
  tearDown(() => ApiService.setToken(null));

  test('private model cache does not cross accounts, logout or legacy key',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'ai_models_cache_${backend.id}', '["legacy-private"]');
    expect(await cache.read(backend.id), isEmpty);
    await cache.write(backend.id, ['private-1']);
    await switchAccount('2');
    expect(await cache.read(backend.id), isEmpty);
    await cache.write(backend.id, ['private-2']);
    await switchAccount('1');
    expect(await cache.read(backend.id), ['private-1']);
    ApiService.setToken(null);
    expect(await cache.read(backend.id), isEmpty);
  });

  test('model listing carries JWT and caches only current account', () async {
    await http.runWithClient(() async {
      expect(await AiChatGatewayService().fetchModelsForProfile(backend),
          ['base', 'private-1']);
    },
        () => MockClient((request) async {
              expect(request.headers['authorization'], 'Bearer jwt-1');
              expect(request.url.path, '/api/llm/models');
              return envelope({
                'models': [
                  {'name': 'base'},
                  {'name': 'private-1'}
                ]
              });
            }));
    expect(await cache.read(backend.id), ['base', 'private-1']);
    await switchAccount('2');
    expect(await cache.read(backend.id), isEmpty);
  });

  test(
      'account switch during model request does not leak its result or fallback',
      () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = AiChatGatewayService().fetchModelsForProfile(backend);
      await started.future;
      await switchAccount('2');
      response.complete(envelope({
        'models': [
          {'name': 'private-1'}
        ]
      }));
      await expectLater(pending, throwsA(isA<ApiException>()));
    },
        () => MockClient((_) {
              started.complete();
              return response.future;
            }));
    expect(await cache.read(backend.id), isEmpty);
  });

  test('401 model listing never falls back to stale private cache', () async {
    await cache.write(backend.id, ['private-1']);
    await http.runWithClient(() async {
      await expectLater(AiChatGatewayService().fetchModelsForProfile(backend),
          throwsA(isA<ApiException>()));
    }, () => MockClient((_) async => http.Response('{}', 401)));
  });

  for (final operation in ['sync', 'delete']) {
    test('$operation invalidates account backend cache', () async {
      await cache.write(backend.id, ['private-1']);
      await http.runWithClient(() async {
        if (operation == 'sync') {
          await LlmApiService.upsertAgentPrompt(
              agentId: 'card',
              requestId: 'r',
              baseModel: 'base',
              systemPrompt: '');
        } else {
          await LlmApiService.deleteManagedModel(
              agentId: 'card', requestId: 'r');
        }
      },
          () => MockClient((request) async =>
              request.url.path == '/api/llm/config'
                  ? config()
                  : envelope(
                      view(state: operation == 'sync' ? 'ready' : 'deleted'))));
      expect(await cache.read(backend.id), isEmpty);
    });
  }

  test('backend chat uses structured gateway and preserves temperature zero',
      () async {
    await http.runWithClient(() async {
      final reply = await AiChatGatewayService().sendChat(
        agent: AiAgent(
            id: 'a',
            name: 'a',
            description: '',
            systemPrompt: '',
            modelName: 'base',
            createdAt: DateTime(2026)),
        messages: [
          {'role': 'user', 'content': 'hello'}
        ],
        temperature: 0,
        topP: 0.8,
      );
      expect(reply, 'hello');
    },
        () => MockClient((request) async {
              expect(request.url.toString(), startsWith(ApiService.baseUrl));
              expect(request.headers['authorization'], 'Bearer jwt-1');
              expect(request.url.path, '/api/llm/chat');
              final body = jsonDecode(request.body) as Map;
              expect(body['agent_id'], 'a');
              expect(body['temperature'], 0);
              expect(body['top_p'], 0.8);
              expect(body.containsKey('options'), false);
              expect(body.containsKey('stream'), false);
              expect(body.containsKey('client_memory_applied'), false);
              return envelope({'content': 'hello'});
            }));
  });

  test('prompt save re-reads card and never creates or updates model',
      () async {
    final requests = <String>[];
    await http.runWithClient(() async {
      await AiAgentCloudService().updateSystemPrompt('card', 'new prompt');
    },
        () => MockClient((request) async {
              requests.add('${request.method} ${request.url.path}');
              expect(request.url.path, '/api/ai/agents');
              if (request.method == 'GET') {
                return envelope({
                  'items': [
                    {
                      'id': 'card',
                      'payload_json': jsonEncode(AiAgent(
                              id: 'card',
                              name: 'current name',
                              description: '',
                              systemPrompt: 'old',
                              modelName: 'server-cas-bound',
                              createdAt: DateTime(2026),
                              isPublic: true)
                          .toMap())
                    }
                  ]
                });
              }
              final body = jsonDecode(request.body) as Map;
              final card = jsonDecode(body['payload_json'] as String) as Map;
              expect(card['model_name'], 'server-cas-bound');
              expect(card['name'], 'current name');
              expect(card['system_prompt'], 'new prompt');
              expect(card['is_public'], true);
              return envelope({'success': true});
            }));
    expect(requests, ['GET /api/ai/agents', 'POST /api/ai/agents']);
  });
}
