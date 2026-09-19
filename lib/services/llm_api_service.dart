import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';
import 'ai_models_cache_service.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'llm_endpoint_config.dart';

/// 本人受管模型的服务端视图；HTTP 200 不代表写操作已完成。
class LlmManagedModel {
  const LlmManagedModel({
    required this.agentId,
    required this.modelName,
    required this.baseModel,
    required this.state,
    required this.requestId,
    this.code = 0,
    this.message = '',
    this.success = false,
    this.bindingApplied = false,
    this.retryable = false,
  });

  factory LlmManagedModel.fromJson(Map<String, dynamic> json) =>
      LlmManagedModel(
        agentId: json['agent_id']?.toString() ?? '',
        modelName: json['model_name']?.toString() ?? '',
        baseModel: json['base_model']?.toString() ?? '',
        state: json['state']?.toString() ?? 'unknown',
        requestId: json['request_id']?.toString() ?? '',
        code: (json['code'] as num?)?.toInt() ?? 0,
        message: json['message']?.toString() ?? '',
        success: json['success'] == true,
        bindingApplied: json['binding_applied'] == true,
        retryable: json['retryable'] == true,
      );

  final String agentId, modelName, baseModel, state, requestId, message;
  final int code;
  final bool success, bindingApplied, retryable;
  bool get isReady => success && state == 'ready';
  bool get isUnresolved =>
      const ['unknown', 'pending', 'deleting'].contains(state);
  bool get isDeleted => success && state == 'deleted';

  String get statusLabel => switch (state) {
        'ready' => '已就绪',
        'pending' => '创建中',
        'deleting' => '删除中',
        'deleted' => '已删除',
        'failed' => '失败',
        _ => '结果未知',
      };

  String get outcomeMessage {
    if (isUnresolved) return '结果尚未确认，请到「本人模型管理」重查；不要重复创建或删除。';
    if (isReady && !bindingApplied) return '模型已就绪，但角色卡已变更，未自动绑定；请刷新角色卡后检查。';
    if (isReady) return '本人模型已同步并绑定角色卡';
    if (isDeleted) return '本人模型已删除';
    return message.isNotEmpty ? message : '模型操作未完成';
  }
}

/// LLM 配置 / agent 同步等 `/api/llm/*` 与 Ollama show 的域服务封装。
class LlmApiService {
  LlmApiService._();

  /// 读取后端生效的 LLM / 记忆预算 / runtime 配置。
  static Future<Map<String, dynamic>> getConfig() async {
    final decoded = await ApiClient.get('/api/llm/config');
    final data = normalizeConfig(ApiResponse.nestedPayload(decoded));
    final inference = data['llm_inference'];
    final budget = data['memory_budget'];
    if (inference is! Map ||
        inference.isEmpty ||
        budget is! Map ||
        budget.isEmpty) {
      throw Exception('配置字段缺失');
    }
    return data;
  }

  /// 兼容旧嵌套 `llm_inference`/`ollama` 与当前扁平 `inference_*` 字段。
  static Map<String, dynamic> normalizeConfig(Map<String, dynamic> data) {
    final nested = data['llm_inference'] ?? data['ollama'];
    final inference = <String, dynamic>{};
    if (nested is Map) {
      inference.addAll(Map<String, dynamic>.from(nested));
    }
    if (inference['base_url'] == null &&
        (data['inference_base_url'] != null ||
            data['inference_api_style'] != null)) {
      inference['base_url'] = data['inference_base_url'];
      inference['api_style'] = data['inference_api_style'];
      inference['timeout_seconds'] = data['inference_timeout_sec'];
      inference['memory_model'] = data['memory_model'];
      inference['has_summary_prompt'] = data['has_summary_prompt'];
      inference['has_extract_prompt'] = data['has_extract_prompt'];
    }
    inference['supports_model_management'] =
        data['supports_model_management'] ??
            inference['supports_model_management'] ??
            false;
    inference['model_sync_timeout_seconds'] =
        data['model_sync_timeout_seconds'] ??
            inference['model_sync_timeout_seconds'] ??
            120;
    return {
      'llm_inference': inference,
      'memory_budget': data['memory_budget'] is Map
          ? Map<String, dynamic>.from(data['memory_budget'] as Map)
          : <String, dynamic>{},
      'runtime': data['runtime'] is Map
          ? Map<String, dynamic>.from(data['runtime'] as Map)
          : null,
    };
  }

  /// 配置仅用于协议与能力，绝不作为客户端推理地址。
  static Future<Map<String, dynamic>> getInferenceConfig() async {
    final result = await ApiClient.get('/api/llm/config');
    return normalizeConfig(ApiResponse.nestedPayload(result))['llm_inference']
        as Map<String, dynamic>;
  }

  /// UUID v4；同一未决操作必须复用调用方保存的 ID。
  static String newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String _managedPath(String agentId) =>
      '/api/llm/managed-models/${Uri.encodeComponent(agentId)}';

  static Future<List<LlmManagedModel>> listManagedModels() async {
    final payload = await _managedRequest('/api/llm/managed-models');
    if (!ApiResponse.isSuccess(payload)) {
      throw ApiException(payload['message']?.toString() ?? '加载本人模型失败');
    }
    final models = payload['models'];
    if (models is! List) throw const FormatException('模型列表格式错误');
    return models
        .map((e) =>
            LlmManagedModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<LlmManagedModel> getManagedModel(String agentId) async =>
      LlmManagedModel.fromJson(await _managedRequest(_managedPath(agentId)));

  static Future<LlmManagedModel> reconcileManagedModel(String agentId) async =>
      _mutateManagedModel('${_managedPath(agentId)}/reconcile',
          agentId: agentId, requestId: '', body: const {});

  static Future<LlmManagedModel> deleteManagedModel({
    required String agentId,
    required String requestId,
  }) =>
      _mutateManagedModel(_managedPath(agentId),
          method: 'DELETE',
          agentId: agentId,
          requestId: requestId,
          body: {'request_id': requestId});

  static Future<LlmManagedModel> upsertAgentPrompt({
    required String agentId,
    required String requestId,
    required String baseModel,
    required String systemPrompt,
  }) =>
      _mutateManagedModel('/api/llm/agents',
          agentId: agentId,
          requestId: requestId,
          baseModel: baseModel,
          body: {
            'agent_id': agentId,
            'request_id': requestId,
            'base_model': baseModel,
            'system_prompt': systemPrompt
          });

  static Future<LlmManagedModel> _mutateManagedModel(
    String path, {
    String method = 'POST',
    required String agentId,
    required String requestId,
    String baseModel = '',
    required Map<String, dynamic> body,
  }) async {
    final token = ApiClient.token;
    if (token == null || token.isEmpty) throw ApiException('请先登录');
    final config = await getInferenceConfig();
    if (ApiClient.token != token) throw ApiException('账号已切换，请重新打开页面');
    final seconds =
        (config['model_sync_timeout_seconds'] as num?)?.toInt() ?? 120;
    final timeout = Duration(seconds: (seconds > 0 ? seconds : 120) + 15);
    try {
      final payload = await _managedRequest(path,
          method: method, body: body, timeout: timeout);
      final view = LlmManagedModel.fromJson(payload);
      await AiModelsCacheService()
          .invalidate(AiProviderProfile.builtinBackendId);
      return view;
    } on ApiException {
      rethrow; // 确定的非 2xx，交由用户处理，不自动重试。
    } catch (_) {
      // 请求发送后断连、超时或响应损坏，都不能证明上游未执行。
      await AiModelsCacheService()
          .invalidate(AiProviderProfile.builtinBackendId);
      return LlmManagedModel(
          agentId: agentId,
          requestId: requestId,
          modelName: '',
          baseModel: baseModel,
          state: 'unknown');
    }
  }

  static Future<Map<String, dynamic>> _managedRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final token = ApiClient.token;
    if (token == null || token.isEmpty) throw ApiException('请先登录');
    final uri = Uri.parse('${ApiClient.baseUrl}$path');
    final headers = ApiClient.mergeTunnelHeaders(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    final Future<http.Response> pending = switch (method) {
      'DELETE' => http.delete(uri, headers: headers, body: jsonEncode(body)),
      'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
      _ => http.get(uri, headers: headers),
    };
    final response = await pending.timeout(timeout);
    if (ApiClient.token != token) throw ApiException('账号已切换，请重新打开页面');
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = '模型请求失败（HTTP ${response.statusCode}）';
      try {
        final error = jsonDecode(text);
        if (error is Map) {
          message = (error['message'] ?? error['msg'] ?? message).toString();
        }
      } on FormatException {
        // 网关纯文本错误仍保留 HTTP 状态，不误当未知写入。
      }
      throw ApiException(message, response.statusCode);
    }
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return decoded['data'] is Map
        ? ApiResponse.nestedPayload(decoded)
        : decoded;
  }

  /// 从 Ollama `/api/show` 读取 system prompt（含 modelfile SYSTEM 回退）。
  static Future<String> fetchOllamaSystemPrompt(String modelName) async {
    try {
      final uri = LlmEndpointConfig.showUri();
      ApiClient.logDirectHttp('POST', uri);
      final token = ApiClient.token;
      final headers = ApiClient.mergeTunnelHeaders(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      final response = await http
          .post(uri, headers: headers, body: jsonEncode({'name': modelName}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map &&
            data['system'] is String &&
            (data['system'] as String).isNotEmpty) {
          return data['system'] as String;
        }
        if (data is Map && data['modelfile'] is String) {
          final mf = data['modelfile'] as String;
          final tripleMatch =
              RegExp(r'SYSTEM\s+"""([\s\S]*?)"""', multiLine: true)
                  .firstMatch(mf);
          if (tripleMatch != null) return tripleMatch.group(1)?.trim() ?? '';
          final singleMatch = RegExp(r'SYSTEM\s+"(.*?)"').firstMatch(mf);
          if (singleMatch != null) return singleMatch.group(1)?.trim() ?? '';
        }
        return '';
      }
      return '（读取失败：HTTP ${response.statusCode}）';
    } catch (e) {
      return '（读取失败：$e）';
    }
  }
}
