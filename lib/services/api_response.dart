import '../utils/api_json.dart';

/// 统一解析后端 HTTP 响应（compat BaseResp + proto 信封 + proto 直出）。
class ApiResponse {
  static const _envelopeKeys = {'code', 'message', 'success', 'reason'};

  static bool isSuccess(Map<String, dynamic> json) {
    if (json['success'] == false) return false;
    final code = json['code'];
    if (code is int && code != 0 && code != 200) return false;
    if (code is num && code != 0 && code != 200) return false;
    return true;
  }

  /// 登录/注册会话：兼容 `data.{user,token}` 与信封下平铺字段。
  static ({Map<String, dynamic> user, String token})? authSession(
    Map<String, dynamic> json,
  ) {
    final data = json['data'];
    Map<String, dynamic>? userMap;
    String? token;

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final user = m['user'];
      if (user is Map) {
        userMap = Map<String, dynamic>.from(user);
      }
      final t = m['token'];
      if (t is String && t.isNotEmpty) token = t;
    }

    final flat = payload(json);
    userMap ??= _mapOrNull(flat['user']);
    token ??= _stringOrNull(flat['token']);

    if (userMap == null || token == null || token.isEmpty) return null;
    final uid = coerceUserId(userMap['id']);
    if (uid == null) return null;
    userMap['id'] = uid;
    return (user: userMap, token: token);
  }

  /// 后端 user.id 可能是 string / int；过滤 0 与空。
  static String? coerceUserId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == '0') return null;
      return s;
    }
    if (raw is int) {
      if (raw <= 0) return null;
      return raw.toString();
    }
    if (raw is num) {
      final n = raw.toInt();
      if (n <= 0) return null;
      return n.toString();
    }
    final s = raw.toString().trim();
    if (s.isEmpty || s == '0') return null;
    return s;
  }

  static bool isValidUserId(String? raw) => coerceUserId(raw) != null;

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

  /// 兼容 proto 消息体内再套一层 BaseResp（如 GetLlmConfigResp.data）。
  static Map<String, dynamic> nestedPayload(Map<String, dynamic> json) {
    final first = payload(json);
    final inner = first['data'];
    if (inner is Map<String, dynamic>) {
      return Map<String, dynamic>.from(inner);
    }
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return first;
  }

  /// 列表：兼容 `data:[]`、`data:{items:[]}`、proto 字段名。
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
      'groups',
      'members',
      'gifts',
      'friends',
      'badges',
      'logs',
      'devices',
      'images',
      'transactions',
      'memories',
      'packs',
      'outfits',
      'followings',
      'followers',
      'users',
      'history',
      'data',
    ],
  }) {
    final direct = json['data'];
    if (direct is List) {
      return direct
          .map((e) => e is Map ? apiNormalizedMap(e) : e)
          .toList(growable: false);
    }
    if (direct is Map) {
      for (final key in keys) {
        final v = direct[key];
        if (v is List) {
          return v
              .map((e) => e is Map ? apiNormalizedMap(e) : e)
              .toList(growable: false);
        }
      }
    }
    for (final key in keys) {
      final v = json[key];
      if (v is List) {
        return v
            .map((e) => e is Map ? apiNormalizedMap(e) : e)
            .toList(growable: false);
      }
    }
    final nested = payload(json);
    for (final key in keys) {
      final v = nested[key];
      if (v is List) {
        return v
            .map((e) => e is Map ? apiNormalizedMap(e) : e)
            .toList(growable: false);
      }
    }
    return const [];
  }

  /// 单对象：优先 `data` 内指定 [keys]（如 `data.user`），否则 `data` 本身或 payload。
  static Map<String, dynamic> object(
    Map<String, dynamic> json, {
    List<String> keys = const [
      'user',
      'post',
      'comment',
      'order',
      'plan',
      'record',
      'group',
      'message',
      'pack',
      'outfit',
      'status',
      'summary',
      'level_info',
      'avatar',
      'quota',
      'plan',
      'order',
      'pack',
      'outfit',
    ],
  }) {
    final direct = json['data'];
    if (direct is Map) {
      final dm = apiNormalizedMap(direct);
      for (final key in keys) {
        final v = dm[key];
        if (v is Map) return apiNormalizedMap(v);
      }
      return dm;
    }

    final flat = payload(json);
    for (final key in keys) {
      final v = flat[key];
      if (v is Map) return apiNormalizedMap(v);
    }
    return apiNormalizedMap(flat);
  }

  static int? intField(Map<String, dynamic> json, String key) {
    final v = json[key] ?? payload(json)[key] ?? json['data']?[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static bool? boolField(Map<String, dynamic> json, String key) {
    final v = json[key] ?? payload(json)[key] ?? json['data'];
    if (v is bool) return v;
    if (key == 'data' && json['data'] is bool) return json['data'] as bool;
    return null;
  }

  static String? stringField(Map<String, dynamic> json, String key) {
    final v = json[key] ?? payload(json)[key] ?? json['data']?[key];
    return v?.toString();
  }

  static Map<String, dynamic>? _mapOrNull(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String? _stringOrNull(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }
}
