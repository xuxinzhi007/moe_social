import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/ai_provider_profile.dart';
import 'api_client.dart';

/// 按 Provider 缓存上次成功的模型列表；后端私人目录按账号与后端隔离。
class AiModelsCacheService {
  AiModelsCacheService._();

  static final AiModelsCacheService _instance = AiModelsCacheService._();
  factory AiModelsCacheService() => _instance;

  static Future<String?> _key(String profileId) async {
    if (profileId != AiProviderProfile.builtinBackendId) {
      return 'ai_models_cache_$profileId';
    }
    final token = ApiClient.token;
    if (token == null || token.isEmpty) return null;
    try {
      final userId = await AuthService.getUserId();
      if (ApiClient.token != token) return null;
      final scope =
          base64Url.encode(utf8.encode('${ApiClient.baseUrl}|$userId'));
      // 不迁移旧的无账号目录，无法证明其中模型归属。
      return 'ai_models_cache_${profileId}_$scope';
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> read(String profileId) async {
    final key = await _key(profileId);
    if (key == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _normalize(decoded);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> write(String profileId, List<String> models) async {
    final key = await _key(profileId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_normalize(models)));
  }

  Future<void> invalidate(String profileId) async {
    final key = await _key(profileId);
    final prefs = await SharedPreferences.getInstance();
    if (key != null) await prefs.remove(key);
    await prefs.remove('ai_models_cache_$profileId');
  }

  static List<String> _normalize(Iterable<dynamic> models) {
    return models
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
