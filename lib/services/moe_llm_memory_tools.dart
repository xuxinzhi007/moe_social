import 'dart:convert';

import 'package:llamadart/llamadart.dart';

import 'ai_memory_tools.dart';
import 'ai_tool_runtime.dart';

/// 将 [AiMemoryTools]（OpenClaw 记忆工具）桥接为 llamadart [ToolDefinition]。
abstract final class MoeLlmMemoryTools {
  static List<ToolDefinition> build({required String userId}) {
    return AiMemoryTools.openAiToolDefinitions()
        .map((def) => _fromOpenAiDef(def, userId: userId))
        .toList();
  }

  static List<ToolDefinition> forProfile({
    required bool enabled,
    required String? userId,
  }) {
    if (!enabled || userId == null || userId.trim().isEmpty) {
      return const [];
    }
    return build(userId: userId);
  }

  static String toolSystemAppendix() {
    return '''
你具备以下本地工具（需要时请按模型约定发起工具调用，不要编造未执行的结果）：
${AiMemoryTools.allToolNames.map((n) => '- $n').join('\n')}
工具说明与 OpenClaw 记忆库一致：可检索、读取、保存、列出、读日记、删除用户长期记忆。''';
  }

  static ToolDefinition _fromOpenAiDef(
    Map<String, dynamic> def, {
    required String userId,
  }) {
    final fn = def['function'];
    final fnMap = fn is Map ? Map<String, dynamic>.from(fn) : const {};
    final name = (fnMap['name'] ?? '').toString();
    final description = (fnMap['description'] ?? '').toString();
    final schema = fnMap['parameters'];
    return ToolDefinition(
      name: name,
      description: description,
      parameters: _paramsFromSchema(schema),
      handler: (params) async {
        return AiToolRuntime.execute(
          name: name,
          argumentsJson: jsonEncode(params.raw),
          userId: userId,
        );
      },
    );
  }

  static List<ToolParam> _paramsFromSchema(dynamic schema) {
    if (schema is! Map) return const [];
    final props = schema['properties'];
    if (props is! Map) return const [];
    final required = <String>{
      if (schema['required'] is List)
        ...((schema['required'] as List).map((e) => e.toString())),
    };
    return props.entries.map((entry) {
      final raw = entry.value;
      final prop = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      final type = (prop['type'] ?? 'string').toString();
      final desc = (prop['description'] ?? '').toString();
      final isRequired = required.contains(entry.key.toString());
      return switch (type) {
        'integer' => ToolParam.integer(
            entry.key.toString(),
            description: desc.isEmpty ? null : desc,
            required: isRequired,
          ),
        'number' => ToolParam.number(
            entry.key.toString(),
            description: desc.isEmpty ? null : desc,
            required: isRequired,
          ),
        'boolean' => ToolParam.boolean(
            entry.key.toString(),
            description: desc.isEmpty ? null : desc,
            required: isRequired,
          ),
        _ => ToolParam.string(
            entry.key.toString(),
            description: desc.isEmpty ? null : desc,
            required: isRequired,
          ),
      };
    }).toList();
  }
}
