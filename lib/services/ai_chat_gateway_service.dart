import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_agent.dart';
import '../models/ai_provider_profile.dart';
import 'ai_models_cache_service.dart';
import 'ai_provider_service.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';
import 'llm_response_parser.dart';

class AiChatGatewayService {
  AiChatGatewayService._();

  static final AiChatGatewayService _instance = AiChatGatewayService._();
  factory AiChatGatewayService() => _instance;

  /// 将 Provider / 网络异常转为用户可读文案（聊天页展示）。
  static String userFacingError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.contains('请先在「模型来源」')) return raw;
    if (raw.contains('401') ||
        raw.contains('403') ||
        raw.contains('未提供令牌') ||
        raw.toLowerCase().contains('unauthorized') ||
        raw.toLowerCase().contains('invalid api key')) {
      return 'API 认证失败：请在「模型来源」检查该 Provider 的 API Key 是否已填写且有效';
    }
    final messageMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (messageMatch != null) {
      final msg = messageMatch.group(1)!.trim();
      if (msg.isNotEmpty) return '请求失败：$msg';
    }
    if (raw.startsWith('Provider 请求失败')) {
      return '模型服务请求失败，请检查 API 地址、模型 ID 与 Key';
    }
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Connection refused')) {
      return '无法连接模型服务，请检查网络与 API 地址';
    }
    if (raw.length > 120) {
      return '请求失败，请稍后重试';
    }
    return raw;
  }

  Future<List<String>> fetchModelsForAgent(AiAgent agent) async {
    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    return fetchModelsForProfile(profile);
  }

  Future<List<String>> fetchModelsForProfile(AiProviderProfile profile) async {
    try {
      if (profile.isBackendOllama) {
        final uri = await LlmEndpointConfig.modelsUri();
        ApiService.logDirectHttp('GET', uri);
        final response = await http
            .get(uri, headers: ApiService.mergeTunnelHeaders(uri))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw Exception('加载模型失败: ${response.statusCode}');
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return _extractModelNames(decoded);
      }

      final apiKey = await AiProviderService().readApiKey(profile.id);
      if (apiKey.trim().isEmpty) {
        throw Exception(
          '请先在「模型来源」中为「${profile.name}」填写 API Key',
        );
      }
      final uri = Uri.parse('${_normalizeBaseUrl(profile.baseUrl)}/models');
      final response = await http
          .get(uri, headers: await _buildProviderHeaders(profile, uri: uri))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('加载模型失败: ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final names = _extractModelNames(decoded);
      if (names.isNotEmpty) {
        await AiModelsCacheService().write(profile.id, names);
        return names;
      }
    } catch (_) {}

    final cached = await AiModelsCacheService().read(profile.id);
    if (cached.isNotEmpty) return cached;

    final fallback = <String>[
      if (profile.defaultModel.trim().isNotEmpty) profile.defaultModel.trim(),
      ...profile.manualModels.map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];
    return fallback.toSet().toList();
  }

  Future<String> sendChat({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
  }) async {
    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    // useServerMemory：内置 Ollama 走 /api/llm/chat（注入+提取）；第三方在客户端注入/提取。
    // 记忆编排见 AiMemoryOrchestrator。
    if (profile.isBackendOllama) {
      return _sendToBackendOllama(
        agent: agent,
        messages: messages,
        sessionId: sessionId,
        sourceMsgId: sourceMsgId,
      );
    }
    return _sendToOpenAiCompatible(
      profile: profile,
      model: _effectiveModel(agent, profile),
      messages: messages,
    );
  }

  Future<String> _sendToBackendOllama({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
  }) async {
    final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();
    final uri = await LlmEndpointConfig.chatUri();
    ApiService.logDirectHttp('POST', uri);
    final token = ApiService.token;
    final response = await http
        .post(
          uri,
          headers: ApiService.mergeTunnelHeaders(uri, headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          }),
          body: jsonEncode({
            'model': _effectiveModel(agent, AiProviderProfile.builtinBackend()),
            'messages': messages,
            'session_id': sessionId,
            'source_msg_id': sourceMsgId,
            if (terminalMode) 'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200) {
      throw Exception('请求失败 (${response.statusCode})');
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    final data = LlmResponseParser.decodeJsonOrNdjson(decodedBody);
    final content = LlmResponseParser.extractChatContent(
      data,
      terminalMode: terminalMode,
    );
    if (content.trim().isNotEmpty) return content.trim();

    if (data is Map && data['error'] is String) {
      throw Exception(data['error'] as String);
    }
    throw Exception('响应格式异常');
  }

  Future<String> _sendToOpenAiCompatible({
    required AiProviderProfile profile,
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final apiKey = await AiProviderService().readApiKey(profile.id);
    if (apiKey.trim().isEmpty) {
      throw Exception(
        '请先在「模型来源」中为「${profile.name}」填写 API Key，再开始聊天',
      );
    }
    final uri =
        Uri.parse('${_normalizeBaseUrl(profile.baseUrl)}/chat/completions');
    final headers = await _buildProviderHeaders(profile, uri: uri);
    final payloadMessages = profile.supportsSystemMessages
        ? messages
        : _foldSystemMessagesIntoConversation(messages);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'model': model,
            'messages': payloadMessages,
            'stream': profile.supportsStreaming,
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200 &&
        _providerRejectsSystemMessages(response.bodyBytes)) {
      final fallbackMessages = _foldSystemMessagesIntoConversation(messages);
      final retry = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': model,
              'messages': fallbackMessages,
              'stream': profile.supportsStreaming,
            }),
          )
          .timeout(const Duration(seconds: 180));
      if (retry.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(retry.bodyBytes));
        final content = _extractOpenAiCompatibleContent(decoded);
        if (content.isNotEmpty) return content;
        throw Exception('Provider 响应格式异常');
      }
      final retryBody = utf8.decode(retry.bodyBytes);
      throw Exception('Provider 请求失败 (${retry.statusCode}): $retryBody');
    }

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception('Provider 请求失败 (${response.statusCode}): $body');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content = _extractOpenAiCompatibleContent(decoded);
    if (content.isEmpty) {
      throw Exception('Provider 响应格式异常');
    }
    return content;
  }

  Future<Map<String, String>> _buildProviderHeaders(
    AiProviderProfile profile, {
    Uri? uri,
  }) async {
    final apiKey = _normalizeApiKey(
      await AiProviderService().readApiKey(profile.id),
    );
    final baseHeaders = {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };
    if (uri != null) {
      return ApiService.mergeTunnelHeaders(uri, headers: baseHeaders);
    }
    return baseHeaders;
  }

  List<String> _extractModelNames(dynamic decoded) {
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
        .toList();
  }

  String _extractOpenAiCompatibleContent(dynamic decoded) {
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    final content = message['content'];
    if (content is String) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['type'] == 'text' && part['text'] is String) {
          buffer.write(part['text']);
        }
      }
      return buffer.toString().trim();
    }
    return '';
  }

  String _normalizeApiKey(String raw) {
    var key = raw.trim();
    if (key.toLowerCase().startsWith('bearer ')) {
      key = key.substring(7).trim();
    }
    return key;
  }

  String _normalizeBaseUrl(String raw) {
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

  String _effectiveModel(AiAgent agent, AiProviderProfile profile) {
    final explicit = agent.modelName.trim();
    if (explicit.isNotEmpty) return explicit;
    return profile.defaultModel.trim();
  }

  bool _providerRejectsSystemMessages(List<int> bodyBytes) {
    final body = utf8.decode(bodyBytes).toLowerCase();
    return body.contains('system messages are not allowed') ||
        body.contains('"detail":"system messages are not allowed"');
  }

  List<Map<String, String>> _foldSystemMessagesIntoConversation(
    List<Map<String, String>> messages,
  ) {
    final systemContents = <String>[];
    final normalized = <Map<String, String>>[];

    for (final message in messages) {
      final role = (message['role'] ?? '').trim();
      final content = (message['content'] ?? '').trim();
      if (content.isEmpty) continue;
      if (role == 'system') {
        systemContents.add(content);
        continue;
      }
      normalized.add({'role': role, 'content': content});
    }

    if (systemContents.isEmpty) return normalized;

    final injectedPrompt = StringBuffer()
      ..writeln('请严格遵循以下角色设定与回复规则：')
      ..writeln(systemContents.join('\n\n'))
      ..writeln()
      ..write('在后续对话中不要重复解释这些规则，直接按设定回答。');

    if (normalized.isEmpty) {
      return [
        {'role': 'user', 'content': injectedPrompt.toString().trim()},
      ];
    }

    final first = normalized.first;
    if (first['role'] == 'user') {
      normalized[0] = {
        'role': 'user',
        'content':
            '${injectedPrompt.toString().trim()}\n\n[用户消息]\n${first['content'] ?? ''}',
      };
      return normalized;
    }

    return [
      {'role': 'user', 'content': injectedPrompt.toString().trim()},
      ...normalized,
    ];
  }
}
