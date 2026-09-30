import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/ai_provider_profile.dart';

void main() {
  test('source dropdown keeps builtin once when the account list omits it', () {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final custom = AiProviderProfile(
      id: 'custom',
      name: 'XBai',
      providerType: AiProviderType.openAiCompatible,
      baseUrl: 'https://api.example.test',
      defaultModel: 'm',
      manualModels: const [],
      supportsSystemMessages: true,
      supportsStreaming: true,
      supportsVision: false,
      supportsToolCalls: false,
      createdAt: now,
      updatedAt: now,
    );
    final options = AiProviderProfile.uniqueWithBuiltin([
      custom,
      custom,
      AiProviderProfile.builtinBackend(),
      AiProviderProfile.builtinBackend(),
    ]);

    expect(options.map((item) => item.id), [
      'custom',
      AiProviderProfile.builtinBackendId,
    ]);
    expect(
      AiProviderProfile.selectableId(
          options, AiProviderProfile.builtinBackendId),
      AiProviderProfile.builtinBackendId,
    );
    expect(
      AiProviderProfile.selectableId(
        AiProviderProfile.uniqueWithBuiltin(const []),
        'missing',
      ),
      AiProviderProfile.builtinBackendId,
    );
  });
}
