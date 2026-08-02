import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/ai_provider_usage_service.dart';

void main() {
  test('ProviderTokenUsage parses New API token usage data', () {
    final usage = ProviderTokenUsage.fromResponse({
      'code': true,
      'data': {
        'object': 'token_usage',
        'name': 'Xbai',
        'total_granted': 1200000,
        'total_used': 200000,
        'total_available': 1000000,
        'unlimited_quota': false,
      },
    });

    expect(usage, isNotNull);
    expect(usage!.totalAvailable, 1000000);
    expect(usage.unlimitedQuota, isFalse);
  });

  test('ProviderTokenLogEntry parses token log quota without inventing RMB',
      () {
    final entry = ProviderTokenLogEntry.fromJson({
      'id': 9,
      'type': 2,
      'content': 'API调用成功',
      'model_name': 'gpt-4o-mini',
      'quota': 1250,
      'created_at': 1640995000,
    });

    expect(entry, isNotNull);
    expect(entry!.quota, 1250);
    expect(entry.promptTokens, isNull);
    expect(entry.completionTokens, isNull);
  });

  test(
      'ProviderTokenLogEntry keeps prompt/completion when gateway provides them',
      () {
    final entry = ProviderTokenLogEntry.fromJson({
      'id': 10,
      'quota': 2000,
      'model_name': 'gpt-4o',
      'created_at': 1640995100,
      'prompt_tokens': 40,
      'completion_tokens': 80,
    });

    expect(entry!.promptTokens, 40);
    expect(entry.completionTokens, 80);
  });
}
