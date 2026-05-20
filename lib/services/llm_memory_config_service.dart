import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// 后端 LLM/记忆相关配置（与聊天 Provider 无关）。
///
/// 提取、总结等后台任务应使用 [resolveMemoryModel]，勿使用角色绑定的 gpt/codex 模型名。
class LlmMemoryConfigService {
  LlmMemoryConfigService._();

  static final LlmMemoryConfigService _instance = LlmMemoryConfigService._();
  factory LlmMemoryConfigService() => _instance;

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const String _defaultMemoryModel = 'llama3';

  String? _cachedMemoryModel;
  DateTime? _cachedAt;

  /// 用于记忆提取/整理的模型 ID（来自 `GET /api/llm/config` → `ollama.memory_model`）。
  Future<String> resolveMemoryModel({String fallback = _defaultMemoryModel}) async {
    await _ensureLoaded();
    final model = _cachedMemoryModel?.trim() ?? '';
    if (model.isNotEmpty) return model;
    final fb = fallback.trim();
    return fb.isNotEmpty ? fb : _defaultMemoryModel;
  }

  Future<void> invalidate() async {
    _cachedMemoryModel = null;
    _cachedAt = null;
  }

  Future<void> _ensureLoaded() async {
    final cachedAt = _cachedAt;
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl &&
        _cachedMemoryModel != null) {
      return;
    }
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/config');
      ApiService.logDirectHttp('GET', uri);
      final response = await http
          .get(
            uri,
            headers: ApiService.mergeTunnelHeaders(uri, headers: {
              if (ApiService.token case final t?) 'Authorization': 'Bearer $t',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! Map) return;
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final ollama = data['ollama'];
      if (ollama is Map) {
        final raw = (ollama['memory_model'] as String?)?.trim() ?? '';
        if (raw.isNotEmpty) {
          _cachedMemoryModel = raw;
          _cachedAt = DateTime.now();
          if (kDebugMode) {
            debugPrint('🧠 [Memory] memory_model=$raw (from /api/llm/config)');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🧠 [Memory] load config failed: $e');
      }
    }
  }
}
