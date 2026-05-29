import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_agent.dart';
import '../models/ai_provider_profile.dart';
import 'ai_memory_tools.dart';
import 'ai_models_cache_service.dart';
import 'ai_provider_service.dart';
import 'ai_tool_runtime.dart';
import 'api_service.dart';
import 'api_response.dart';
import 'llama_cpp_endpoint_config.dart';
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
    final parsed = _parseProviderErrorPayload(raw);
    if (parsed != null) return parsed;
    if (raw.contains('Provider 空回复')) {
      return '模型返回了空回复：接口已成功，但未生成可见文字。'
          'Codex 做角色扮演时较常见，建议换 gpt-5.2 / gpt-5.4 或新建对话。';
    }
    if (raw.startsWith('Provider 请求失败')) {
      return '模型服务请求失败，请检查 API 地址、模型 ID 与 Key（详情见调试日志）';
    }
    if (raw.startsWith('Provider 响应格式异常')) {
      return '模型返回了空回复或无法解析的内容。Codex 类模型不适合角色扮演时会出现，建议换 gpt-5.2 或新建对话';
    }
    if (raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Connection refused') ||
        raw.contains('Failed to fetch') ||
        raw.contains('XMLHttpRequest')) {
      if (raw.contains('6633')) {
        return '无法连接本机 llama.cpp（端口 6633）。请确认 llama-server 已启动，并在「模型来源 → llama.cpp 设置」检查地址';
      }
      if (kIsWeb &&
          (raw.contains('Failed to fetch') || raw.contains('XMLHttpRequest'))) {
        return '浏览器跨域 (CORS) 拦截了 llama.cpp / ngrok 响应。'
            'ngrok 可能已收到 200，但 Chrome 网页版读不到。'
            '请改用 Windows 桌面 App，或给 llama-server 开启 CORS。';
      }
      return '无法连接模型服务，请检查网络与 API 地址';
    }
    if (raw.length > 120) {
      return '请求失败，请稍后重试（详情见调试日志）';
    }
    return raw;
  }

  static String? _parseProviderErrorPayload(String raw) {
    final jsonStart = raw.indexOf('{');
    if (jsonStart < 0) return null;
    try {
      final decoded = jsonDecode(raw.substring(jsonStart));
      if (decoded is! Map) return null;
      final nested = decoded['error'];
      if (nested is Map) {
        final msg =
            (nested['message'] ?? nested['msg'] ?? '').toString().trim();
        final code = (nested['code'] ?? nested['type'] ?? '').toString().trim();
        return _friendlyProviderMessage(
          msg.isNotEmpty ? msg : code,
          code,
        );
      }
      final top =
          (decoded['message'] ?? decoded['msg'] ?? '').toString().trim();
      if (top.isNotEmpty) {
        return _friendlyProviderMessage(top, '');
      }
    } catch (_) {}
    return null;
  }

  static String _friendlyProviderMessage(String message, String code) {
    final combined = '$message $code'.toLowerCase();
    if (combined.contains('openai_error')) {
      return '模型服务返回 openai_error：多为 API Key、余额不足或模型 ID 不可用。'
          '「模型来源」里测试连接成功只说明 Key 有效，请确认角色绑定的模型（如 gpt-5.2）在 Xbai 已开通。';
    }
    if (message.isNotEmpty) return '请求失败：$message';
    if (code.isNotEmpty) return '请求失败：$code';
    return '模型服务请求失败，请稍后重试';
  }

  static void _logProviderFailure({
    required Uri uri,
    required int statusCode,
    required String body,
    required String model,
    int? messageCount,
    int? systemChars,
  }) {
    if (!kDebugMode) return;
    final preview = body.length > 1200 ? '${body.substring(0, 1200)}…' : body;
    debugPrint(
      '❌ [Provider] chat/completions failed '
      'status=$statusCode model=$model '
      'messages=$messageCount systemChars=$systemChars '
      'url=$uri',
    );
    debugPrint('❌ [Provider] response: $preview');
  }

  Future<List<String>> fetchModelsForAgent(AiAgent agent) async {
    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    return fetchModelsForProfile(profile);
  }

  Future<List<String>> fetchModelsForProfile(AiProviderProfile profile) async {
    try {
      if (profile.isLlamaCppServer || profile.isOpenAiCompatible) {
        return _fetchOpenAiCompatibleModels(profile);
      }

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
    } catch (_) {}

    final cached = await AiModelsCacheService().read(profile.id);
    if (cached.isNotEmpty) return cached;

    final fallback = <String>[
      if (profile.defaultModel.trim().isNotEmpty) profile.defaultModel.trim(),
      ...profile.manualModels.map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];
    return fallback.toSet().toList();
  }

  Future<List<String>> _fetchOpenAiCompatibleModels(
    AiProviderProfile profile,
  ) async {
    if (profile.requiresApiKey) {
      final apiKey = await AiProviderService().readApiKey(profile.id);
      if (apiKey.trim().isEmpty) {
        throw Exception(
          '请先在「模型来源」中为「${profile.name}」填写 API Key',
        );
      }
    }
    final baseUrl = await _resolveProviderBaseUrl(profile);
    final uri = Uri.parse('${_normalizeBaseUrl(baseUrl)}/models');
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
    throw Exception('models_empty');
  }

  Future<String> sendChat({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
    double? temperature,
    double? topP,
  }) async {
    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    // 记忆注入由 AiMemoryOrchestrator 在 messages 中完成；Ollama 请求标记 client_memory_applied 避免服务端重复注入。
    if (profile.isBackendOllama) {
      return _sendToBackendOllama(
        agent: agent,
        messages: messages,
        sessionId: sessionId,
        sourceMsgId: sourceMsgId,
        temperature: temperature,
        topP: topP,
      );
    }

    // llama.cpp server 与 OpenAI 兼容中转均走 chat/completions。
    final model = _effectiveModel(agent, profile);
    if (profile.supportsToolCalls) {
      final userId = await AiMemoryTools.resolveUserId();
      if (userId != null) {
        try {
          return await _sendToOpenAiCompatibleWithTools(
            profile: profile,
            model: model,
            messages: messages,
            userId: userId,
            temperature: temperature,
            topP: topP,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('🔧 [Tool] fallback without tools: $e');
          }
        }
      }
    }
    return _sendToOpenAiCompatible(
      profile: profile,
      model: model,
      messages: messages,
      temperature: temperature,
      topP: topP,
    );
  }

  Future<String> _sendToBackendOllama({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
    double? temperature,
    double? topP,
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
            'client_memory_applied': true,
            if (terminalMode) 'stream': false,
            if (temperature != null && temperature > 0)
              'temperature': temperature,
            if (topP != null && topP > 0) 'top_p': topP,
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

  /// Codex / o 系列等推理模型通常不接受自定义 temperature，强行传入会 400。
  static bool supportsSamplingParams(String model) {
    final id = model.trim().toLowerCase();
    if (id.contains('codex')) return false;
    if (RegExp(r'\bo[0-9](?:-|$|/)').hasMatch(id)) return false;
    if (id.contains('reasoning')) return false;
    return true;
  }

  Map<String, dynamic> _openAiChatBody({
    required String model,
    required List<Map<String, dynamic>> messages,
    required bool stream,
    double? temperature,
    double? topP,
    List<Map<String, dynamic>>? tools,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': stream,
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
      body['tool_choice'] = 'auto';
    }
    if (supportsSamplingParams(model)) {
      if (temperature != null && temperature >= 0) {
        body['temperature'] = temperature;
      }
      if (topP != null && topP > 0) body['top_p'] = topP;
    }
    return body;
  }

  List<Map<String, dynamic>> _toDynamicMessages(
    List<Map<String, String>> messages,
  ) =>
      messages
          .map(
            (m) => {
              'role': m['role'] ?? '',
              'content': m['content'] ?? '',
            },
          )
          .toList();

  Future<String> _sendToOpenAiCompatibleWithTools({
    required AiProviderProfile profile,
    required String model,
    required List<Map<String, String>> messages,
    required String userId,
    double? temperature,
    double? topP,
  }) async {
    final apiKey = await AiProviderService().readApiKey(profile.id);
    if (profile.requiresApiKey && apiKey.trim().isEmpty) {
      throw Exception(
        '请先在「模型来源」中为「${profile.name}」填写 API Key，再开始聊天',
      );
    }
    final baseUrl = await _resolveProviderBaseUrl(profile);
    final uri =
        Uri.parse('${_normalizeBaseUrl(baseUrl)}/chat/completions');
    final headers = await _buildProviderHeaders(profile, uri: uri);
    final tools = AiToolRuntime.definitionsForMemory();
    var working = profile.supportsSystemMessages
        ? _toDynamicMessages(messages)
        : _toDynamicMessages(_foldSystemMessagesIntoConversation(messages));

    for (var round = 0; round < AiToolRuntime.maxRounds; round++) {
      if (kDebugMode) {
        debugPrint('🔧 [Tool] round=${round + 1} messages=${working.length}');
      }
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(
              _openAiChatBody(
                model: model,
                messages: working,
                stream: false,
                temperature: temperature,
                topP: topP,
                tools: tools,
              ),
            ),
          )
          .timeout(const Duration(seconds: 180));

      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode != 200) {
        throw Exception('Provider 请求失败 (${response.statusCode}): $body');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw Exception('Provider 响应格式异常');
      }

      final toolCalls = _extractToolCalls(decoded);
      if (toolCalls.isNotEmpty) {
        final assistantMsg = _extractAssistantMessageMap(decoded);
        if (assistantMsg != null) {
          working.add(assistantMsg);
        }
        for (final call in toolCalls) {
          final result = await AiToolRuntime.execute(
            name: call.name,
            argumentsJson: call.argumentsJson,
            userId: userId,
          );
          working.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': result,
          });
        }
        continue;
      }

      final content = _extractOpenAiCompatibleContent(decoded);
      if (content.isNotEmpty) return content;
      throw Exception('Provider 工具调用后仍无可见回复');
    }
    throw Exception('Provider 工具调用轮次已达上限');
  }

  List<_OpenAiToolCall> _extractToolCalls(Map<dynamic, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return const [];
    final first = choices.first;
    if (first is! Map) return const [];
    final message = first['message'];
    if (message is! Map) return const [];
    final raw = message['tool_calls'];
    if (raw is! List) return const [];
    final out = <_OpenAiToolCall>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString();
      final fn = item['function'];
      if (fn is! Map) continue;
      final name = (fn['name'] ?? '').toString();
      final args = (fn['arguments'] ?? '{}').toString();
      if (name.isEmpty) continue;
      out.add(_OpenAiToolCall(id: id, name: name, argumentsJson: args));
    }
    return out;
  }

  Map<String, dynamic>? _extractAssistantMessageMap(
      Map<dynamic, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;
    return Map<String, dynamic>.from(message);
  }

  Future<String> _sendToOpenAiCompatible({
    required AiProviderProfile profile,
    required String model,
    required List<Map<String, String>> messages,
    double? temperature,
    double? topP,
  }) async {
    final apiKey = await AiProviderService().readApiKey(profile.id);
    if (profile.requiresApiKey && apiKey.trim().isEmpty) {
      throw Exception(
        '请先在「模型来源」中为「${profile.name}」填写 API Key，再开始聊天',
      );
    }
    final baseUrl = await _resolveProviderBaseUrl(profile);
    final uri =
        Uri.parse('${_normalizeBaseUrl(baseUrl)}/chat/completions');
    ApiService.logDirectHttp('POST', uri);
    final headers = await _buildProviderHeaders(profile, uri: uri);
    final payloadMessages = profile.supportsSystemMessages
        ? messages
        : _foldSystemMessagesIntoConversation(messages);
    final dynamicMessages = _toDynamicMessages(payloadMessages);
    final systemChars = payloadMessages
        .where((m) => m['role'] == 'system')
        .fold<int>(0, (sum, m) => sum + (m['content'] ?? '').length);
    final sendTemp = supportsSamplingParams(model) ? temperature : null;
    final useStream = profile.supportsStreaming && !profile.isLlamaCppServer;
    if (kDebugMode) {
      debugPrint(
        '📤 [Provider] chat model=$model messages=${payloadMessages.length} '
        'stream=$useStream systemChars=$systemChars '
        'temperature=${sendTemp ?? 'default'}',
      );
    }
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(
            _openAiChatBody(
              model: model,
              messages: dynamicMessages,
              stream: useStream,
              temperature: temperature,
              topP: topP,
            ),
          ),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200 &&
        _providerRejectsSystemMessages(response.bodyBytes)) {
      final fallbackMessages = _foldSystemMessagesIntoConversation(messages);
      final retry = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(
              _openAiChatBody(
                model: model,
                messages: _toDynamicMessages(fallbackMessages),
                stream: useStream,
                temperature: temperature,
                topP: topP,
              ),
            ),
          )
          .timeout(const Duration(seconds: 180));
      if (retry.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(retry.bodyBytes));
        final content = _extractOpenAiCompatibleContent(decoded);
        if (content.isNotEmpty) return content;
        throw Exception('Provider 响应格式异常');
      }
      final retryBody = utf8.decode(retry.bodyBytes);
      _logProviderFailure(
        uri: uri,
        statusCode: retry.statusCode,
        body: retryBody,
        model: model,
        messageCount: fallbackMessages.length,
        systemChars: systemChars,
      );
      throw Exception('Provider 请求失败 (${retry.statusCode}): $retryBody');
    }

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      _logProviderFailure(
        uri: uri,
        statusCode: response.statusCode,
        body: body,
        model: model,
        messageCount: payloadMessages.length,
        systemChars: systemChars,
      );
      throw Exception('Provider 请求失败 (${response.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] != null) {
      _logProviderFailure(
        uri: uri,
        statusCode: response.statusCode,
        body: body,
        model: model,
        messageCount: payloadMessages.length,
        systemChars: systemChars,
      );
      throw Exception('Provider 请求失败 (200): $body');
    }
    final content = _extractOpenAiCompatibleContent(decoded);
    if (content.isEmpty) {
      _logProviderFailure(
        uri: uri,
        statusCode: response.statusCode,
        body: body,
        model: model,
        messageCount: payloadMessages.length,
        systemChars: systemChars,
      );
      throw Exception(
        'Provider 空回复: 模型 $model 返回 HTTP 200 但 content 为空（可能不适合当前对话场景）',
      );
    }
    return content;
  }

  Future<Map<String, String>> _buildProviderHeaders(
    AiProviderProfile profile, {
    Uri? uri,
  }) async {
    final apiKey = profile.isLlamaCppServer
        ? ''
        : _normalizeApiKey(
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

  String _extractOpenAiCompatibleContent(dynamic decoded) {
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['type'] == 'text' && part['text'] is String) {
          buffer.write(part['text']);
        }
      }
      if (buffer.isNotEmpty) return buffer.toString().trim();
    }
    for (final key in ['reasoning_content', 'reasoning']) {
      final alt = message[key];
      if (alt is String && alt.trim().isNotEmpty) return alt.trim();
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

  Future<String> _resolveProviderBaseUrl(AiProviderProfile profile) async {
    if (profile.isLlamaCppServer) {
      return LlamaCppEndpointConfig.resolveRootUrl();
    }
    return profile.baseUrl;
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

class _OpenAiToolCall {
  final String id;
  final String name;
  final String argumentsJson;

  const _OpenAiToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });
}
