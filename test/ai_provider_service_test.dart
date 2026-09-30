import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/ai_provider_profile.dart';
import 'package:moe_social/services/ai_provider_service.dart';

void main() {
  AiProviderProfile customProfile(
    String id, {
    String defaultModel = 'gpt-4o-mini',
  }) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return AiProviderProfile(
      id: id,
      name: id,
      providerType: AiProviderType.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      defaultModel: defaultModel,
      manualModels: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  test('keeps an explicitly selected custom provider', () {
    final selected = customProfile('selected');
    final other = customProfile('other');

    final result = AiProviderService.resolveSelection(
      profiles: [selected, other],
      selectedId: selected.id,
    );

    expect(result.profile.id, selected.id);
    expect(result.source, AiProviderSelectionSource.explicitCustom);
    expect(result.autoSelected, isFalse);
  });

  test('uses the server default when nothing was saved', () {
    final configured = customProfile('only-provider');

    final result = AiProviderService.resolveSelection(
      profiles: [configured],
    );

    expect(result.profile.isBuiltinBackend, isTrue);
    expect(result.source, AiProviderSelectionSource.defaultBuiltin);
    expect(result.autoSelected, isFalse);
  });

  test('does not promote a custom provider from a legacy local selection', () {
    final configured = customProfile('xbai');

    final result = AiProviderService.resolveSelection(
      profiles: [configured],
      selectedId: AiProviderProfile.legacyBuiltinLocalLlamaCppId,
    );

    expect(result.profile.isBuiltinBackend, isTrue);
    expect(result.source, AiProviderSelectionSource.explicitBuiltin);
  });

  test('keeps the built-in provider when it was explicitly selected', () {
    final configured = customProfile('configured');

    final result = AiProviderService.resolveSelection(
      profiles: [configured],
      selectedId: AiProviderProfile.builtinBackendId,
    );

    expect(result.profile.isBuiltinBackend, isTrue);
    expect(result.source, AiProviderSelectionSource.explicitBuiltin);
  });

  test('does not guess between multiple custom providers', () {
    final first = customProfile('first');
    final second = customProfile('second');

    final result = AiProviderService.resolveSelection(
      profiles: [first, second],
      selectedId: 'missing-provider',
    );

    expect(result.profile.isBuiltinBackend, isTrue);
    expect(result.source, AiProviderSelectionSource.defaultBuiltin);
  });
}
