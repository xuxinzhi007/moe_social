import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/services/llm_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> view({String state = 'ready', bool binding = true}) => {
      'code': 0,
      'message': 'result',
      'success': state == 'ready' || state == 'deleted',
      'agent_id': 'card/一',
      'model_name': 'moe-private-1',
      'base_model': 'base',
      'state': state,
      'request_id': 'intent-1',
      'binding_applied': binding,
      'retryable': false,
    };
http.Response envelope(Map<String, dynamic> payload, [int status = 200]) =>
    http.Response(jsonEncode({'code': 0, 'data': payload}), status,
        headers: {'content-type': 'application/json'});
http.Response config() => envelope({
      'inference_api_style': 'ollama',
      'supports_model_management': true,
      'model_sync_timeout_seconds': 180,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.setToken('site-jwt');
  });
  tearDown(() => ApiService.setToken(null));

  test('normalizes flat capabilities and preserves zero sampling elsewhere',
      () {
    final data = LlmApiService.normalizeConfig({
      'inference_base_url': 'http://127.0.0.1:11434',
      'inference_api_style': 'ollama',
      'inference_timeout_sec': 120,
      'memory_budget': {'max_ctx_tokens': 8192},
      'supports_model_management': true,
      'model_sync_timeout_seconds': 240,
    });
    final inference = data['llm_inference'] as Map;
    expect(inference['api_style'], 'ollama');
    expect(inference['supports_model_management'], true);
    expect(inference['model_sync_timeout_seconds'], 240);
    expect((data['memory_budget'] as Map)['max_ctx_tokens'], 8192);
  });

  test('keeps nested config and fails closed for absent capability', () {
    final data = LlmApiService.normalizeConfig({
      'llm_inference': {
        'base_url': 'https://example.test',
        'api_style': 'openai'
      },
    });
    expect((data['llm_inference'] as Map)['api_style'], 'openai');
    expect((data['llm_inference'] as Map)['supports_model_management'], false);
  });

  test('request IDs are UUID v4 and unique', () {
    final id = LlmApiService.newRequestId();
    expect(
        id,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(id, isNot(LlmApiService.newRequestId()));
  });

  for (final state in ['ready', 'unknown', 'pending', 'deleting', 'failed']) {
    test('upsert returns structured $state without re-sending', () async {
      var writes = 0;
      await http.runWithClient(() async {
        final result = await LlmApiService.upsertAgentPrompt(
          agentId: 'card/一',
          requestId: 'intent-1',
          baseModel: 'base',
          systemPrompt: 'kind',
        );
        expect(result.state, state);
        expect(result.isReady, state == 'ready');
        expect(result.bindingApplied, true);
        expect(result.modelName, 'moe-private-1');
        expect(result.requestId, 'intent-1');
      },
          () => MockClient((request) async {
                expect(request.headers['authorization'], 'Bearer site-jwt');
                if (request.url.path == '/api/llm/config') return config();
                writes++;
                expect(request.method, 'POST');
                expect(request.url.path, '/api/llm/agents');
                expect(jsonDecode(request.body), {
                  'agent_id': 'card/一',
                  'request_id': 'intent-1',
                  'base_model': 'base',
                  'system_prompt': 'kind',
                });
                return envelope(view(state: state));
              }));
      expect(writes, 1);
    });
  }

  test('ready without CAS binding is not advertised as bound', () {
    final result = LlmManagedModel.fromJson(view(binding: false));
    expect(result.isReady, true);
    expect(result.bindingApplied, false);
    expect(result.outcomeMessage, contains('未自动绑定'));
  });

  for (final status in [400, 403, 409, 429, 503]) {
    test('HTTP $status propagates normally without retry', () async {
      var writes = 0;
      await http.runWithClient(() async {
        await expectLater(
            LlmApiService.upsertAgentPrompt(
              agentId: 'card',
              requestId: 'intent-1',
              baseModel: 'base',
              systemPrompt: '',
            ),
            throwsA(isA<ApiException>().having((e) => e.code, 'code', status)));
      },
          () => MockClient((request) async {
                if (request.url.path == '/api/llm/config') return config();
                writes++;
                return http.Response(
                    jsonEncode({'message': 'rejected'}), status);
              }));
      expect(writes, 1);
    });
  }

  for (final error in [
    TimeoutException('offline'),
    http.ClientException('disconnected')
  ]) {
    test('lost response is unknown and retains original intent: $error',
        () async {
      var writes = 0;
      await http.runWithClient(() async {
        final result = await LlmApiService.upsertAgentPrompt(
          agentId: 'card',
          requestId: 'same-intent',
          baseModel: 'base',
          systemPrompt: '',
        );
        expect(result.isUnresolved, true);
        expect(result.requestId, 'same-intent');
        expect(result.outcomeMessage, contains('不要重复'));
      },
          () => MockClient((request) async {
                if (request.url.path == '/api/llm/config') return config();
                writes++;
                throw error;
              }));
      expect(writes, 1);
    });
  }

  test('list/get/reconcile/delete use JWT, encoded id and delete intent',
      () async {
    final methods = <String>[];
    await http.runWithClient(() async {
      expect(
          (await LlmApiService.listManagedModels()).single.agentId, 'card/一');
      expect((await LlmApiService.getManagedModel('card/一')).isReady, true);
      expect(
          (await LlmApiService.reconcileManagedModel('card/一')).isReady, true);
      expect(
          (await LlmApiService.deleteManagedModel(
                  agentId: 'card/一', requestId: 'intent-1'))
              .isDeleted,
          true);
    },
        () => MockClient((request) async {
              expect(request.headers['authorization'], 'Bearer site-jwt');
              if (request.url.path == '/api/llm/config') return config();
              methods.add(request.method);
              if (request.url.path == '/api/llm/managed-models') {
                return envelope({
                  'success': true,
                  'models': [view()]
                });
              }
              expect(request.url.toString(), contains('card%2F%E4%B8%80'));
              if (request.method == 'DELETE') {
                expect(jsonDecode(request.body), {'request_id': 'intent-1'});
                return envelope(view(state: 'deleted'));
              }
              return envelope(view());
            }));
    expect(methods, ['GET', 'GET', 'POST', 'DELETE']);
  });

  test('omitted models field is an empty list', () async {
    await http.runWithClient(() async {
      expect(await LlmApiService.listManagedModels(), isEmpty);
    },
        () => MockClient((request) async => envelope({
              'code': 200,
              'message': '获取受管模型成功',
              'success': true,
            })));
  });

  test('management refuses anonymous list without HTTP', () async {
    ApiService.setToken(null);
    await http.runWithClient(() async {
      await expectLater(
          LlmApiService.listManagedModels(), throwsA(isA<ApiException>()));
    }, () => MockClient((_) async => throw StateError('must not send')));
  });
}
