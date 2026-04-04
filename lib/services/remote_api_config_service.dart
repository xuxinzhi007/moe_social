import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 从网络读取「当前 API 根地址」，避免隧道域名变动时反复发版。
///
/// 在稳定位置托管一份 JSON（推荐 GitHub 仓库里的 raw 链接，改文件即生效）：
/// ```json
/// { "api_base_url": "http://你的新域名:端口" }
/// ```
/// 也支持驼峰键名 `apiBaseUrl`。
///
/// 地址来源优先级：
/// 1. 编译参数 `--dart-define=MOE_API_CONFIG_URL=https://.../moe_api.json`
/// 2. 下方 [kRemoteApiConfigJsonUrl]（可填一次 raw 链接后提交）
/// 3. 若都为空：不发起请求，仅用调用方传入的兜底地址。
class RemoteApiConfigService {
  RemoteApiConfigService._();

  static const String _prefsKey = 'moe_remote_api_base_url_v1';

  /// 与仓库内 `lib/config/moe_api.json` 对应：GitHub 打开该文件 → Raw → 复制地址栏。
  /// 若默认分支不是 main，把 URL 里的 `main` 改成你的分支名。
  static const String kRemoteApiConfigJsonUrl =
      'https://raw.githubusercontent.com/xuxinzhi007/moe_social/main/lib/config/moe_api.json';

  static String get _effectiveConfigUrl {
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

  /// 启动时调用：先请求远端 JSON，成功则写入缓存；失败则用上次缓存，再没有则用 [fallbackBakedUrl]。
  static Future<String> resolveProductionBaseUrl({
    required String fallbackBakedUrl,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = normalizeBaseUrl(fallbackBakedUrl) ?? 'http://127.0.0.1:8888';

    final configUrl = _effectiveConfigUrl;
    if (configUrl.isEmpty) {
      final cached = normalizeBaseUrl(prefs.getString(_prefsKey));
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('RemoteApiConfig: 未配置 MOE_API_CONFIG_URL，使用本地缓存 $cached');
        }
        return cached;
      }
      return fallback;
    }

    try {
      final uri = Uri.parse(configUrl);
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final raw = decoded['api_base_url'] ??
              decoded['apiBaseUrl'] ??
              decoded['base_url'] ??
              decoded['baseUrl'];
          if (raw is String) {
            final next = normalizeBaseUrl(raw);
            if (next != null) {
              await prefs.setString(_prefsKey, next);
              if (kDebugMode) {
                debugPrint('RemoteApiConfig: 已拉取 API 基址 $next');
              }
              return next;
            }
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          'RemoteApiConfig: 拉取失败 status=${res.statusCode}，尝试缓存或兜底',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteApiConfig: 请求异常 $e，尝试缓存或兜底');
      }
    }

    final cached = normalizeBaseUrl(prefs.getString(_prefsKey));
    if (cached != null) {
      return cached;
    }
    return fallback;
  }
}
