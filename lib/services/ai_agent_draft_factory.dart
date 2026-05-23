import '../models/ai_agent.dart';
import '../models/ai_provider_profile.dart';

/// 从「模型来源」Tab 进入编辑页时生成草稿角色卡（身份设定，非 Ollama 模型）。
abstract final class AiAgentDraftFactory {
  static bool isEphemeralId(String id) =>
      id.startsWith('draft_') || id.startsWith('template_');

  static AiAgent fromModel({
    required String modelName,
    required AiProviderProfile provider,
  }) {
    final now = DateTime.now();
    final desc = switch (provider.providerType) {
      AiProviderType.llamaCppServer =>
        '将绑定本机 llama.cpp 模型「$modelName」。请先启动 llama-server。',
      AiProviderType.localGguf =>
        '将绑定 App 内 llama.cpp 模型「$modelName」。请先在「离线模型下载」安装 GGUF。',
      AiProviderType.openAiCompatible =>
        '将绑定中转站模型「$modelName」。保存的是本地身份 JSON，不会在 API 上创建模型。',
      _ => '将绑定服务器模型「$modelName」。保存本地身份 JSON 即可聊天。',
    };
    return AiAgent(
      id: 'draft_${now.microsecondsSinceEpoch}',
      name: '新角色',
      description: desc,
      systemPrompt: '',
      modelName: modelName,
      providerProfileId: provider.isBackendOllama ? null : provider.id,
      createdAt: now,
    );
  }
}
