import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_profile.dart';
import 'ai_cloud_config_service.dart';
import 'ai_db_service.dart';

class AiProviderService {
  AiProviderService._();

  static final AiProviderService _instance = AiProviderService._();
  factory AiProviderService() => _instance;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const String _webProfilesKey = 'ai_provider_profiles_web_json';
  static const String _lastSelectedProfileKey = 'ai_last_selected_provider_id';

  String _apiKeyStorageKey(String profileId) =>
      'ai_provider_api_key_$profileId';

  Future<List<AiProviderProfile>> listProfiles() async {
    final out = await _listLocalProfiles();
    unawaited(_refreshCloudProfilesToLocal());
    return out;
  }

  Future<List<AiProviderProfile>> _listLocalProfiles() async {
    final out = <AiProviderProfile>[];
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webProfilesKey);
      if (raw == null || raw.isEmpty) return out;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          out.addAll(
            decoded.whereType<Map>().map(
                (e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e))),
          );
        }
      } catch (_) {}
      return out;
    }
    final locals = await AiDbService().getProviderProfiles();
    out.addAll(locals);
    return out;
  }

  Future<void> _refreshCloudProfilesToLocal() async {
    try {
      final cloudProfiles = await AiCloudConfigService()
          .fetchProviders()
          .timeout(const Duration(seconds: 5));
      if (cloudProfiles == null) return;
      final parsed = cloudProfiles
          .map((e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      await _saveProfilesToLocal(parsed);
    } catch (_) {
      // 静默回退到本地缓存。
    }
  }

  Future<void> _saveProfilesToLocal(List<AiProviderProfile> profiles) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _webProfilesKey,
        jsonEncode(profiles.map((e) => e.toMap()).toList()),
      );
      return;
    }
    final db = AiDbService();
    final existing = await db.getProviderProfiles();
    final existingIds = existing.map((e) => e.id).toSet();
    for (final profile in profiles) {
      if (existingIds.contains(profile.id)) {
        await db.updateProviderProfile(profile);
      } else {
        await db.insertProviderProfile(profile);
      }
    }
  }

  Future<AiProviderProfile> resolveProfile(String? id) async {
    if (id == null || id.trim().isEmpty) {
      return AiProviderProfile.builtinBackend();
    }
    if (id == AiProviderProfile.builtinBackendId) {
      return AiProviderProfile.builtinBackend();
    }
    final profiles = await listProfiles();
    for (final item in profiles) {
      if (item.id == id) return item;
    }
    return AiProviderProfile.builtinBackend();
  }

  Future<void> saveProfile(
    AiProviderProfile profile, {
    String? apiKey,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final current = await listProfiles();
      final customs = current.where((e) => !e.isBuiltin).toList();
      final next = <AiProviderProfile>[];
      var replaced = false;
      for (final item in customs) {
        if (item.id == profile.id) {
          next.add(profile);
          replaced = true;
        } else {
          next.add(item);
        }
      }
      if (!replaced) {
        next.add(profile);
      }
      await prefs.setString(
        _webProfilesKey,
        jsonEncode(next.map((e) => e.toMap()).toList()),
      );
    } else {
      final db = AiDbService();
      final exists =
          (await db.getProviderProfiles()).any((e) => e.id == profile.id);
      if (exists) {
        await db.updateProviderProfile(profile);
      } else {
        await db.insertProviderProfile(profile);
      }
    }
    await AiCloudConfigService().upsertProvider(profile.toMap());
    if (apiKey != null) {
      await writeApiKey(profile.id, apiKey);
    }
  }

  Future<void> deleteProfile(String profileId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final current = await listProfiles();
      final next = current
          .where((e) => !e.isBuiltin && e.id != profileId)
          .map((e) => e.toMap())
          .toList();
      await prefs.setString(_webProfilesKey, jsonEncode(next));
    } else {
      await AiDbService().deleteProviderProfile(profileId);
    }
    await AiCloudConfigService().deleteProvider(profileId);
    await deleteApiKey(profileId);
  }

  Future<String> readApiKey(String profileId) async {
    if (profileId.isEmpty) return '';
    final key = _apiKeyStorageKey(profileId);
    try {
      String raw;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(key) ?? '';
      } else {
        raw = await _secureStorage.read(key: key) ?? '';
      }
      return normalizeApiKey(raw);
    } catch (_) {
      return '';
    }
  }

  static String normalizeApiKey(String raw) {
    var key = raw.trim();
    if (key.toLowerCase().startsWith('bearer ')) {
      key = key.substring(7).trim();
    }
    return key;
  }

  Future<void> writeApiKey(String profileId, String value) async {
    final key = _apiKeyStorageKey(profileId);
    final normalized = normalizeApiKey(value);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, normalized);
      return;
    }
    await _secureStorage.write(key: key, value: normalized);
  }

  Future<void> deleteApiKey(String profileId) async {
    final key = _apiKeyStorageKey(profileId);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

  Future<void> saveLastSelectedProfileId(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedProfileKey, profileId);
    await AiCloudConfigService().savePreferences({
      'last_selected_provider_id': profileId,
    });
  }

  Future<String?> readLastSelectedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getString(_lastSelectedProfileKey)?.trim();
    if (localValue != null && localValue.isNotEmpty) {
      return localValue;
    }

    final cloud = await AiCloudConfigService().fetch();
    final cloudValue =
        cloud?.preferences['last_selected_provider_id']?.toString().trim();
    if (cloudValue != null && cloudValue.isNotEmpty) {
      await prefs.setString(_lastSelectedProfileKey, cloudValue);
      return cloudValue;
    }
    return null;
  }
}
