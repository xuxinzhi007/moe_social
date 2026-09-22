import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/services/content_generation_service.dart';

import 'llm_api_config_test.dart' show envelope;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ApiService.setToken(null));

  test('content generation delegates content rules to backend', () async {
    ApiService.setToken('jwt-1');
    const service = ContentGenerationService();
    await http.runWithClient(() async {
      final result = await service.generate(
        type: 'poem',
        prompt: '写一首星空诗',
        agentId: 'agent-1',
      );
      expect(result, '星光落在窗台');
    }, () {
      return MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/content/generate');
        expect(request.headers['authorization'], 'Bearer jwt-1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'poem');
        expect(body['prompt'], '写一首星空诗');
        expect(body.containsKey('messages'), false);
        expect(body.containsKey('system_prompt'), false);
        final options = jsonDecode(body['options_json'] as String) as Map;
        expect(options['agent_id'], 'agent-1');
        return envelope({'content': '星光落在窗台'});
      });
    });
  });
}
