/// 统一解析后端 HTTP 响应（compat BaseResp + proto 信封 + proto 直出）。
class ApiResponse {
  static const _envelopeKeys = {'code', 'message', 'success', 'reason'};

  /// 业务字段（去掉 code/message/success/reason 信封层）。
  static Map<String, dynamic> payload(Map<String, dynamic> json) {
    if (json['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(json['data'] as Map);
    }
    if (json['data'] is Map) {
      return Map<String, dynamic>.from(json['data'] as Map);
    }

    final out = <String, dynamic>{};
    json.forEach((key, value) {
      if (!_envelopeKeys.contains(key) && key != 'data') {
        out[key] = value;
      }
    });
    return out;
  }

  /// 列表：兼容 `data:[]`、`data:{items:[]}`、proto `posts`/`notifications` 等。
  static List<dynamic> listOf(
    Map<String, dynamic> json, {
    List<String> keys = const [
      'posts',
      'notifications',
      'comments',
      'messages',
      'conversations',
      'items',
      'records',
      'orders',
      'plans',
    ],
  }) {
    final direct = json['data'];
    if (direct is List) return direct;
    if (direct is Map) {
      for (final key in keys) {
        final v = direct[key];
        if (v is List) return v;
      }
    }
    for (final key in keys) {
      final v = json[key];
      if (v is List) return v;
    }
    final nested = payload(json);
    for (final key in keys) {
      final v = nested[key];
      if (v is List) return v;
    }
    return const [];
  }

  /// 单对象：优先 `data`（compat），否则取 payload。
  static Map<String, dynamic> object(
    Map<String, dynamic> json, {
    List<String> keys = const [
      'user',
      'post',
      'comment',
      'order',
      'plan',
      'record',
    ],
  }) {
    final direct = json['data'];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final flat = payload(json);
    for (final key in keys) {
      final v = flat[key];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return flat;
  }

  static int? intField(Map<String, dynamic> json, String key) {
    final v = json[key] ?? payload(json)[key] ?? json['data']?[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static String? stringField(Map<String, dynamic> json, String key) {
    final v = json[key] ?? payload(json)[key] ?? json['data']?[key];
    return v?.toString();
  }
}
