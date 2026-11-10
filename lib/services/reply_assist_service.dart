import 'dart:io';

import 'api_service.dart';
import 'api_response.dart';
import 'media_category.dart';
import '../models/reply_assist_models.dart';

/// 读屏回复参谋域服务（独立 API，不写入 Companion 会话）。
class ReplyAssistService {
  // 生成常要 12-18 秒，解析失败重试会更长，不能走通用 18 秒超时。
  static const Duration _suggestTimeout = Duration(seconds: 60);

  Future<ReplyAssistSuggestResult> suggest({
    required String source,
    List<ReplyAssistChatMessage> messages = const [],
    String pastedText = '',
    String? imageUrl,
    String appPackage = '',
    bool adultIntimate = false,
    ReplyAssistChatMessage? targetMessage,
  }) async {
    final body = <String, dynamic>{
      'source': source,
      'messages': messages.map((m) => m.toJson()).toList(),
      'pasted_text': pastedText,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      if (appPackage.isNotEmpty) 'app_package': appPackage,
      'adult_intimate': adultIntimate,
      if (targetMessage != null) 'target_message': targetMessage.toJson(),
    };
    final json = await ApiService.post('/api/reply-assist/suggest', body: body, timeout: _suggestTimeout);
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
