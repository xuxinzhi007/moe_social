import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// LLM 端点配置（用于“终端同款/本地 Ollama 直连”）
///
/// - 关闭时：走后端包装接口 `${ApiService.baseUrl}/api/llm/*`
/// - 开启时：直连本地/局域网 Ollama `http://<PC-IP>:11434/api/*`
class LlmEndpointConfig {
  static const String _kDirectEnabled = 'llm_direct_ollama_enabled';
  static const String _kDirectBaseUrl = 'llm_direct_ollama_base_url';
  static const String _kUseBackendProxy = 'llm_direct_use_backend_proxy';
  static const String _kIgnoreAgentSystemPrompt =
      'llm_direct_ignore_agent_system_prompt';

  /// 当用户没手动配置时，尝试从 `ApiService.baseUrl` 推导：
  /// - 若 baseUrl 是局域网 IP/域名（非 localhost / 非 cpolar），则默认使用同 host 的 11434
  /// - 否则回退到一个常见示例地址
  static const String _fallbackDirectBaseUrl = 'http://192.168.1.16:11434';

  static String _inferDirectBaseUrlFromApi() {
    try {
      final api = Uri.parse(ApiService.baseUrl);
      final host = api.host;
      if (host.isEmpty) return _fallbackDirectBaseUrl;
      final lowerHost = host.toLowerCase();
      // 这些场景无法从后端地址推导出“电脑 Ollama 地址”
      if (lowerHost == 'localhost' ||
          lowerHost == '127.0.0.1' ||
          lowerHost == '10.0.2.2' ||
          lowerHost.endsWith('.cpolar.top')) {
        return _fallbackDirectBaseUrl;
      }
      final scheme = api.scheme.isNotEmpty ? api.scheme : 'http';
      return '$scheme://$host:11434';
    } catch (_) {
      return _fallbackDirectBaseUrl;
    }
  }

  static Future<bool> isDirectEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kDirectEnabled) ?? false;
  }

  static Future<void> setDirectEnabled(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDirectEnabled, v);
  }

  static Future<String> getDirectBaseUrl() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kDirectBaseUrl)?.trim();
    return (v == null || v.isEmpty) ? _inferDirectBaseUrlFromApi() : v;
  }

  static Future<void> setDirectBaseUrl(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDirectBaseUrl, v.trim());
  }

  /// 终端同款的“连接方式”：
  /// - true：通过后端转发（适合 cpolar/外网环境；手机只需访问 ApiService.baseUrl）
  /// - false：手机直连电脑 Ollama（需要同内网/WiFi 或单独把 11434 做穿透）
  static Future<bool> useBackendProxy() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getBool(_kUseBackendProxy);
    if (v != null) return v;

    // 未显式配置时：如果当前 ApiService.baseUrl 看起来是外网/隧道/本机地址，
    // 默认启用后端转发更符合“内网穿透”的使用方式。
    try {
      final api = Uri.parse(ApiService.baseUrl);
      final host = api.host.toLowerCase();
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '10.0.2.2' ||
          host.endsWith('.cpolar.top')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setUseBackendProxy(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kUseBackendProxy, v);
  }

  /// 直连模式下：是否忽略智能体 system prompt（建议开启以贴近终端输出）
  static Future<bool> ignoreAgentSystemPrompt() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kIgnoreAgentSystemPrompt) ?? true;
  }

  static Future<void> setIgnoreAgentSystemPrompt(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kIgnoreAgentSystemPrompt, v);
  }

  static Future<Uri> modelsUri() async {
    if (await isDirectEnabled()) {
      if (await useBackendProxy()) {
        return Uri.parse('${ApiService.baseUrl}/api/llm/models/raw');
      }
      final base = (await getDirectBaseUrl()).replaceAll(RegExp(r'/+$'), '');
      return Uri.parse('$base/api/tags');
    }
    return Uri.parse('${ApiService.baseUrl}/api/llm/models');
  }

  static Future<Uri> chatUri() async {
    if (await isDirectEnabled()) {
      if (await useBackendProxy()) {
        return Uri.parse('${ApiService.baseUrl}/api/llm/chat/raw');
      }
      final base = (await getDirectBaseUrl()).replaceAll(RegExp(r'/+$'), '');
      return Uri.parse('$base/api/chat');
    }
    return Uri.parse('${ApiService.baseUrl}/api/llm/chat');
  }
}

