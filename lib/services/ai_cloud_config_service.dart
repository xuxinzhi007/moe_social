import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_response.dart';
import 'api_service.dart';

@visibleForTesting
List<Map<String, dynamic>> parseAiResourceItems(
  Map<String, dynamic> response,
) {
  return ApiResponse.listOf(response, keys: const ['items']).map((raw) {
    if (raw is! Map) {
      throw const FormatException('AI resource item must be an object');
    }
    final item = Map<String, dynamic>.from(raw);
    final payloadJson = item['payload_json'] ?? item['payloadJson'];
    if (payloadJson is! String) {
      throw const FormatException('AI resource payload_json must be a string');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw const FormatException('AI resource payload_json must be an object');
    }
    final payload = Map<String, dynamic>.from(decoded);
    final id = item['id'];
    if (id != null) payload['id'] = id.toString();
    return payload;
  }).toList(growable: false);
}

class AiCloudConfigSnapshot {
  final List<Map<String, dynamic>> providerProfiles;
  final Map<String, String> providerApiKeys;
  final List<Map<String, dynamic>> agents;
  final List<Map<String, dynamic>> lorebooks;
  final String userPersona;
  final Map<String, dynamic> preferences;

  const AiCloudConfigSnapshot({
    required this.providerProfiles,
    required this.providerApiKeys,
    required this.agents,
    required this.lorebooks,
    required this.userPersona,
    required this.preferences,
  });
}

class AiCloudConfigService {
  AiCloudConfigService._();

  static final AiCloudConfigService _instance = AiCloudConfigService._();
  factory AiCloudConfigService() => _instance;
  static const Duration _readTimeout = Duration(seconds: 6);
  static const Duration _writeTimeout = Duration(seconds: 5);

  bool get isAuthenticated => (ApiService.token ?? '').trim().isNotEmpty;

  Future<AiCloudConfigSnapshot?> fetch() async {
    if (!isAuthenticated) return null;
    try {
      final resp = await ApiService.get('/api/ai/config').timeout(_readTimeout);
      final data = ApiResponse.object(resp);
      final profiles = (data['provider_profiles'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final agents = (data['agents'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final lorebooks = (data['lorebooks'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final prefs = (data['preferences'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final providerApiKeys = _parseProviderApiKeys(data);
      return AiCloudConfigSnapshot(
        providerProfiles: profiles,
        providerApiKeys: providerApiKeys,
        agents: agents,
        lorebooks: lorebooks,
        userPersona: (data['user_persona'] ?? '').toString(),
        preferences: prefs,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>?> fetchProviderApiKeys() async {
    final snapshot = await fetch();
    return snapshot?.providerApiKeys;
  }

  Future<List<Map<String, dynamic>>?> fetchProviders() async {
    if (!isAuthenticated) return null;
    try {
      final resp =
          await ApiService.get('/api/ai/providers').timeout(_readTimeout);
      return parseAiResourceItems(resp);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertProvider(Map<String, dynamic> data) async {
    await _upsertResource('/api/ai/providers', data);
  }

  Future<void> deleteProvider(String id) async {
    await ApiService.delete(
      '/api/ai/providers/${Uri.encodeComponent(id)}',
    ).timeout(_writeTimeout);
  }

  Future<List<Map<String, dynamic>>?> fetchAgents() async {
    try {
      final resp = await ApiService.get('/api/ai/agents').timeout(_readTimeout);
      return parseAiResourceItems(resp);
    } catch (_) {
      return null;
    }
  }

  /// 广场：各用户已发布（is_public=true）的角色卡 JSON 列表。
  Future<List<Map<String, dynamic>>?> fetchPublicAgents(
      {int limit = 50}) async {
    try {
      final resp = await ApiService.get(
        '/api/ai/agents/public?limit=$limit',
      ).timeout(_readTimeout);
      return parseAiResourceItems(resp);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertAgent(Map<String, dynamic> data) async {
    await _upsertResource('/api/ai/agents', data);
  }

  Future<void> deleteAgent(String id) async {
    await ApiService.delete(
      '/api/ai/agents/${Uri.encodeComponent(id)}',
    ).timeout(_writeTimeout);
  }

  Future<List<Map<String, dynamic>>?> fetchLorebooks() async {
    try {
      final resp =
          await ApiService.get('/api/ai/lorebooks').timeout(_readTimeout);
      return parseAiResourceItems(resp);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertLorebook(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> entries,
  ) async {
    final payload = Map<String, dynamic>.from(data)..['entries'] = entries;
    await _upsertResource('/api/ai/lorebooks', payload);
  }

  Future<void> deleteLorebook(String id) async {
    await ApiService.delete(
      '/api/ai/lorebooks/${Uri.encodeComponent(id)}',
    ).timeout(_writeTimeout);
  }

  Future<void> saveUserPersona(String persona) async {
    await _put({
      'user_persona': persona,
      'has_user_persona': true,
    });
  }

  Future<void> savePreferences(Map<String, dynamic> preferences) async {
    await _put({'preferences': preferences});
  }

  /// 保存单个 Provider 的账号同步密钥；空值表示删除云端密钥。
  Future<void> setProviderApiKey(String profileId, String apiKey) async {
    final id = profileId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(profileId, 'profileId', '不能为空');
    }
    await _put({
      'provider_api_key_profile_id': id,
      'provider_api_key': apiKey.trim(),
      'has_provider_api_key': true,
    });
  }

  Future<void> deleteProviderApiKey(String profileId) async {
    await setProviderApiKey(profileId, '');
  }

  Future<void> _put(Map<String, dynamic> body) async {
    await ApiService.put('/api/ai/config', body: body).timeout(_writeTimeout);
  }

  Future<void> _upsertResource(
    String path,
    Map<String, dynamic> payload,
  ) async {
    await ApiService.post(
      path,
      body: {
        'id': payload['id']?.toString() ?? '',
        'payload_json': jsonEncode(payload),
      },
    ).timeout(_writeTimeout);
  }

  Map<String, String> _parseProviderApiKeys(Map<String, dynamic> data) {
    final raw = data['provider_api_keys_json'] ??
        data['providerApiKeysJson'] ??
        data['provider_api_keys'] ??
        data['providerApiKeys'];
    dynamic decoded = raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null;
      }
    }
    if (decoded is! Map) return const <String, String>{};
    final out = <String, String>{};
    for (final entry in decoded.entries) {
      final profileId = entry.key.toString().trim();
      final apiKey = entry.value?.toString().trim() ?? '';
      if (profileId.isNotEmpty && apiKey.isNotEmpty) {
        out[profileId] = apiKey;
      }
    }
    return out;
  }
}
