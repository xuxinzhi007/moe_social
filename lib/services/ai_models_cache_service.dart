import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 按 Provider 缓存上次成功的模型列表。
class AiModelsCacheService {
  AiModelsCacheService._();

  static final AiModelsCacheService _instance = AiModelsCacheService._();
  factory AiModelsCacheService() => _instance;

  static String _key(String profileId) => 'ai_models_cache_$profileId';

  Future<List<String>> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> write(String profileId, List<String> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), jsonEncode(models));
  }
}
