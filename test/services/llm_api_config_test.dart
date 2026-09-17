import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/services/llm_api_service.dart';

void main() {
  test('normalizes flat inference_* fields from GetLlmConfig', () {
    final data = LlmApiService.normalizeConfig({
      'inference_base_url': 'http://127.0.0.1:11434',
      'inference_api_style': 'ollama',
      'inference_timeout_sec': 120,
      'memory_model': 'qwen2.5:3b-instruct',
      'has_summary_prompt': false,
      'has_extract_prompt': false,
      'memory_budget': {
        'max_ctx_tokens': 8192,
        'ctx_safe_ratio': 0.75,
      },
    });

    expect(data['llm_inference'], isA<Map>());
    expect(
        (data['llm_inference'] as Map)['base_url'], 'http://127.0.0.1:11434');
    expect((data['llm_inference'] as Map)['api_style'], 'ollama');
    expect((data['memory_budget'] as Map)['max_ctx_tokens'], 8192);
  });

  test('keeps nested llm_inference when already present', () {
    final data = LlmApiService.normalizeConfig({
      'llm_inference': {
        'base_url': 'https://api.deepseek.com',
        'api_style': 'openai',
      },
      'memory_budget': {'max_ctx_tokens': 4096},
    });

    expect(
        (data['llm_inference'] as Map)['base_url'], 'https://api.deepseek.com');
  });

  for (final entry in [
    (
      name: 'HTTP failure',
      status: 501,
      body: {'code': 501, 'success': false, 'message': 'unsupported'},
      succeeds: false
    ),
    (
      name: 'nested failure without success field',
      status: 200,
      body: {
        'code': 200,
        'success': true,
        'data': {'code': 501, 'message': 'unsupported'}
      },
      succeeds: false
    ),
    (
      name: 'nested explicit failure',
      status: 200,
      body: {
        'code': 200,
        'success': true,
        'data': {'code': 200, 'success': false, 'message': 'unsupported'}
      },
      succeeds: false
    ),
    (
      name: 'nested success',
      status: 200,
      body: {
        'code': 200,
        'success': true,
        'data': {'code': 200, 'success': true}
      },
      succeeds: true
    ),
    (
      name: 'direct success',
      status: 200,
      body: {'code': 200, 'success': true},
      succeeds: true
    ),
  ]) {
    test('agent prompt sync handles ${entry.name}', () async {
      final request = http.runWithClient(
        () => LlmApiService.upsertAgentPrompt(
          name: 'agent',
          baseModel: 'base',
          systemPrompt: 'be kind',
        ),
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/llm/agents');
          expect(jsonDecode(request.body), {
            'name': 'agent',
            'base_model': 'base',
            'system_prompt': 'be kind',
          });
          return http.Response(jsonEncode(entry.body), entry.status,
              headers: {'content-type': 'application/json'});
        }),
      );
      if (entry.succeeds) {
        await expectLater(request, completes);
      } else {
        await expectLater(request,
            throwsA(predicate((e) => e.toString().contains('unsupported'))));
      }
    });
  }
}
