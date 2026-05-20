import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';
import 'ai_chat_gateway_service.dart';
import 'ai_provider_service.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';
import 'llm_response_parser.dart';

/// 记忆提取专用 LLM 调用：优先当前聊天中转站，失败再回退后端 Ollama。
class MemoryExtractLlmClient {
  MemoryExtractLlmClient._();

  static Future<String> complete({
    required AiProviderProfile? relayProfile,
    required String relayModel,
    required String ollamaModel,
    required String userPrompt,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    String? relayError;
    if (relayProfile != null &&
        relayProfile.isOpenAiCompatible &&
        relayModel.trim().isNotEmpty) {
      try {
        final content = await _viaRelay(
          profile: relayProfile,
          model: relayModel.trim(),
          userPrompt: userPrompt,
          timeout: timeout,
        );
        if (content.trim().isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '🧠 [Memory] extract via relay model=$relayModel profile=${relayProfile.name}',
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

    try {
      final content = await _viaBackendOllama(
        model: ollamaModel,
        userPrompt: userPrompt,
        timeout: timeout,
      );
      if (content.trim().isNotEmpty) return content;
    } catch (e) {
      final ollamaErr =
          e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (relayError != null && relayError.isNotEmpty) {
        throw Exception('中转提取失败（$relayError）；Ollama 回退也失败（$ollamaErr）');
      }
      rethrow;
    }

    if (relayError != null && relayError.isNotEmpty) {
      throw Exception('记忆提取失败：$relayError（且 Ollama 回退无内容）');
    }
    return '';
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
          'content':
              '你是记忆提取助手。只输出 JSON 数组，不要 Markdown，不要解释。',
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

  static Future<String> _viaBackendOllama({
    required String model,
    required String userPrompt,
    required Duration timeout,
  }) async {
    final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();
    final uri = await LlmEndpointConfig.chatUri();
    ApiService.logDirectHttp('POST', uri);
    final token = ApiService.token;
    final headers = ApiService.mergeTunnelHeaders(uri, headers: {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.1,
            if (terminalMode) 'stream': false,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Ollama 提取失败: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is Map) {
      if (data['success'] == false) {
        final msg = (data['message'] as String?)?.trim();
        throw Exception(
          msg != null && msg.isNotEmpty ? msg : 'Ollama 记忆提取失败',
        );
      }
      final content = LlmResponseParser.extractChatContent(
        data,
        terminalMode: terminalMode,
      );
      if (content.trim().isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🧠 [Memory] extract via backend ollama model=$model');
        }
        return content;
      }
    }
    throw Exception('Ollama 记忆提取返回空内容（请确认本机 Ollama 已启动且模型可用）');
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
