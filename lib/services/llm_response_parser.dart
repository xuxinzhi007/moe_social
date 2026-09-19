import 'dart:convert';

import 'api_response.dart';

class LlmResponseParser {
  LlmResponseParser._();

  static dynamic decodeJsonOrNdjson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const FormatException('Empty response body');
    try {
      return jsonDecode(text);
    } on FormatException {
      final chunks = <dynamic>[];
      for (var line in text.split('\n').map((e) => e.trim())) {
        if (line.isEmpty || line.startsWith(':') || line.startsWith('event:')) {
          continue;
        }
        if (line.startsWith('data:')) line = line.substring(5).trim();
        if (line == '[DONE]') {
          chunks.add({'_stream_done': true});
        } else {
          chunks.add(jsonDecode(line));
        }
      }
      if (chunks.isEmpty) rethrow;
      return chunks;
    }
  }

  static void _checkError(Map data) {
    final error = data['error'];
    if (error != null) {
      throw FormatException(error is Map
          ? (error['message'] ?? error['code'] ?? '模型服务错误').toString()
          : error.toString());
    }
    if (!ApiResponse.isSuccess(Map<String, dynamic>.from(data))) {
      throw FormatException(
          (data['message'] ?? data['msg'] ?? '模型请求失败').toString());
    }
  }

  static String _content(Map data) {
    _checkError(data);
    if (data['content'] is String) return data['content'] as String;
    final message = data['message'];
    if (message is Map) return _text(message['content']);
    if (data['response'] is String) return data['response'] as String;
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map;
      final msg = choice['message'] ?? choice['delta'];
      if (msg is Map) return _text(msg['content']);
    }
    return '';
  }

  static String _text(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      return value
          .whereType<Map>()
          .where((p) => p['type'] == 'text')
          .map((p) => p['text'] is String ? p['text'] : '')
          .join();
    }
    return '';
  }

  static String extractChatContent(dynamic data, {required bool terminalMode}) {
    if (data is Map) {
      _checkError(data);
      if (data['data'] is Map) {
        return extractChatContent(data['data'], terminalMode: terminalMode);
      }
      if (data['done'] == false) {
        throw const FormatException('模型流未完整结束');
      }
      return _content(data);
    }
    if (data is List) {
      final buffer = StringBuffer();
      var complete = false;
      for (final chunk in data) {
        if (chunk is! Map) throw const FormatException('模型响应格式错误');
        _checkError(chunk);
        buffer.write(_content(chunk));
        final choices = chunk['choices'];
        complete = complete ||
            chunk['done'] == true ||
            chunk['_stream_done'] == true ||
            (choices is List &&
                choices.any((c) => c is Map && c['finish_reason'] != null));
      }
      if (!complete) throw const FormatException('模型流未完整结束');
      return buffer.toString();
    }
    throw const FormatException('模型响应格式错误');
  }
}
