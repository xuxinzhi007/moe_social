import '../models/ai_provider_profile.dart';

/// 默认本地推理来源：本机 llama-server（OpenAI 兼容）。
abstract final class AiPlatformLocalProvider {
  static String get defaultBuiltinProviderId =>
      AiProviderProfile.builtinLlamaCppId;

  static AiProviderProfile defaultBuiltinProfileSync() =>
      AiProviderProfile.builtinLlamaCpp();
}
