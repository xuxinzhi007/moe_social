/// 非 Web / 非 dart:io 平台占位（当前主路径为 [local_llm_chat_service_impl]）。
class LocalLlmChatService {
  LocalLlmChatService._();

  static final LocalLlmChatService instance = LocalLlmChatService._();

  Future<String> chat({
    required String modelId,
    required List<Map<String, String>> messages,
    required bool enableTools,
    String? userId,
    double? temperature,
  }) async {
    throw UnsupportedError('当前平台不支持本机 GGUF，请使用 Web / 移动端或桌面端');
  }

  Future<void> dispose() async {}
}
