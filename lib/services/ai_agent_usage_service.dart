import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 角色卡本地使用次数（用于排序，不依赖后端）。
class AiAgentUsageService {
  AiAgentUsageService._();

  static final AiAgentUsageService _instance = AiAgentUsageService._();
  factory AiAgentUsageService() => _instance;

  static const _key = 'ai_agent_usage_counts_json';

  Future<Map<String, int>> loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), (v is num) ? v.toInt() : 0),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> increment(String agentId) async {
    if (agentId.isEmpty) return;
    final counts = await loadCounts();
    counts[agentId] = (counts[agentId] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(counts));
  }
}
