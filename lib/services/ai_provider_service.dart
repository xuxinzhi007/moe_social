import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_profile.dart';
import 'ai_cloud_config_service.dart';
import 'api_service.dart';

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
  static const String _lastSelectedProfileKey = 'ai_last_selected_provider_id';

  String _apiKeyStorageKey(String profileId) =>
      'ai_provider_api_key_$profileId';

  String get backendBaseUrl => ApiService.baseUrl;

  /// 已登录时只返回 `/api/ai/providers`。空列表就是没有自备来源。
  Future<List<AiProviderProfile>> listProfiles() async {
    final cloud = AiCloudConfigService();
    if (!cloud.isAuthenticated) return const [];
    final raw = await cloud.fetchProviders();
    if (raw == null) {
      throw Exception('加载模型来源失败');
    }
    return raw
        .map((e) => AiProviderProfile.fromMap(Map<String, dynamic>.from(e)))
        .toList();
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
    final cloud = AiCloudConfigService();
    if (!cloud.isAuthenticated) {
      throw const AiCloudSyncException('请先登录后再保存模型来源');
    }
    await cloud.upsertProvider(profile.toMap());

    if (apiKey != null) {
      final normalized = normalizeApiKey(apiKey);
      if (normalized.isNotEmpty) {
        await writeApiKey(profile.id, normalized);
      } else if (clearApiKey) {
        await deleteApiKey(profile.id);
      }
    }

    if (syncApiKeyToCloud != null) {
      final normalized = normalizeApiKey(apiKey ?? '');
      if (syncApiKeyToCloud && normalized.isNotEmpty) {
        await cloud.setProviderApiKey(profile.id, normalized);
      } else {
        await cloud.deleteProviderApiKey(profile.id);
      }
    }
  }

  Future<void> deleteProfile(String profileId) async {
    final cloud = AiCloudConfigService();
    if (!cloud.isAuthenticated) {
      throw const AiCloudSyncException('请先登录后再删除模型来源');
    }
    await cloud.deleteProvider(profileId);
    await cloud.deleteProviderApiKey(profileId);
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
