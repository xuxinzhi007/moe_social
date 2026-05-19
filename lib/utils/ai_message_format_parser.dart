import 'dart:convert';

/// 将 AI 回复拆成可渲染块（文本 / 代码 / JSON），兼容酒馆式 ```lang 围栏。
enum AiMessageBlockKind { text, code, json }

class AiMessageBlock {
  const AiMessageBlock({
    required this.kind,
    required this.content,
    this.language,
  });

  final AiMessageBlockKind kind;
  final String content;
  final String? language;
}

final _fencePattern = RegExp(
  r'```([^\n`]*)[\r\n]+([\s\S]*?)```',
  multiLine: true,
);

bool messageLooksFormatted(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  return t.contains('```') ||
      t.contains('**') ||
      t.contains('*') ||
      t.contains('`') ||
      t.contains('\n- ') ||
      t.contains('\n1. ');
}

/// 去掉围栏与常见 Markdown，供 TTS 朗读。
String plainTextForSpeech(String raw) {
  var text = raw;
  text = text.replaceAllMapped(
    _fencePattern,
    (m) => m.group(2)?.trim() ?? '',
  );
  text = text.replaceAll(RegExp(r'`+'), '');
  text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
  text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
  text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

List<AiMessageBlock> parseAiMessageContent(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const [AiMessageBlock(kind: AiMessageBlockKind.text, content: '')];
  }

  final blocks = <AiMessageBlock>[];
  var cursor = 0;
  for (final match in _fencePattern.allMatches(raw)) {
    if (match.start > cursor) {
      final segment = raw.substring(cursor, match.start).trim();
      if (segment.isNotEmpty) {
        blocks.add(
          AiMessageBlock(kind: AiMessageBlockKind.text, content: segment),
        );
      }
    }

    final lang = (match.group(1) ?? '').trim().toLowerCase();
    final body = (match.group(2) ?? '').trimRight();
    final isJson = lang == 'json' || _looksLikeJson(body);
    blocks.add(
      AiMessageBlock(
        kind: isJson ? AiMessageBlockKind.json : AiMessageBlockKind.code,
        content: body,
        language: lang.isEmpty ? (isJson ? 'json' : null) : lang,
      ),
    );
    cursor = match.end;
  }

  if (cursor < raw.length) {
    final tail = raw.substring(cursor).trim();
    if (tail.isNotEmpty) {
      blocks.add(AiMessageBlock(kind: AiMessageBlockKind.text, content: tail));
    }
  }

  if (blocks.isEmpty) {
    if (_looksLikeJson(trimmed)) {
      return [
        AiMessageBlock(
          kind: AiMessageBlockKind.json,
          content: trimmed,
          language: 'json',
        ),
      ];
    }
    return [AiMessageBlock(kind: AiMessageBlockKind.text, content: raw)];
  }

  return blocks;
}

bool _looksLikeJson(String text) {
  final t = text.trim();
  if (t.length < 2) return false;
  if (!(t.startsWith('{') && t.endsWith('}')) &&
      !(t.startsWith('[') && t.endsWith(']'))) {
    return false;
  }
  try {
    final decoded = jsonDecode(t);
    return decoded is Map || decoded is List;
  } catch (_) {
    return false;
  }
}

String formatJsonForDisplay(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}
