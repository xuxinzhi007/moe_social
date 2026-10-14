import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发帖草稿存储键（CreatePostViewModel 与分享预填入口共用，保持单一来源）。
const String createPostDraftPrefsKey = 'create_post_draft_v1';

/// 写入纯文本分享草稿；字段格式与 CreatePostViewModel.saveDraft 一致。
Future<void> prefillCreatePostShareDraft(String caption) async {
  if (caption.trim().isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      createPostDraftPrefsKey,
      jsonEncode(<String, dynamic>{
        'caption': caption,
        'imageUrls': const <String>[],
        'moodTag': '',
        'topics': <dynamic>[],
      }),
    );
  } catch (e) {
    debugPrint('写入分享预填草稿失败: $e');
  }
}
