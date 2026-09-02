/// 兼容 OpenAI、Ollama 及常见中转站的模型列表响应。
abstract final class AiModelListParser {
  static List<String> extract(dynamic decoded) {
    if (decoded is! Map) return const [];

    final names = <String>{};
    final root = Map<String, dynamic>.from(decoded);

    void collect(dynamic value) {
      if (value is List) {
        for (final item in value) {
          _addName(names, item);
        }
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final key in const ['models', 'data', 'items']) {
          final nested = map[key];
          if (nested is List || nested is Map) {
            collect(nested);
          }
        }
      }
    }

    collect(root['models']);
    collect(root['data']);
    collect(root['items']);

    return names.toList(growable: false);
  }

  static void _addName(Set<String> names, dynamic value) {
    if (value is String) {
      final name = value.trim();
      if (name.isNotEmpty) names.add(name);
      return;
    }
    if (value is! Map) return;

    final map = Map<String, dynamic>.from(value);
    for (final key in const ['id', 'name', 'model', 'model_id']) {
      final raw = map[key];
      if (raw == null) continue;
      final name = raw.toString().trim();
      if (name.isNotEmpty) {
        names.add(name);
        return;
      }
    }
  }
}
