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

  Future<AiCloudConfigSnapshot?> fetch() async {
    try {
      final resp = await ApiService.get('/api/ai/config');
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
      final prefs = (data['preferences'] as Map?)
              ?.cast<String, dynamic>() ??
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
      final resp = await ApiService.get('/api/ai/providers');
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertProvider(Map<String, dynamic> data) async {
    try {
      await ApiService.put('/api/ai/providers', body: {'data': data});
    } catch (_) {}
  }

  Future<void> deleteProvider(String id) async {
    try {
      await ApiService.delete('/api/ai/providers?id=$id');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> fetchAgents() async {
    try {
      final resp = await ApiService.get('/api/ai/agents');
      return (resp['data'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertAgent(Map<String, dynamic> data) async {
    try {
      await ApiService.put('/api/ai/agents', body: {'data': data});
    } catch (_) {}
  }

  Future<void> deleteAgent(String id) async {
    try {
      await ApiService.delete('/api/ai/agents?id=$id');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> fetchLorebooks() async {
    try {
      final resp = await ApiService.get('/api/ai/lorebooks');
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
    try {
      await ApiService.put(
        '/api/ai/lorebooks',
        body: {'data': data, 'entries': entries},
      );
    } catch (_) {}
  }

  Future<void> deleteLorebook(String id) async {
    try {
      await ApiService.delete('/api/ai/lorebooks?id=$id');
    } catch (_) {}
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
    try {
      await ApiService.put('/api/ai/config', body: body);
    } catch (_) {
      // keep local-first fallback silent
    }
  }
}
