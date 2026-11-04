import 'dart:io';

import 'api_service.dart';
import 'api_response.dart';
import 'media_category.dart';
import '../models/reply_assist_models.dart';

/// 读屏回复参谋域服务（独立 API，不写入 Companion 会话）。
class ReplyAssistService {
  Future<ReplyAssistSuggestResult> suggest({
    required String source,
    List<ReplyAssistChatMessage> messages = const [],
    String pastedText = '',
    String? imageUrl,
    String appPackage = '',
  }) async {
    final body = <String, dynamic>{
      'source': source,
      'messages': messages.map((m) => m.toJson()).toList(),
      'pasted_text': pastedText,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      if (appPackage.isNotEmpty) 'app_package': appPackage,
    };
    final json = await ApiService.post('/api/reply-assist/suggest', body: body);
    if (!ApiResponse.isSuccess(json)) {
      throw Exception(
          json['msg']?.toString() ?? json['message']?.toString() ?? '请求失败');
    }
    final data = ApiResponse.payload(json);
    return ReplyAssistSuggestResult.fromJson(data);
  }

  Future<String?> uploadScreenshot(File file) async {
    if (!file.existsSync()) return null;
    return ApiService.uploadImage(file, category: MediaCategory.album);
  }
}
