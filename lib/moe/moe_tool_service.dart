import 'dart:convert';

import '../services/api_service.dart';
import 'moe_capability_tier.dart';

/// Moe Core 工具 API 客户端（schema / execute / 动态检索）。
class MoeToolService {
  MoeToolService._();

  static final MoeToolService _instance = MoeToolService._();
  factory MoeToolService() => _instance;

  /// OpenAI 兼容 tools 列表 + 默认档位。
  Future<MoeToolSchema> fetchSchema() async {
    final raw = await ApiService.get('/api/moe/tools/schema');
    final data = raw['data'] as Map<String, dynamic>? ?? {};
    final tools = (data['tools'] as List<dynamic>?) ?? [];
    return MoeToolSchema(
      tier: (data['tier'] ?? MoeCapabilityTier.defaultTier).toString(),
      tools: tools,
    );
  }

  /// 执行 Moe 工具（需登录 JWT）。
  Future<MoeToolExecuteResult> execute({
    required String tool,
    required Map<String, dynamic> arguments,
    String? agentKey,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'tool': tool,
      'arguments': jsonEncode(arguments),
      if (agentKey != null && agentKey.isNotEmpty) 'agent_key': agentKey,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
    };
    final raw = await ApiService.post('/api/moe/tools/execute', body: body);
    final data = raw['data'] as Map<String, dynamic>? ?? {};
    return MoeToolExecuteResult(
      ok: data['ok'] == true,
      result: (data['result'] ?? '').toString(),
      error: (data['error'] ?? '').toString(),
    );
  }

  /// Post Pulse P0：关键词搜动态。
  Future<List<MoePostSearchHit>> searchPosts({
    String query = '',
    int pageSize = 10,
    String? moodTag,
    String? viewerUserId,
  }) async {
    final parts = <String>[
      'page_size=$pageSize',
      if (query.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(query.trim())}',
      if (moodTag != null && moodTag.isNotEmpty)
        'mood_tag=${Uri.encodeQueryComponent(moodTag)}',
      if (viewerUserId != null && viewerUserId.isNotEmpty)
        'viewer_user_id=${Uri.encodeQueryComponent(viewerUserId)}',
    ];
    final raw = await ApiService.get('/api/posts/search?${parts.join('&')}');
    final data = raw['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map>()
        .map((e) => MoePostSearchHit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class MoeToolSchema {
  final String tier;
  final List<dynamic> tools;

  const MoeToolSchema({required this.tier, required this.tools});
}

class MoeToolExecuteResult {
  final bool ok;
  final String result;
  final String error;

  const MoeToolExecuteResult({
    required this.ok,
    required this.result,
    required this.error,
  });
}

class MoePostSearchHit {
  final String postId;
  final String userName;
  final String snippet;
  final double score;
  final String scoreReason;

  const MoePostSearchHit({
    required this.postId,
    required this.userName,
    required this.snippet,
    required this.score,
    required this.scoreReason,
  });

  factory MoePostSearchHit.fromMap(Map<String, dynamic> map) {
    return MoePostSearchHit(
      postId: (map['post_id'] ?? '').toString(),
      userName: (map['user_name'] ?? '').toString(),
      snippet: (map['snippet'] ?? map['content'] ?? '').toString(),
      score: (map['score'] is num) ? (map['score'] as num).toDouble() : 0,
      scoreReason: (map['score_reason'] ?? '').toString(),
    );
  }
}

/// 服务端注册的 Moe 社交工具名（与 backend/pkg/moe/tools 一致）。
abstract final class MoeSocialToolNames {
  static const postSearch = 'post_search';
  static const postGet = 'post_get';
  static const postCreate = 'post_create';
}
