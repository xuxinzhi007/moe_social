import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 每日一文（外部轻量文案 API）。仅供域层调用，UI 不得直连 HTTP。
class DailyQuoteService {
  DailyQuoteService._();

  static const String fallbackQuote = '生活明朗，万物可爱。';
  static const Duration _timeout = Duration(seconds: 10);

  static final Uri _quoteUri = Uri.parse(
    'https://api.52vmy.cn/api/chat/spark?msg='
    '${Uri.encodeComponent('生成一句温暖治愈的每日一文，只输出一句话，不要任何前缀/解释，不要JSON/字段名，控制在18个汉字以内')}',
  );

  /// 拉取一句每日一文；失败时返回 [fallbackQuote]。
  static Future<String> fetchQuote() async {
    try {
      final response = await http.get(_quoteUri).timeout(_timeout);
      if (response.statusCode != 200) {
        return fallbackQuote;
      }

      final rawText = utf8.decode(response.bodyBytes).trim();
      final content = _parseQuote(rawText);
      if (content != null && content.isNotEmpty) {
        return content;
      }
    } catch (e) {
      debugPrint('DailyQuoteService.fetchQuote failed: $e');
    }
    return fallbackQuote;
  }

  static String? _parseQuote(String rawText) {
    try {
      final data = jsonDecode(rawText);
      String? content;
      if (data is Map) {
        if (data['answer'] is String) {
          content = data['answer'] as String;
        } else if (data['data'] is Map &&
            (data['data'] as Map)['answer'] is String) {
          content = (data['data'] as Map)['answer'] as String;
        }
        content ??= data['content']?.toString();
        content ??= data['data']?.toString();
        content ??= data['message']?.toString();
      }
      content ??= _extractAnswerFromLooseText(rawText);
      return _cleanQuote(content);
    } catch (_) {
      return _cleanQuote(_extractAnswerFromLooseText(rawText));
    }
  }

  static String? _cleanQuote(String? input) {
    var s = input?.trim();
    if (s == null || s.isEmpty) return s;

    s = _extractAnswerFromLooseText(s) ?? s;
    s = s.replaceFirst(
        RegExp(r'^(answer|回答)\s*[:：]\s*', caseSensitive: false), '');
    s = s.replaceFirst(
      RegExp(
        r'^(Skill|Answer|Response|AI|好的|当然|没问题|Here is|Sure)\s*[，。！:：\n]*\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'^[\s\{\[\"“]+'), '');
    s = s.replaceAll(RegExp(r'[\s\}\]\"”]+$'), '');
    s = s
        .split(RegExp(r'\s*(time|questions?)\s*[:：]', caseSensitive: false))
        .first
        .trim();
    return s.trim();
  }

  static String? _extractAnswerFromLooseText(String raw) {
    final m = RegExp(r'answer\s*[:：]\s*([^,}\n]+)', caseSensitive: false)
        .firstMatch(raw);
    return m?.group(1)?.trim();
  }
}
