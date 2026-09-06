import 'package:flutter_test/flutter_test.dart';
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
}
