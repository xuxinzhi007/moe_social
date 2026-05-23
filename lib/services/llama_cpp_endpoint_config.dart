import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本机 llama.cpp server（OpenAI 兼容 `/v1/chat/completions`）地址配置。
///
/// Windows 上典型启动：
/// `llama-server.exe -m D:\llm_models\qwen2.gguf --host 0.0.0.0 --port 6633`
///
/// ngrok / 内网穿透：Host 填完整 `https://xxx.ngrok-free.dev`，Port 可留空（走 443）。
class LlamaCppEndpointConfig {
  LlamaCppEndpointConfig._();

  static const int defaultPort = 6633;
  static const String _kHostOverride = 'llama_cpp_host_override';
  static const String _kPortOverride = 'llama_cpp_port_override';

  static String defaultHost() {
    if (kIsWeb) return '127.0.0.1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      default:
        return '127.0.0.1';
    }
  }

  static Future<String> readHostOverride() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(_kHostOverride) ?? '').trim();
  }

  static Future<int?> readPortOverride() async {
    final sp = await SharedPreferences.getInstance();
    if (!sp.containsKey(_kPortOverride)) return null;
    return sp.getInt(_kPortOverride);
  }

  static Future<void> saveHostOverride(String host) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kHostOverride, host.trim());
  }

  static Future<void> savePortOverride(int? port) async {
    final sp = await SharedPreferences.getInstance();
    if (port == null) {
      await sp.remove(_kPortOverride);
      return;
    }
    await sp.setInt(_kPortOverride, port);
  }

  /// 是否为 ngrok / cpolar 等穿透域名（对外默认 443，不要再拼 6633）。
  static bool isTunnelHost(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    return value.contains('ngrok') ||
        value.contains('cpolar') ||
        value.contains('loca.lt') ||
        value.contains('trycloudflare.com') ||
        value.contains('serveo.net');
  }

  /// 将 Host + Port 解析为根 URL（不含 `/v1`）。
  static String composeRootUrl({
    required String hostInput,
    int? port,
  }) {
    var input = hostInput.trim();
    if (input.isEmpty) {
      input = defaultHost();
    }

    // 完整 URL：https://xxx.ngrok-free.dev 或 http://192.168.1.2:6633
    if (input.startsWith('http://') || input.startsWith('https://')) {
      final uri = Uri.tryParse(input);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.hasPort
            ? '${uri.scheme}://${uri.host}:${uri.port}'
            : '${uri.scheme}://${uri.host}';
      }
    }

    final hostOnly = input.replaceFirst(RegExp(r'^https?://'), '');
    if (hostOnly.contains(':')) {
      final scheme = isTunnelHost(hostOnly) ? 'https' : 'http';
      return '$scheme://$hostOnly';
    }

    if (isTunnelHost(hostOnly)) {
      return 'https://$hostOnly';
    }

    final effectivePort = port ?? defaultPort;
    return 'http://$hostOnly:$effectivePort';
  }

  static Future<String> resolveRootUrl() async {
    final overrideHost = await readHostOverride();
    final port = await readPortOverride();
    final host = overrideHost.isNotEmpty ? overrideHost : defaultHost();
    return composeRootUrl(hostInput: host, port: port);
  }

  static Future<String> resolveV1BaseUrl() async {
    final root = await resolveRootUrl();
    return root.endsWith('/v1') ? root : '$root/v1';
  }

  static bool isLocalHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1' || h == '10.0.2.2') {
      return true;
    }
    if (h.startsWith('192.168.') ||
        h.startsWith('10.') ||
        h.startsWith('172.')) {
      return true;
    }
    return false;
  }

  static bool isLocalBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.host.isEmpty) return false;
    if (isTunnelHost(uri.host)) return false;
    return isLocalHost(uri.host);
  }
}
