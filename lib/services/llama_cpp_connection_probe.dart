import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'api_response.dart';
import 'llama_cpp_endpoint_config.dart';

class LlamaCppProbeResult {
  const LlamaCppProbeResult({
    required this.success,
    required this.message,
    this.models = const [],
    this.requestUrl = '',
  });

  final bool success;
  final String message;
  final List<String> models;
  final String requestUrl;

  factory LlamaCppProbeResult.ok({
    required String message,
    required List<String> models,
    required String requestUrl,
  }) =>
      LlamaCppProbeResult(
        success: true,
        message: message,
        models: models,
        requestUrl: requestUrl,
      );

  factory LlamaCppProbeResult.fail({
    required String message,
    required String requestUrl,
  }) =>
      LlamaCppProbeResult(
        success: false,
        message: message,
        requestUrl: requestUrl,
      );
}

/// 直连 llama-server 探测（设置页测试用，会返回明确错误，不做 fallback）。
abstract final class LlamaCppConnectionProbe {
  static Uri _modelsUri(String rootUrl) {
    var base = rootUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (!base.endsWith('/v1')) {
      base = '$base/v1';
    }
    return Uri.parse('$base/models');
  }

  static List<String> _extractModelNames(dynamic decoded) {
    if (decoded is! Map) return const [];
    final raw = ApiResponse.listOf(
      Map<String, dynamic>.from(decoded),
      keys: const ['models'],
    );
    if (raw.whereType<String>().isNotEmpty) {
      return raw.whereType<String>().toList();
    }
    return raw
        .whereType<Map>()
        .map((m) => (m['name'] ?? m['id'])?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  static bool _looksLikeHtml(String body) {
    final trimmed = body.trimLeft();
    return trimmed.startsWith('<!DOCTYPE') ||
        trimmed.startsWith('<html') ||
        trimmed.contains('<body');
  }

  static String _corsHint() {
    if (!kIsWeb) return '';
    return '\n\n当前是浏览器版 App：跨域 (CORS) 会拦截 ngrok → llama-server 的响应。'
        '请改用 Windows/Android 桌面安装包测试，或在 llama-server 启动参数里开启 CORS（见设置页说明）。';
  }

  static Future<LlamaCppProbeResult> testModels() async {
    final root = await LlamaCppEndpointConfig.resolveRootUrl();
    final uri = _modelsUri(root);
    final headers = ApiService.mergeTunnelHeaders(
      uri,
      headers: const {
        'Accept': 'application/json',
      },
    );

    ApiService.logDirectHttp('GET', uri);

    try {
      final response =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode != 200) {
        final preview =
            body.length > 200 ? '${body.substring(0, 200)}…' : body;
        return LlamaCppProbeResult.fail(
          requestUrl: uri.toString(),
          message: 'HTTP ${response.statusCode}\n$preview',
        );
      }

      if (_looksLikeHtml(body)) {
        return LlamaCppProbeResult.fail(
          requestUrl: uri.toString(),
          message: '返回了 HTML 页面而非 JSON。'
              '请确认 ngrok 域名完整正确，且请求已带 ngrok 跳过页头。'
              '${_corsHint()}',
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        return LlamaCppProbeResult.fail(
          requestUrl: uri.toString(),
          message: '响应不是合法 JSON：$e${_corsHint()}',
        );
      }

      final models = _extractModelNames(decoded);
      if (models.isEmpty) {
        return LlamaCppProbeResult.ok(
          requestUrl: uri.toString(),
          message: '连接成功，但 /v1/models 未返回模型名。'
              '聊天时模型 ID 填 qwen2（与 gguf 文件名一致）即可。',
          models: const ['qwen2'],
        );
      }

      return LlamaCppProbeResult.ok(
        requestUrl: uri.toString(),
        message: '连接成功',
        models: models,
      );
    } catch (e) {
      final err = e.toString();
      if (kIsWeb &&
          (err.contains('Failed to fetch') ||
              err.contains('XMLHttpRequest') ||
              err.contains('NetworkError'))) {
        return LlamaCppProbeResult.fail(
          requestUrl: uri.toString(),
          message: '浏览器跨域 (CORS) 拦截了响应。'
              'ngrok 日志里可能已有 200，但 Chrome 不允许网页读取。'
              '\n\n建议：'
              '\n1. 用 Windows 桌面版 App（非 Chrome）测试 llama.cpp'
              '\n2. 或 llama-server 加 CORS 参数（见上方启动说明）'
              '\n3. 本机直连用 127.0.0.1:6633，不必走 ngrok',
        );
      }
      return LlamaCppProbeResult.fail(
        requestUrl: uri.toString(),
        message: '连接失败：$err',
      );
    }
  }

  static Future<LlamaCppProbeResult> testHealth() async {
    final root = await LlamaCppEndpointConfig.resolveRootUrl();
    final uri = Uri.parse('$root/health');
    final headers = ApiService.mergeTunnelHeaders(uri);
    try {
      final response =
          await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        return LlamaCppProbeResult.ok(
          requestUrl: uri.toString(),
          message: 'health 正常\n$body',
          models: const [],
        );
      }
      return LlamaCppProbeResult.fail(
        requestUrl: uri.toString(),
        message: 'health HTTP ${response.statusCode}\n$body',
      );
    } catch (e) {
      final err = e.toString();
      if (kIsWeb && err.contains('Failed to fetch')) {
        return LlamaCppProbeResult.fail(
          requestUrl: uri.toString(),
          message: 'health 被浏览器 CORS 拦截：$err',
        );
      }
      return LlamaCppProbeResult.fail(
        requestUrl: uri.toString(),
        message: 'health 失败：$err',
      );
    }
  }
}
