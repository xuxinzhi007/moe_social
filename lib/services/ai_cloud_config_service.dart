import 'dart:async';

import 'api_service.dart';

class AiCloudConfigSnapshot {
  final List<Map<String, dynamic>> providerProfiles;
  final List<Map<String, dynamic>> agents;
  final List<Map<String, dynamic>> lorebooks;
  final String userPersona;
  final Map<String, dynamic> preferences;

  const AiCloudConfigSnapshot({
    required this.providerProfiles,
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

  Future<AiCloudConfigSnapshot?> fetch() async {
    try {
      final resp = await ApiService.get('/api/ai/config').timeout(_readTimeout);
      final data = (resp['data'] as Map?)?.cast<String, dynamic>() ?? {};
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
      return AiCloudConfigSnapshot(
        providerProfiles: profiles,
        agents: agents,
        lorebooks: lorebooks,
        userPersona: (data['user_persona'] ?? '').toString(),
        preferences: prefs,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchProviders() async {
    try {
      final resp =
          await ApiService.get('/api/ai/providers').timeout(_readTimeout);
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertProvider(Map<String, dynamic> data) async {
    await ApiService.put('/api/ai/providers', body: {'data': data})
        .timeout(_writeTimeout);
  }

  Future<void> deleteProvider(String id) async {
    await ApiService.delete('/api/ai/providers?id=$id').timeout(_writeTimeout);
  }

  Future<List<Map<String, dynamic>>?> fetchAgents() async {
    try {
      final resp = await ApiService.get('/api/ai/agents').timeout(_readTimeout);
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
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
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertAgent(Map<String, dynamic> data) async {
    await ApiService.put('/api/ai/agents', body: {'data': data})
        .timeout(_writeTimeout);
  }

  Future<void> deleteAgent(String id) async {
    await ApiService.delete('/api/ai/agents?id=$id').timeout(_writeTimeout);
  }

  Future<List<Map<String, dynamic>>?> fetchLorebooks() async {
    try {
      final resp =
          await ApiService.get('/api/ai/lorebooks').timeout(_readTimeout);
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertLorebook(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> entries,
  ) async {
    await ApiService.put(
      '/api/ai/lorebooks',
      body: {'data': data, 'entries': entries},
    ).timeout(_writeTimeout);
  }

  Future<void> deleteLorebook(String id) async {
    await ApiService.delete('/api/ai/lorebooks?id=$id').timeout(_writeTimeout);
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

  Future<void> _put(Map<String, dynamic> body) async {
    await ApiService.put('/api/ai/config', body: body).timeout(_writeTimeout);
  }
}
