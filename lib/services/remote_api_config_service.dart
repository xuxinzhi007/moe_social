import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 远程 API 基址（生产环境冷启动解析一次）。
///
/// ## 你只需要维护两处（内容保持一致）
/// 1. **本机** `backend/config/config.yaml` → `app_client.public_api_base_url`
/// 2. **GitHub** `lib/config/moe_api.json`（或 `MOE_API_CONFIG_URL`）→ `api_base_url`
///
/// 换 ngrok 时两处写成**同一个新域名**。其它文件（含 Dart 兜底）不必跟着改。
/// 若只改了 GitHub 忘改 yaml：client-config 会仍返回旧 yaml；App 在「经 GitHub 入口拉取」时会
/// **以 GitHub 为准**并提示你补改 yaml。
///
/// ## App 只信一件事
/// **`GET {某入口}/api/public/client-config` 返回的 `api_base_url`**（即 yaml 里的值）。
/// - 能连上接口 → 用返回值写入缓存，**自动纠正**旧缓存 / 旧 GitHub 与 yaml 不一致的情况。
/// - 一直连不上 → 才临时用缓存或 GitHub 上的字符串（并提示），此时应检查两处配置或网络。
///
/// ## 顺序（简单）
/// 1. 用**缓存**当入口问 client-config → 成功则结束。
/// 2. 失败则用 **Dart 兜底**再问一次（仅首装无缓存时主要用到）。
/// 3. 仍失败则 **拉 GitHub 一次**，用 JSON 里的地址再问 client-config → 成功则结束。
/// 4. 仍失败：有缓存用缓存，否则用 GitHub 地址，再没有用 Dart 兜底。
class RemoteApiConfigService {
  RemoteApiConfigService._();

  static String? _startupConfigHint;

  static const String _prefsKey = 'moe_remote_api_base_url_v2';

  static const String _clientConfigPath = '/api/public/client-config';

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

  static Map<String, String> _tunnelBypassHeadersForHost(String host) {
    final h = host.toLowerCase();
    if (h.contains('ngrok-free.app') ||
        h.contains('ngrok-free.dev') ||
        h.endsWith('.ngrok.io') ||
        h.contains('ngrok.app')) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }
    return const {};
  }

  /// 向该入口请求 client-config，返回 yaml 中的权威 `api_base_url`。
  static Future<String?> _fetchOfficialFromEntry(
    String? base,
    Duration timeout,
  ) async {
    final b = normalizeBaseUrl(base);
    if (b == null) return null;
    final uri = Uri.parse('$b$_clientConfigPath');
    try {
      final headers = _tunnelBypassHeadersForHost(uri.host);
      final res = await http.get(uri, headers: headers).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return _parseApiBaseFromJsonMap(decoded);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: $uri 不可用 $e');
      }
      return null;
    }
  }

  static Future<String?> _tryStaticJsonUrl(
    String configUrl,
    Duration timeout,
  ) async {
    try {
      final uri = Uri.parse(configUrl);
      final headers = _tunnelBypassHeadersForHost(uri.host);
      final res = await http.get(uri, headers: headers).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return _parseApiBaseFromJsonMap(decoded);
        }
      }
      if (kDebugMode) {
        debugPrint(
          'RemoteApiConfig: 静态 JSON 失败 status=${res.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 静态 JSON 异常 $e');
      }
    }
    return null;
  }

  static String? takeStartupConfigHint() {
    final h = _startupConfigHint;
    _startupConfigHint = null;
    return h;
  }

  static Future<String> resolveProductionBaseUrl({
    required String fallbackBakedUrl,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fallback =
        normalizeBaseUrl(fallbackBakedUrl) ?? 'http://127.0.0.1:8888';
    final cached = normalizeBaseUrl(prefs.getString(_prefsKey));

    String? official = cached != null
        ? await _fetchOfficialFromEntry(cached, timeout)
        : null;
    official ??= await _fetchOfficialFromEntry(fallback, timeout);

    String? githubBootstrap;
    var officialCameFromGithubEntry = false;
    final jsonUrl = _effectiveJsonConfigUrl;
    if (official == null && jsonUrl.isNotEmpty) {
      githubBootstrap = await _tryStaticJsonUrl(jsonUrl, timeout);
      if (githubBootstrap != null) {
        official =
            await _fetchOfficialFromEntry(githubBootstrap, timeout);
        if (official != null) {
          officialCameFromGithubEntry = true;
        }
      }
    }

    if (official != null) {
      if (officialCameFromGithubEntry && githubBootstrap != null) {
        final o = normalizeBaseUrl(official)!;
        final g = normalizeBaseUrl(githubBootstrap)!;
        if (o != g) {
          official = g;
          _startupConfigHint =
              'config.yaml 与 GitHub 地址不一致，已暂用 GitHub。请尽快同步 backend/config/config.yaml 中的 app_client.public_api_base_url。';
          if (kDebugMode) {
            debugPrint(
              'RemoteApiConfig: yaml 返回 $o 与 GitHub $g 不一致，采用 GitHub',
            );
          }
        } else {
          _startupConfigHint = null;
        }
      } else {
        _startupConfigHint = null;
      }
      await prefs.setString(_prefsKey, official);
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 使用基址 $official');
      }
      return official;
    }

    if (cached != null) {
      _startupConfigHint =
          '无法从服务器获取最新地址，暂用上次缓存。请确认 yaml 与 GitHub 已改为同一新域名，或稍后重试。';
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 降级使用缓存 $cached');
      }
      return cached;
    }

    if (githubBootstrap != null) {
      _startupConfigHint =
          '未能完成服务器校验，暂用 GitHub 上的地址。请确认隧道与 yaml 正常。';
      await prefs.setString(_prefsKey, githubBootstrap);
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 降级使用 GitHub $githubBootstrap');
      }
      return githubBootstrap;
    }

    _startupConfigHint =
        '无法拉取配置，使用应用内置兜底。请检查网络或 GitHub moe_api.json。';
    if (kDebugMode) {
      debugPrint('RemoteApiConfig: 降级使用兜底 $fallback');
    }
    return fallback;
  }
}
