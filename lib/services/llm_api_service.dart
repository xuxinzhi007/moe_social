import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_response.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';

/// LLM 配置 / agent 同步等 `/api/llm/*` 与 Ollama show 的域服务封装。
class LlmApiService {
  LlmApiService._();

  /// 读取后端生效的 LLM / 记忆预算 / runtime 配置。
  static Future<Map<String, dynamic>> getConfig() async {
    final decoded = await ApiClient.get('/api/llm/config');
    final data = ApiResponse.nestedPayload(decoded);
    if (data.isEmpty) {
      throw Exception('配置数据为空');
    }
    return data;
  }

  /// 同步角色 system prompt 到后端 `/api/llm/agents`。
  static Future<void> upsertAgentPrompt({
    required String name,
    required String baseModel,
    required String systemPrompt,
  }) async {
    final result = await ApiService.post('/api/llm/agents', body: {
      'name': name,
      'base_model': baseModel,
      'system_prompt': systemPrompt,
    });
    if (!ApiResponse.isSuccess(result)) {
      throw Exception(result['message']?.toString() ?? '同步失败');
    }
  }

  /// 从 Ollama `/api/show` 解析 FROM 基座模型名；失败时回退 [modelName]。
  static Future<String> resolveBaseModelFromShow(String modelName) async {
    try {
      final uri = LlmEndpointConfig.showUri();
      final token = ApiClient.token;
      final headers = ApiClient.mergeTunnelHeaders(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'name': modelName}),
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return modelName;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return modelName;
      final modelfile = data['modelfile'];
      if (modelfile is! String || modelfile.trim().isEmpty) {
        return modelName;
      }
      final fromMatch = RegExp(r'^\s*FROM\s+([^\s#]+)', multiLine: true)
          .firstMatch(modelfile);
      final fromModel = fromMatch?.group(1)?.trim();
      if (fromModel != null && fromModel.isNotEmpty) {
        return fromModel;
      }
      return modelName;
    } catch (_) {
      return modelName;
    }
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
