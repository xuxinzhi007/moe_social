import 'dart:convert';

class LlmResponseParser {
  LlmResponseParser._();

  static dynamic decodeJsonOrNdjson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('Empty response body');
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      final lines = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.isEmpty) rethrow;
      final chunks = <dynamic>[];
      for (final line in lines) {
        chunks.add(jsonDecode(line));
      }
      return chunks;
    }
  }

  static String extractChatContent(dynamic data, {required bool terminalMode}) {
    if (!terminalMode) {
      if (data is Map && data['content'] is String) {
        return data['content'] as String;
      }
      if (data is List && data.isNotEmpty) {
        final last = data.last;
        if (last is Map && last['content'] is String) {
          return last['content'] as String;
        }
      }
      return '';
    }

    if (data is Map) {
      final msg = data['message'];
      if (msg is Map && msg['content'] is String) {
        return msg['content'] as String;
      }
      return '';
    }

    if (data is List) {
      final sb = StringBuffer();
      for (final chunk in data) {
        if (chunk is! Map) continue;
        final msg = chunk['message'];
        if (msg is Map && msg['content'] is String) {
          sb.write(msg['content'] as String);
        }
      }
      return sb.toString();
    }
    return '';
  }
}
