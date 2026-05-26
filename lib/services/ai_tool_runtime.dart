import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../moe/moe_tool_service.dart';
import 'ai_memory_tools.dart';

/// 聊天链路工具执行运行时（记忆工具 + Moe Core 社交工具）。
abstract final class AiToolRuntime {
  static const int maxRounds = 3;

  /// 当前已注册的工具 schema（发往中转 chat/completions）。
  static List<Map<String, dynamic>> definitionsForMemory() =>
      AiMemoryTools.openAiToolDefinitions();

  /// 记忆 + Moe 社交工具（7B 云模型开 tools 时使用）。
  static Future<List<Map<String, dynamic>>> definitionsForChat() async {
    final out = <Map<String, dynamic>>[
      ...AiMemoryTools.openAiToolDefinitions(),
    ];
    try {
      final schema = await MoeToolService().fetchSchema();
      for (final item in schema.tools) {
        if (item is Map<String, dynamic>) {
          out.add(item);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔧 [Tool] moe schema fallback: $e');
      }
    }
    return out;
  }

  static List<String> registeredToolNames() => [
        ...AiMemoryTools.allToolNames,
        MoeSocialToolNames.postSearch,
        MoeSocialToolNames.postGet,
        // post_create 仅 Bot / Admin，不在客户端聊天默认注册
      ];

  static Future<String> execute({
    required String name,
    required String argumentsJson,
    required String userId,
  }) async {
    if (kDebugMode) {
      debugPrint('🔧 [Tool] $name args=$argumentsJson');
    }
    if (_isMoeSocialTool(name)) {
      return _executeMoeSocialTool(
        name: name,
        argumentsJson: argumentsJson,
      );
    }
    return AiMemoryTools.execute(
      toolName: name,
      argumentsJson: argumentsJson,
      userId: userId,
    );
  }

  static bool _isMoeSocialTool(String name) {
    return name == MoeSocialToolNames.postSearch ||
        name == MoeSocialToolNames.postGet ||
        name == MoeSocialToolNames.postCreate;
  }

  static Future<String> _executeMoeSocialTool({
    required String name,
    required String argumentsJson,
  }) async {
    Map<String, dynamic> args = {};
    try {
      final decoded = jsonDecode(argumentsJson);
      if (decoded is Map) {
        args = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    final res = await MoeToolService().execute(
      tool: name,
      arguments: args,
    );
    if (!res.ok) {
      throw Exception(res.error.isNotEmpty ? res.error : '工具执行失败');
    }
    return res.result;
  }
}
