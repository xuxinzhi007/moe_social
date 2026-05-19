import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';
import 'api_service.dart';
import 'ai_provider_service.dart';

/// 探测中转站 Base URL：规范化地址、识别 OpenAI 兼容类型、拉取模型列表。
class AiProviderDetectResult {
  const AiProviderDetectResult({
    required this.success,
    required this.message,
    required this.normalizedBaseUrl,
    required this.suggestedType,
    this.suggestedName,
    this.models = const [],
    this.modelsFromApi = false,
  });

  final bool success;
  final String message;
  final String normalizedBaseUrl;
  final AiProviderType suggestedType;
  final String? suggestedName;
  final List<String> models;
  final bool modelsFromApi;
}

abstract final class AiProviderDetector {
  static Future<AiProviderDetectResult> detect({
    required String baseUrl,
    required String apiKey,
    String? previewProfileId,
  }) async {
    final normalized = normalizeBaseUrl(baseUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return AiProviderDetectResult(
        success: false,
        message: 'Base URL 格式无效，请包含 https://',
        normalizedBaseUrl: normalized,
        suggestedType: AiProviderType.openAiCompatible,
      );
    }

    if (_looksAnthropicNative(uri)) {
      return AiProviderDetectResult(
        success: false,
        message:
            '检测到 Anthropic 原生地址。当前 App 仅支持 OpenAI 兼容网关（需 /v1/models 或 /v1/chat/completions），请改用兼容层或 OneAPI/NewAPI 地址。',
        normalizedBaseUrl: normalized,
        suggestedType: AiProviderType.openAiCompatible,
        suggestedName: _guessNameFromHost(uri),
      );
    }

    final suggestedName = _guessNameFromHost(uri);
    final headers = await _buildHeaders(
      apiKey: apiKey,
      profileId: previewProfileId,
      uri: Uri.parse('$normalized/models'),
    );

    try {
      final modelsUri = Uri.parse('$normalized/models');
      ApiService.logDirectHttp('GET', modelsUri);
      final response = await http
          .get(modelsUri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return AiProviderDetectResult(
          success: false,
          message: '认证失败（HTTP ${response.statusCode}），请检查 API Key',
          normalizedBaseUrl: normalized,
          suggestedType: AiProviderType.openAiCompatible,
          suggestedName: suggestedName,
        );
      }

      if (response.statusCode == 200) {
        final models = _extractModelNames(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
        if (models.isNotEmpty) {
          return AiProviderDetectResult(
            success: true,
            message: '已识别为 OpenAI 兼容 API，获取到 ${models.length} 个模型',
            normalizedBaseUrl: normalized,
            suggestedType: AiProviderType.openAiCompatible,
            suggestedName: suggestedName,
            models: models,
            modelsFromApi: true,
          );
        }
        return AiProviderDetectResult(
          success: true,
          message:
              '已识别为 OpenAI 兼容 API，但 /models 未返回列表（很常见）。请在下方填写「默认模型」或「手动模型列表」后保存。',
          normalizedBaseUrl: normalized,
          suggestedType: AiProviderType.openAiCompatible,
          suggestedName: suggestedName,
          models: const [],
          modelsFromApi: false,
        );
      }

      return AiProviderDetectResult(
        success: false,
        message:
            '无法访问 /models（HTTP ${response.statusCode}）。若聊天地址正确，可仍选手动填写模型 ID。',
        normalizedBaseUrl: normalized,
        suggestedType: AiProviderType.openAiCompatible,
        suggestedName: suggestedName,
      );
    } catch (e) {
      return AiProviderDetectResult(
        success: false,
        message: '连接失败：$e',
        normalizedBaseUrl: normalized,
        suggestedType: AiProviderType.openAiCompatible,
        suggestedName: suggestedName,
      );
    }
  }

  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    if (lower.endsWith('/v1/chat/completions')) {
      value = value.substring(0, value.length - '/chat/completions'.length);
    }
    if (!lower.endsWith('/v1') && !lower.contains('/v1/')) {
      value = '$value/v1';
    }
    return value;
  }

  static bool _looksAnthropicNative(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host.contains('anthropic.com')) return true;
    if (path.contains('/v1/messages') && !path.contains('openai')) return true;
    return false;
  }

  static String? _guessNameFromHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('openrouter')) return 'OpenRouter';
    if (host.contains('deepseek')) return 'DeepSeek';
    if (host.contains('openai')) return 'OpenAI';
    if (host.contains('siliconflow')) return 'SiliconFlow';
    if (host.contains('dashscope') || host.contains('aliyun')) return '通义千问';
    if (host.contains('moonshot')) return 'Moonshot';
    if (host.contains('groq')) return 'Groq';
    if (host.contains('together')) return 'Together';
    if (host.contains('fireworks')) return 'Fireworks';
    if (host.contains('volces') || host.contains('volcengine')) {
      return '火山方舟';
    }
    final parts = host.split('.');
    if (parts.length >= 2) {
      final label = parts[parts.length - 2];
      if (label.length > 2 && label != 'api' && label != 'www') {
        return label[0].toUpperCase() + label.substring(1);
      }
    }
    return null;
  }

  static List<String> _extractModelNames(dynamic decoded) {
    if (decoded is! Map) return const [];
    final raw = decoded['models'] ?? decoded['data'];
    if (raw is! List) return const [];
    if (raw.whereType<String>().isNotEmpty) {
      return raw.whereType<String>().toList();
    }
    return raw
        .whereType<Map>()
        .map((m) => (m['name'] ?? m['id'])?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
  }

  static Future<Map<String, String>> _buildHeaders({
    required String apiKey,
    required Uri uri,
    String? profileId,
  }) async {
    var key = apiKey.trim();
    if (key.isEmpty && profileId != null) {
      key = await AiProviderService().readApiKey(profileId);
    }
    final base = {
      'Content-Type': 'application/json',
      if (key.isNotEmpty) 'Authorization': 'Bearer $key',
    };
    return ApiService.mergeTunnelHeaders(uri, headers: base);
  }
}
