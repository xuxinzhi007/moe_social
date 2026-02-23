import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// LLM 端点配置（终端同款：始终通过后端转发到本机 Ollama）
///
/// - 关闭：走后端包装接口（带记忆/总结/系统提示词增强）`/api/llm/*`
/// - 开启：走后端 raw 转发接口（原样转发到 Ollama）`/api/llm/*/raw`
class LlmEndpointConfig {
  static const String _kTerminalModeEnabled = 'llm_terminal_mode_enabled';

  /// 默认开启：与你终端输出保持一致
  static Future<bool> isTerminalModeEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kTerminalModeEnabled) ?? true;
  }

  static Future<void> setTerminalModeEnabled(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kTerminalModeEnabled, v);
  }

  static Future<Uri> modelsUri() async {
    if (await isTerminalModeEnabled()) {
      return Uri.parse('${ApiService.baseUrl}/api/llm/models/raw');
    }
    return Uri.parse('${ApiService.baseUrl}/api/llm/models');
  }

  static Future<Uri> chatUri() async {
    if (await isTerminalModeEnabled()) {
      return Uri.parse('${ApiService.baseUrl}/api/llm/chat/raw');
    }
    return Uri.parse('${ApiService.baseUrl}/api/llm/chat');
  }

  /// 代理 Ollama POST /api/show，用于读取模型的 Modelfile / 系统提示词
  static Uri showUri() =>
      Uri.parse('${ApiService.baseUrl}/api/llm/show/raw');
}

