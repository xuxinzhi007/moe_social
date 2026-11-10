import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/ai_provider_profile.dart';
import 'package:moe_social/services/chat_model_selection.dart';
import 'package:moe_social/services/llm_api_service.dart';

void main() {
  final customProvider = AiProviderProfile(
    id: 'prov-1',
    name: 'DeepSeek',
    providerType: AiProviderType.openAiCompatible,
    baseUrl: 'https://api.example.com',
    defaultModel: 'deepseek-chat',
    manualModels: const [],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  test('reads builtin_chat_model and keeps other preferences when saving', () {
    const prefs = {
      'last_selected_provider_id': 'prov-1',
      'builtin_chat_model': 'qwen2.5:3b-instruct',
    };
    expect(
      ChatModelSelection.builtinModelFromPreferences(prefs),
      'qwen2.5:3b-instruct',
    );
    expect(ChatModelSelection.builtinModelFromPreferences({}), isNull);
    expect(ChatModelSelection.builtinModelFromPreferences(null), isNull);

    final next = ChatModelSelection.withBuiltinModel(prefs, 'mine-lora');
    expect(next['builtin_chat_model'], 'mine-lora');
    expect(next['last_selected_provider_id'], 'prov-1');
  });

  test('only reports a server default when memory_model is actually present',
      () {
    expect(
      ChatModelSelection.serverDefaultFromConfig({
        'llm_inference': {'memory_model': 'qwen2.5:3b-instruct'},
      }),
      'qwen2.5:3b-instruct',
    );
    expect(
      ChatModelSelection.serverDefaultFromConfig({
        'llm_inference': {'memory_model': ''},
      }),
      isNull,
    );
    expect(ChatModelSelection.serverDefaultFromConfig({}), isNull);
    expect(ChatModelSelection.serverDefaultFromConfig(null), isNull);
  });

  test('splits catalog into base and derived models', () {
    const models = [
      LlmCatalogModel(name: 'qwen2.5:3b-instruct', contextLength: 8192),
      LlmCatalogModel(name: 'mine-lora', derived: true),
      LlmCatalogModel(name: ''),
    ];
    expect(
      ChatModelSelection.baseModels(models).map((e) => e.name),
      ['qwen2.5:3b-instruct'],
    );
    expect(
      ChatModelSelection.derivedModels(models).map((e) => e.name),
      ['mine-lora'],
    );
  });

  test(
      'display prefers custom provider model, then preference, then server default',
      () {
    final providerView = ChatModelSelection.resolve(
      activeProvider: customProvider,
      builtinChatModel: 'qwen2.5:3b-instruct',
      serverDefaultModel: 'ignored',
    );
    expect(providerView.title, 'deepseek-chat');
    expect(providerView.usesCustomProvider, isTrue);
    expect(providerView.subtitle, contains('来源 DeepSeek'));
    expect(providerView.subtitle, contains('和小星聊天共用同一选择'));

    final selected = ChatModelSelection.resolve(
      builtinChatModel: 'qwen2.5:7b-instruct',
      serverDefaultModel: 'qwen2.5:3b-instruct',
    );
    expect(selected.title, 'qwen2.5:7b-instruct');
    expect(selected.isExplicitSelection, isTrue);
    expect(selected.subtitle, '和小星聊天共用同一选择');

    final fallback = ChatModelSelection.resolve(
      serverDefaultModel: 'qwen2.5:3b-instruct',
    );
    expect(fallback.title, 'qwen2.5:3b-instruct');
    expect(fallback.isExplicitSelection, isFalse);
    expect(fallback.subtitle, contains('未选择，使用服务端默认'));

    final unset = ChatModelSelection.resolve();
    expect(unset.title, '未选择，使用服务端默认');
    expect(unset.isExplicitSelection, isFalse);
  });

  test('builtin provider does not override an explicit chat model', () {
    final view = ChatModelSelection.resolve(
      activeProvider: AiProviderProfile.builtinBackend(),
      builtinChatModel: 'mine-lora',
    );
    expect(view.title, 'mine-lora');
    expect(view.usesCustomProvider, isFalse);
  });
}
