/// 读取 API JSON 字段：兼容 legacy snake_case 与 Kratos protojson camelCase。
dynamic apiField(Map<String, dynamic> json, String snake, String camel) {
  if (json.containsKey(snake)) return json[snake];
  return json[camel];
}

/// protojson 常省略 0 的计数字段（与 moe-admin apiRecord 对齐）。
const _protoZeroNumericKeys = <String>{
  'likes',
  'comments',
  'price',
  'sort_order',
  'member_count',
  'message_count',
  'owned_quantity',
  'gift_charm',
  'balance',
  'exp_reward',
  'required_count',
  'visit_count',
  'total_duration_ms',
  'total_events_7d',
  'total',
  'count',
  'level',
  'experience',
  'total_exp',
  'duration_days',
  'received_gift_value',
  'size',
};

String _camelToSnake(String key) {
  return key.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}

String _snakeToCamel(String key) {
  return key.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );
}

/// 单条记录：补 snake/camel 别名，并为 proto 省略的 0 计数字段填默认 0。
Map<String, dynamic> apiNormalizedMap(dynamic raw) {
  final base = apiMap(raw);
  final out = Map<String, dynamic>.from(base);

  for (final entry in base.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    final snake = _camelToSnake(key);
    final camel = _snakeToCamel(key);
    if (snake != key) out.putIfAbsent(snake, () => value);
    if (camel != key) out.putIfAbsent(camel, () => value);
  }

  for (final key in _protoZeroNumericKeys) {
    if (out.containsKey(key) && out[key] != null) continue;
    final camel = _snakeToCamel(key);
    if (out.containsKey(camel) && out[camel] != null) {
      out[key] = out[camel];
      continue;
    }
    out.putIfAbsent(key, () => 0);
  }

  return out;
}

/// 将列表项规范为 `Map<String, dynamic>`（Web/JSON 解码后可能是 `Map<dynamic, dynamic>`）。
Map<String, dynamic> apiMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  return Map<String, dynamic>.from(raw as Map);
}

/// 字符串字段；[fallback] 在缺失或空字符串时生效。
String apiString(
  Map<String, dynamic> json,
  String snake,
  String camel, {
  String fallback = '',
}) {
  final v = apiField(json, snake, camel);
  if (v == null) return fallback;
  final s = v.toString();
  if (s.isEmpty) return fallback;
  return s;
}

/// 整数字段（proto 缺省或 JSON 数字/字符串均可）。
int apiInt(dynamic raw, {int fallback = 0}) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

/// 布尔字段。
bool apiBool(
  Map<String, dynamic> json,
  String snake,
  String camel, {
  bool fallback = false,
}) {
  final v = apiField(json, snake, camel);
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1';
  }
  return fallback;
}
