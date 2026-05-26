import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';
import 'ai_chat_gateway_service.dart';
import 'ai_provider_service.dart';
import 'api_service.dart';
import 'llama_cpp_endpoint_config.dart';
/// 记忆提取专用 LLM 调用：优先当前中转 Provider → 本机 llama.cpp。
class MemoryExtractLlmClient {
  MemoryExtractLlmClient._();

  static Future<String> complete({
    AiProviderProfile? providerProfile,
    required String relayModel,
    required String extractModel,
    required String userPrompt,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    String? relayError;
    if (providerProfile != null &&
        providerProfile.isOpenAiCompatible &&
        relayModel.trim().isNotEmpty) {
      try {
        final content = await _viaRelay(
          profile: providerProfile,
          model: relayModel.trim(),
          userPrompt: userPrompt,
          timeout: timeout,
        );
        if (content.trim().isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '🧠 [Memory] extract via relay model=$relayModel profile=${providerProfile.name}',
            );
          }
          return content;
        }
        relayError = '中转站返回空内容';
      } catch (e) {
        relayError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        if (kDebugMode) {
          debugPrint('🧠 [Memory] relay extract failed: $relayError');
        }
      }
    }

    // 本机 llama-server（OpenAI 兼容）— 替代已停用的 Ollama 11434
    var llamaError = '';
    try {
      final model = _resolveLlamaExtractModel(
        providerProfile: providerProfile,
        extractModel: extractModel,
        relayModel: relayModel,
      );
      final content = await _viaLlamaCpp(
        model: model,
        userPrompt: userPrompt,
        timeout: timeout,
      );
      if (content.trim().isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🧠 [Memory] extract via llama.cpp model=$model');
        }
        return content;
      }
      llamaError = 'llama.cpp 返回空内容';
    } catch (e) {
      llamaError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (kDebugMode) {
        debugPrint('🧠 [Memory] llama.cpp extract failed: $llamaError');
      }
    }

    if (relayError != null && relayError.isNotEmpty) {
      throw Exception(
        '中转提取失败（$relayError）；本机 llama.cpp 也失败（$llamaError）。'
        '请确认 llama-server 已启动（默认 6633）且模型 ID 与聊天一致。',
      );
    }
    throw Exception(
      llamaError.isNotEmpty
          ? '本机 llama.cpp 记忆提取失败：$llamaError'
          : '本机 llama.cpp 记忆提取失败，请确认 llama-server 已启动（默认端口 6633）',
    );
  }

  static String _resolveLlamaExtractModel({
    AiProviderProfile? providerProfile,
    required String extractModel,
    required String relayModel,
  }) {
    final fromRelay = relayModel.trim();
    if (fromRelay.isNotEmpty) return fromRelay;
    final fromProfile = providerProfile?.defaultModel.trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    final manual = providerProfile?.effectiveModelIds ?? const [];
    if (manual.isNotEmpty) return manual.first;
    final fb = extractModel.trim();
    if (fb.isNotEmpty) return fb;
    return 'qwen2';
  }

  static Future<String> _viaLlamaCpp({
    required String model,
    required String userPrompt,
    required Duration timeout,
  }) async {
    final baseUrl = await LlamaCppEndpointConfig.resolveV1BaseUrl();
    final uri = Uri.parse('${_normalizeBaseUrl(baseUrl)}/chat/completions');
    ApiService.logDirectHttp('POST', uri);

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    '你是记忆提取助手。只输出 JSON 数组，不要 Markdown，不要解释。',
              },
              {'role': 'user', 'content': userPrompt},
            ],
            'stream': false,
            'temperature': 0.1,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'llama.cpp 提取失败: HTTP ${response.statusCode}（请确认 llama-server 已启动且模型 ID 正确）',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content = _extractOpenAiContent(decoded);
    if (content.isEmpty) {
      throw Exception('llama.cpp 提取返回空内容');
    }
    return content;
  }

  static Future<String> _viaRelay({
    required AiProviderProfile profile,
    required String model,
    required String userPrompt,
    required Duration timeout,
  }) async {
    final apiKey = _normalizeApiKey(
      await AiProviderService().readApiKey(profile.id),
    );
    if (apiKey.isEmpty) {
      throw Exception('请先在「模型来源」为「${profile.name}」配置 API Key');
    }

    final uri = Uri.parse('${_normalizeBaseUrl(profile.baseUrl)}/chat/completions');
    ApiService.logDirectHttp('POST', uri);
    final headers = ApiService.mergeTunnelHeaders(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
    );

    final messages = <Map<String, dynamic>>[
      if (profile.supportsSystemMessages)
        {
          'role': 'system',
          'content': '你是记忆提取助手。只输出 JSON 数组，不要 Markdown，不要解释。',
        },
      {'role': 'user', 'content': userPrompt},
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': false,
    };
    if (AiChatGatewayService.supportsSamplingParams(model)) {
      body['temperature'] = 0.1;
    }

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('中转站提取失败: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content = _extractOpenAiContent(decoded);
    if (content.isEmpty) {
      throw Exception('中转站提取返回空内容');
    }
    return content;
  }

  static String _extractOpenAiContent(dynamic decoded) {
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) return content.trim();
    return '';
  }

  static String _normalizeApiKey(String raw) {
    var key = raw.trim();
    if (key.toLowerCase().startsWith('bearer ')) {
      key = key.substring(7).trim();
    }
    return key;
  }

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isNotEmpty && !value.endsWith('/v1')) {
      final lower = value.toLowerCase();
      if (!lower.endsWith('/v1/chat/completions') &&
          !lower.contains('/v1/') &&
          !lower.endsWith('/v1')) {
        value = '$value/v1';
      }
    }
    return value;
  }
}
