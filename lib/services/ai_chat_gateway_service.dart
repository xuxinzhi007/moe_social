import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_agent.dart';
import '../models/ai_provider_profile.dart';
import 'ai_models_cache_service.dart';
import 'ai_model_list_parser.dart';
import 'ai_provider_service.dart';
import 'api_service.dart';
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
        return '无法连接本机 llama.cpp（端口 6633）。请确认服务已启动并检查地址配置';
      }
      if (kIsWeb &&
          (raw.contains('Failed to fetch') || raw.contains('XMLHttpRequest'))) {
        return '浏览器跨域 (CORS) 拦截了 llama.cpp / ngrok 响应。'
            'ngrok 可能已收到 200，但 Chrome 网页版读不到。'
            '请改用 Windows 桌面 App，或给服务开启 CORS。';
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

  Future<List<String>> fetchModelsForAgent(AiAgent agent) async {
    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    return fetchModelsForProfile(profile);
  }

  Future<List<String>> fetchModelsForProfile(
    AiProviderProfile profile, {
    String? apiKey,
    bool allowCachedFallback = true,
  }) async {
    final accountToken = ApiService.token;
    final cacheProfileId = profile.isBackendOllama
        ? AiProviderProfile.builtinBackendId
        : profile.id;
    try {
      if (profile.isLlamaCppServer || profile.isOpenAiCompatible) {
        final models = await _fetchOpenAiCompatibleModels(
          profile,
          apiKey: apiKey,
        );
        if (models.isNotEmpty || !allowCachedFallback) return models;
      }

      if (profile.isBackendOllama) {
        final decoded = await ApiService.get('/api/llm/models')
            .timeout(const Duration(seconds: 12));
        if (ApiService.token != accountToken) {
          throw ApiException('账号已切换，请重新加载模型');
        }
        final models = _extractModelNames(decoded);
        await AiModelsCacheService().write(cacheProfileId, models);
        if (ApiService.token != accountToken) {
          throw ApiException('账号已切换，请重新加载模型');
        }
        return models;
      }
    } catch (error) {
      if (!allowCachedFallback ||
          (profile.isBackendOllama &&
              (ApiService.token != accountToken ||
                  error is ApiException &&
                      (error.code == 401 || error.code == 403)))) {
        rethrow;
      }
    }

    final cached = await AiModelsCacheService().read(cacheProfileId);
    if (profile.isBackendOllama && ApiService.token != accountToken) {
      throw ApiException('账号已切换，请重新加载模型');
    }
    if (cached.isNotEmpty || profile.isBackendOllama) return cached;

    final fallback = <String>[
      if (profile.defaultModel.trim().isNotEmpty) profile.defaultModel.trim(),
      ...profile.manualModels.map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];
    return fallback.toSet().toList();
  }

  Future<List<String>> _fetchOpenAiCompatibleModels(
    AiProviderProfile profile, {
    String? apiKey,
  }) async {
    final resolvedApiKey = apiKey == null
        ? await AiProviderService().readApiKey(profile.id)
        : AiProviderService.normalizeApiKey(apiKey);
    if (profile.requiresApiKey) {
      if (resolvedApiKey.trim().isEmpty) {
        throw Exception(
          '请先在「模型来源」中为「${profile.name}」填写 API Key',
        );
      }
    }
    final baseUrl = await _resolveProviderBaseUrl(profile);
    final uri = Uri.parse('${_normalizeBaseUrl(baseUrl)}/models');
    final response = await http
        .get(
          uri,
          headers: await _buildProviderHeaders(
            profile,
            uri: uri,
            apiKeyOverride: resolvedApiKey,
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('加载模型失败: ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final names = _extractModelNames(decoded);
    if (names.isNotEmpty) {
      await AiModelsCacheService().write(profile.id, names);
    }
    return names;
  }

  Future<String> sendChat({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
    double? temperature,
    double? topP,
  }) async {
    return _sendToBackendInference(
      agent: agent,
      messages: messages,
      sessionId: sessionId,
      sourceMsgId: sourceMsgId,
      temperature: temperature,
      topP: topP,
    );
  }

  Future<String> _sendToBackendInference({
    required AiAgent agent,
    required List<Map<String, String>> messages,
    String? sessionId,
    String? sourceMsgId,
    double? temperature,
    double? topP,
  }) async {
    final sampling = <String, dynamic>{
      if (temperature != null && temperature >= 0) 'temperature': temperature,
      if (topP != null && topP > 0) 'top_p': topP,
    };
    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/chat');
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
            'agent_id': agent.id,
            'messages': messages,
            'session_id': sessionId,
            'source_msg_id': sourceMsgId,
            ...sampling,
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes).trim();
      final detail = body.length > 500 ? '${body.substring(0, 500)}…' : body;
      throw Exception(
        detail.isEmpty
            ? '后端推理请求失败 (${response.statusCode})'
            : '后端推理请求失败 (${response.statusCode})：$detail',
      );
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    final data = LlmResponseParser.decodeJsonOrNdjson(decodedBody);
    final content = LlmResponseParser.extractChatContent(
      data,
      terminalMode: false,
    );
    if (content.trim().isNotEmpty) return content.trim();

    if (data is Map && data['error'] is String) {
      throw Exception(data['error'] as String);
    }
    throw Exception('响应格式异常');
  }

  Future<Map<String, String>> _buildProviderHeaders(
    AiProviderProfile profile, {
    Uri? uri,
    String? apiKeyOverride,
  }) async {
    final apiKey = profile.isLlamaCppServer
        ? ''
        : _normalizeApiKey(
            apiKeyOverride ?? await AiProviderService().readApiKey(profile.id),
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
    return AiModelListParser.extract(decoded);
  }

  String _normalizeApiKey(String raw) {
    var key = raw.trim();
    if (key.toLowerCase().startsWith('bearer ')) {
      key = key.substring(7).trim();
    }
    return key;
  }

  Future<String> _resolveProviderBaseUrl(AiProviderProfile profile) async {
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
}
