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
}
