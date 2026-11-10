import '../models/ai_provider_profile.dart';
import 'llm_api_service.dart';

/// 陪伴聊天与回复参谋共用的用户级模型选择。
///
/// 写入的是同一条偏好 `builtin_chat_model`；实际推理仍由服务端
/// `ResolveActiveInference` 按「当前来源 → 该偏好 → 服务端默认」解析。
abstract final class ChatModelSelection {
  static const preferenceKey = 'builtin_chat_model';

  static const unsetFallbackLabel = '未选择，使用服务端默认';

  static const sharedWithCompanionHint = '和小星聊天共用同一选择';

  static String? builtinModelFromPreferences(
      Map<String, dynamic>? preferences) {
    final raw = preferences?[preferenceKey]?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  /// 只在配置里真正读到非空 `memory_model` 时返回，不编造默认名。
  static String? serverDefaultFromConfig(Map<String, dynamic>? config) {
    if (config == null) return null;
    final inference = config['llm_inference'];
    if (inference is Map) {
      final raw = inference['memory_model']?.toString().trim() ?? '';
      if (raw.isNotEmpty) return raw;
    }
    final flat = config['memory_model']?.toString().trim() ?? '';
    return flat.isEmpty ? null : flat;
  }

  static Map<String, dynamic> withBuiltinModel(
    Map<String, dynamic>? preferences,
    String model,
  ) {
    final next = Map<String, dynamic>.from(preferences ?? const {});
    next[preferenceKey] = model;
    return next;
  }

  static List<LlmCatalogModel> baseModels(List<LlmCatalogModel> models) =>
      models.where((item) => item.name.isNotEmpty && !item.derived).toList();

  static List<LlmCatalogModel> derivedModels(List<LlmCatalogModel> models) =>
      models.where((item) => item.name.isNotEmpty && item.derived).toList();

  static ChatModelSelectionDisplay resolve({
    AiProviderProfile? activeProvider,
    String? builtinChatModel,
    String? serverDefaultModel,
  }) {
    final provider = activeProvider;
    if (provider != null && !provider.isBuiltinBackend) {
      final model = provider.effectiveModelId.trim();
      final title = model.isNotEmpty ? model : provider.name;
      final source = provider.name.trim();
      final subtitle = source.isNotEmpty
          ? '来源 $source · $sharedWithCompanionHint'
          : sharedWithCompanionHint;
      return ChatModelSelectionDisplay(
        title: title,
        subtitle: subtitle,
        usesCustomProvider: true,
        isExplicitSelection: true,
      );
    }

    final selected = builtinChatModel?.trim() ?? '';
    if (selected.isNotEmpty) {
      return ChatModelSelectionDisplay(
        title: selected,
        subtitle: sharedWithCompanionHint,
        usesCustomProvider: false,
        isExplicitSelection: true,
      );
    }

    final server = serverDefaultModel?.trim() ?? '';
    if (server.isNotEmpty) {
      return ChatModelSelectionDisplay(
        title: server,
        subtitle: '未选择，使用服务端默认 · $sharedWithCompanionHint',
        usesCustomProvider: false,
        isExplicitSelection: false,
      );
    }

    return const ChatModelSelectionDisplay(
      title: unsetFallbackLabel,
      subtitle: sharedWithCompanionHint,
      usesCustomProvider: false,
      isExplicitSelection: false,
    );
  }
}

class ChatModelSelectionDisplay {
  const ChatModelSelectionDisplay({
    required this.title,
    required this.subtitle,
    required this.usesCustomProvider,
    required this.isExplicitSelection,
  });

  final String title;
  final String subtitle;
  final bool usesCustomProvider;
  final bool isExplicitSelection;
}
