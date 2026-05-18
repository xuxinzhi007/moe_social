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

  String _apiKeyStorageKey(String profileId) => 'ai_provider_api_key_$profileId';

  Future<List<AiProviderProfile>> listProfiles() async {
    final out = <AiProviderProfile>[AiProviderProfile.builtinBackend()];
    final cloudProfiles = await AiCloudConfigService().fetchProviders();
    if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
      out.addAll(
        cloudProfiles
            .map((e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e))),
      );
      return out;
    }
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webProfilesKey);
      if (raw == null || raw.isEmpty) return out;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          out.addAll(
            decoded
                .whereType<Map>()
                .map((e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e))),
          );
        }
      } catch (_) {}
      return out;
    }
    final locals = await AiDbService().getProviderProfiles();
    out.addAll(locals);
    return out;
  }

  Future<AiProviderProfile> resolveProfile(String? id) async {
    if (id == null || id.trim().isEmpty) {
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
      final customs = current.where((e) => !e.isBuiltinBackend).toList();
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
          .where((e) => !e.isBuiltinBackend && e.id != profileId)
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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(key) ?? '';
      }
      return await _secureStorage.read(key: key) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> writeApiKey(String profileId, String value) async {
    final key = _apiKeyStorageKey(profileId);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
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
    final cloud = await AiCloudConfigService().fetch();
    final cloudValue =
        cloud?.preferences['last_selected_provider_id']?.toString().trim();
    if (cloudValue != null && cloudValue.isNotEmpty) {
      return cloudValue;
    }
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastSelectedProfileKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
