import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 从网络读取「当前 API 根地址」，避免隧道域名变动时反复发版。
///
/// **优先级（生产包 `initRemoteProductionBaseUrl`）**
/// 1. **后端接口** `GET {入口}/api/public/client-config`  
///    入口依次尝试：本地缓存的上次基址 → 代码里兜底 `_productionUrl`。  
///    内容由 `backend/config/config.yaml` 的 `app_client.public_api_base_url` 提供，**改 yaml 并重启 API 即生效**。
/// 2. **GitHub 等静态 JSON**（可选）：`--dart-define=MOE_API_CONFIG_URL=...` 或 [kRemoteApiConfigJsonUrl]  
///    格式：`{ "api_base_url": "http://..." }`（亦支持 `apiBaseUrl` 等键名）。
/// 3. 本地 **SharedPreferences 缓存**。
/// 4. 调用方传入的 **兜底地址**。
class RemoteApiConfigService {
  RemoteApiConfigService._();

  static const String _prefsKey = 'moe_remote_api_base_url_v1';

  /// 与 go-zero 路由一致（无鉴权）
  static const String _clientConfigPath = '/api/public/client-config';

  /// 可选：GitHub raw 等静态 JSON（后端不可用时作备份）
  static const String kRemoteApiConfigJsonUrl =
      'https://raw.githubusercontent.com/xuxinzhi007/moe_social/main/lib/config/moe_api.json';

  static String get _effectiveJsonConfigUrl {
    const fromEnv = String.fromEnvironment(
      'MOE_API_CONFIG_URL',
      defaultValue: '',
    );
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    return kRemoteApiConfigJsonUrl.trim();
  }

  /// 规范化：去尾斜杠、必须是 http/https 且有 host。
  static String? normalizeBaseUrl(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return s;
  }

  static String? _parseApiBaseFromJsonMap(Map<String, dynamic> map) {
    final raw = map['api_base_url'] ??
        map['apiBaseUrl'] ??
        map['base_url'] ??
        map['baseUrl'];
    if (raw is String) {
      return normalizeBaseUrl(raw);
    }
    return null;
  }

  static Future<String?> _tryBackendClientConfig(
    List<String?> baseCandidates,
    Duration timeout,
  ) async {
    final seen = <String>{};
    for (final c in baseCandidates) {
      final base = normalizeBaseUrl(c);
      if (base == null || seen.contains(base)) continue;
      seen.add(base);
      final uri = Uri.parse('$base$_clientConfigPath');
      try {
        final res = await http.get(uri).timeout(timeout);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = json.decode(utf8.decode(res.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            final next = _parseApiBaseFromJsonMap(decoded);
            if (next != null) {
              return next;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('RemoteApiConfig: 后端 $uri 不可用 $e');
        }
      }
    }
    return null;
  }

  static Future<String?> _tryStaticJsonUrl(
    String configUrl,
    Duration timeout,
  ) async {
    try {
      final uri = Uri.parse(configUrl);
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return _parseApiBaseFromJsonMap(decoded);
        }
      }
      if (kDebugMode) {
        debugPrint(
          'RemoteApiConfig: 静态 JSON 拉取失败 status=${res.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 静态 JSON 异常 $e');
      }
    }
    return null;
  }

  /// 启动时调用：先尽力从后端 yaml 拉取，再可选 GitHub，再缓存与兜底。
  static Future<String> resolveProductionBaseUrl({
    required String fallbackBakedUrl,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = normalizeBaseUrl(fallbackBakedUrl) ?? 'http://127.0.0.1:8888';
    final cached = normalizeBaseUrl(prefs.getString(_prefsKey));

    final fromBackend = await _tryBackendClientConfig(
      [cached, fallback],
      timeout,
    );
    if (fromBackend != null) {
      await prefs.setString(_prefsKey, fromBackend);
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 使用后端下发的 API 基址 $fromBackend');
      }
      return fromBackend;
    }

    final jsonUrl = _effectiveJsonConfigUrl;
    if (jsonUrl.isNotEmpty) {
      final fromJson = await _tryStaticJsonUrl(jsonUrl, timeout);
      if (fromJson != null) {
        await prefs.setString(_prefsKey, fromJson);
        if (kDebugMode) {
          debugPrint('RemoteApiConfig: 使用静态 JSON 的 API 基址 $fromJson');
        }
        return fromJson;
      }
    }

    if (cached != null) {
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 使用本地缓存 $cached');
      }
      return cached;
    }
    return fallback;
  }
}
