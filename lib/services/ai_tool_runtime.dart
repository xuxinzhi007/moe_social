import 'package:flutter/foundation.dart';

import 'ai_memory_tools.dart';

/// 聊天链路工具执行运行时（OpenClaw 式记忆工具 + 可扩展注册）。
abstract final class AiToolRuntime {
  static const int maxRounds = 3;

  /// 当前已注册的工具 schema（发往中转 chat/completions）。
  static List<Map<String, dynamic>> definitionsForMemory() =>
      AiMemoryTools.openAiToolDefinitions();

  static List<String> registeredToolNames() => AiMemoryTools.allToolNames;

  static Future<String> execute({
    required String name,
    required String argumentsJson,
    required String userId,
  }) async {
    if (kDebugMode) {
      debugPrint('🔧 [Tool] $name args=$argumentsJson');
    }
    return AiMemoryTools.execute(
      toolName: name,
      argumentsJson: argumentsJson,
      userId: userId,
    );
  }
}
