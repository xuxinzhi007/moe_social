import 'dart:convert';

import 'api_response.dart';
import 'api_service.dart';

class ContentGenerationService {
  const ContentGenerationService();

  Future<String> generate({
    required String type,
    required String prompt,
    String? agentId,
  }) async {
    final options = <String, dynamic>{
      if (agentId != null && agentId.trim().isNotEmpty)
        'agent_id': agentId.trim(),
    };
    final response = await ApiService.post(
      '/api/content/generate',
      body: {
        'type': type,
        'prompt': prompt,
        if (options.isNotEmpty) 'options_json': jsonEncode(options),
      },
    );
    final data = ApiResponse.object(response);
    final content = data['content']?.toString().trim() ?? '';
    if (content.isNotEmpty) return content;
    final url = data['url']?.toString().trim() ?? '';
    if (url.isNotEmpty) return url;
    throw ApiException('生成结果为空');
  }
}
