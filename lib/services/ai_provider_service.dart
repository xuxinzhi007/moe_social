import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_profile.dart';
import 'ai_cloud_config_service.dart';
import 'ai_db_service.dart';

class AiCloudSyncException implements Exception {
  final String message;

  const AiCloudSyncException(this.message);

  @override
  String toString() => message;
}

enum AiProviderSelectionSource {
  explicitCustom,
  explicitBuiltin,
  autoSelectedCustom,
  defaultBuiltin,
}

class AiProviderSelection {
  const AiProviderSelection({
    required this.profile,
    required this.source,
  });

  final AiProviderProfile profile;
  final AiProviderSelectionSource source;

  bool get autoSelected =>
      source == AiProviderSelectionSource.autoSelectedCustom;
}

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
    final cloud = AiCloudConfigService();
    if (!cloud.isAuthenticated) return out;
    if (out.isEmpty) {
      await _refreshCloudProfilesToLocal().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      return _listLocalProfiles();
    }
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
      final cloud = AiCloudConfigService();
      final profilesFuture =
          cloud.fetchProviders().timeout(const Duration(seconds: 5));
      final apiKeysFuture =
          cloud.fetchProviderApiKeys().timeout(const Duration(seconds: 5));
      final results = await Future.wait<Object?>([
        profilesFuture,
        apiKeysFuture,
      ]);
      final cloudProfiles = results[0] as List<Map<String, dynamic>>?;
      final cloudApiKeys = results[1] as Map<String, String>?;
      if (cloudProfiles != null) {
        final parsed = cloudProfiles
            .map((e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        await _saveProfilesToLocal(parsed);
      }
      if (cloudApiKeys != null) {
        for (final entry in cloudApiKeys.entries) {
          await writeApiKey(entry.key, entry.value);
        }
      }
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
    final normalizedId = id?.trim() ?? '';
    if (normalizedId.isEmpty ||
        AiProviderProfile.isBuiltinProviderId(normalizedId)) {
      return AiProviderProfile.builtinBackend();
    }
    final profiles = await listProfiles();
    for (final item in profiles) {
      if (item.id == normalizedId) return item;
    }
    return AiProviderProfile.builtinBackend();
  }

  /// 解析聊天当前使用的 Provider，并修复旧版本留下的失效选择。
  Future<AiProviderSelection> resolveActiveProvider({
    List<AiProviderProfile>? profiles,
    String? selectedId,
  }) async {
    final available = profiles ?? await listProfiles();
    final storedId = selectedId ?? await readLastSelectedProfileId();
    final selection = resolveSelection(
      profiles: available,
      selectedId: storedId,
    );
    if (selection.autoSelected) {
      try {
        await saveLastSelectedProfileId(selection.profile.id);
      } catch (_) {
        // 当前设备上的自动选择仍然有效，云端偏好下次再补写。
      }
    }
    return selection;
  }

  /// 根据已加载的 Provider 列表计算当前选择，供页面和测试共享同一规则。
  static AiProviderSelection resolveSelection({
    required List<AiProviderProfile> profiles,
    String? selectedId,
  }) {
    final normalizedId = selectedId?.trim() ?? '';
    if (normalizedId.isNotEmpty) {
      for (final profile in profiles) {
        if (profile.id == normalizedId && !profile.isBuiltin) {
          return AiProviderSelection(
            profile: profile,
            source: AiProviderSelectionSource.explicitCustom,
          );
        }
      }
    }

    final canAutoSelect = normalizedId.isEmpty ||
        AiProviderProfile.isLegacyBuiltinProviderId(normalizedId) ||
        !AiProviderProfile.isBuiltinProviderId(normalizedId);
    if (canAutoSelect) {
      final configured = profiles
          .where(
            (profile) =>
                !profile.isBuiltin &&
                profile.baseUrl.trim().isNotEmpty &&
                profile.effectiveModelId.isNotEmpty,
          )
          .toList(growable: false);
      if (configured.length == 1) {
        return AiProviderSelection(
          profile: configured.first,
          source: AiProviderSelectionSource.autoSelectedCustom,
        );
      }
    }

    return AiProviderSelection(
      profile: AiProviderProfile.builtinBackend(),
      source: normalizedId.isNotEmpty &&
              AiProviderProfile.isBuiltinProviderId(normalizedId)
          ? AiProviderSelectionSource.explicitBuiltin
          : AiProviderSelectionSource.defaultBuiltin,
    );
  }

  Future<void> saveProfile(
    AiProviderProfile profile, {
    String? apiKey,
    bool clearApiKey = false,
    bool? syncApiKeyToCloud,
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

    if (apiKey != null) {
      final normalized = normalizeApiKey(apiKey);
      if (normalized.isNotEmpty) {
        await writeApiKey(profile.id, normalized);
      } else if (clearApiKey) {
        await deleteApiKey(profile.id);
      }
    }

    final cloud = AiCloudConfigService();
    // Provider 元数据可以云同步；密钥只有用户明确选择时才同步。
    if (cloud.isAuthenticated) {
      try {
        await cloud.upsertProvider(profile.toMap());
      } catch (_) {
        // 下次 listProfiles 时会再次尝试同步。
      }
    }
    if (syncApiKeyToCloud != null) {
      final normalized = normalizeApiKey(apiKey ?? '');
      try {
        if (syncApiKeyToCloud && normalized.isNotEmpty) {
          await cloud.setProviderApiKey(
            profile.id,
            normalized,
          );
        } else {
          await cloud.deleteProviderApiKey(profile.id);
        }
      } catch (_) {
        throw const AiCloudSyncException('已保存到本机，但账号同步失败，请稍后重试');
      }
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
    await deleteApiKey(profileId);
    final cloud = AiCloudConfigService();
    if (cloud.isAuthenticated) {
      try {
        await cloud.deleteProvider(profileId);
        await cloud.deleteProviderApiKey(profileId);
      } catch (_) {
        // 本地删除已完成，云端删除下次同步时再处理。
      }
    }
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
      final normalized = normalizeApiKey(raw);
      if (normalized.isNotEmpty || !AiCloudConfigService().isAuthenticated) {
        return normalized;
      }
      final cloudKeys = await AiCloudConfigService().fetchProviderApiKeys();
      final cloudValue = normalizeApiKey(cloudKeys?[profileId] ?? '');
      if (cloudValue.isNotEmpty) {
        await writeApiKey(profileId, cloudValue);
      }
      return cloudValue;
    } catch (_) {
      return '';
    }
  }

  Future<Set<String>?> readCloudApiKeyProfileIds() async {
    if (!AiCloudConfigService().isAuthenticated) return <String>{};
    final cloudKeys = await AiCloudConfigService().fetchProviderApiKeys();
    return cloudKeys?.keys.toSet();
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
    final normalized = profileId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedProfileKey, normalized);
    final cloud = AiCloudConfigService();
    if (!cloud.isAuthenticated) return;
    try {
      await cloud.savePreferences({
        'last_selected_provider_id': normalized,
      });
    } catch (_) {
      // 本机选择已保存；网络恢复后下一次配置同步会再次写入。
    }
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
