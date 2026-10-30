import 'dart:convert';

/// 将 AI 回复拆成可渲染块（文本 / 代码 / JSON / 绘图指令），兼容 `<draw>...</draw>`、
/// 小模型常见的 `(draw)...` / `[draw]...[/draw]` 变体与 ```lang 围栏。
enum AiMessageBlockKind { text, code, json, draw }

class AiMessageBlock {
  const AiMessageBlock({
    required this.kind,
    required this.content,
    this.language,
    this.isIncomplete = false,
  });

  final AiMessageBlockKind kind;
  final String content;
  final String? language;

  /// 流式输出中尚未闭合 `<draw>` 标签时为 true。
  final bool isIncomplete;
}

final _fencePattern = RegExp(
  r'```([^\n`]*)[\r\n]+([\s\S]*?)```',
  multiLine: true,
);

/// 闭合的 `<draw>...</draw>`、`[draw]...[/draw]`、`（draw）...（/draw）`。
final _drawClosedPattern = RegExp(
  r'(?:<draw>|\[draw\]|[(\uff08]draw[)\uff09])([\s\S]*?)(?:</draw>|\[/draw\]|[(\uff08]/draw[)\uff09])',
  caseSensitive: false,
  multiLine: true,
);

/// 小模型（如 3b）常写的单开标签：行首或句尾的 `(draw)...` / `[draw]...`（无闭合标签，直到文本末尾）。
final _drawLooseTailPattern = RegExp(
  r'\s*(?:\[draw\]|[(\uff08]draw[)\uff09])\s*([^\n]+)$',
  caseSensitive: false,
  multiLine: true,
);

final _unclosedOpenTagPattern = RegExp(
  r'<draw>',
  caseSensitive: false,
);

bool messageLooksFormatted(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final lower = t.toLowerCase();
  return lower.contains('<draw>') ||
      lower.contains('(draw)') ||
      lower.contains('（draw）') ||
      lower.contains('[draw]') ||
      t.contains('```') ||
      t.contains('**') ||
      t.contains('*') ||
      t.contains('`') ||
      t.contains('\n- ') ||
      t.contains('\n1. ');
}

/// 去掉 `<draw>` / `(draw)` 绘图指令、代码围栏与常见 Markdown，供 TTS 朗读。
String plainTextForSpeech(String raw) {
  var text = raw.replaceAll('【置顶】', '');
  text = text.replaceAll(_drawClosedPattern, '');
  text = text.replaceAll(_drawLooseTailPattern, '');
  final openMatch = _unclosedOpenTagPattern.firstMatch(text);
  if (openMatch != null) {
    text = text.substring(0, openMatch.start);
  }
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
  final cleaned = raw.replaceAll('【置顶】', '').trim();
  if (cleaned.isEmpty) {
    return const [AiMessageBlock(kind: AiMessageBlockKind.text, content: '')];
  }

  final out = <AiMessageBlock>[];
  var cursor = 0;

  for (final match in _drawClosedPattern.allMatches(cleaned)) {
    if (match.start > cursor) {
      out.addAll(_parseCodeFences(cleaned.substring(cursor, match.start)));
    }
    final prompt = (match.group(1) ?? '').trim();
    if (prompt.isNotEmpty) {
      out.add(
        AiMessageBlock(
          kind: AiMessageBlockKind.draw,
          content: prompt,
        ),
      );
    }
    cursor = match.end;
  }

  if (cursor < cleaned.length) {
    final rest = cleaned.substring(cursor);
    final unclosedMatch = _unclosedOpenTagPattern.firstMatch(rest);
    if (unclosedMatch != null) {
      if (unclosedMatch.start > 0) {
        out.addAll(_parseCodeFences(rest.substring(0, unclosedMatch.start)));
      }
      final partialPrompt = rest.substring(unclosedMatch.end).trim();
      out.add(
        AiMessageBlock(
          kind: AiMessageBlockKind.draw,
          content: partialPrompt,
          isIncomplete: true,
        ),
      );
    } else {
      final looseMatch = _drawLooseTailPattern.firstMatch(rest);
      if (looseMatch != null) {
        if (looseMatch.start > 0) {
          out.addAll(_parseCodeFences(rest.substring(0, looseMatch.start)));
        }
        final loosePrompt = (looseMatch.group(1) ?? '').trim();
        if (loosePrompt.isNotEmpty) {
          out.add(
            AiMessageBlock(
              kind: AiMessageBlockKind.draw,
              content: loosePrompt,
            ),
          );
        }
      } else {
        out.addAll(_parseCodeFences(rest));
      }
    }
  }

  if (out.isEmpty) {
    return [AiMessageBlock(kind: AiMessageBlockKind.text, content: cleaned)];
  }
  return out;
}

List<AiMessageBlock> _parseCodeFences(String segmentRaw) {
  final trimmed = segmentRaw.trim();
  if (trimmed.isEmpty) return const [];

  final blocks = <AiMessageBlock>[];
  var cursor = 0;
  for (final match in _fencePattern.allMatches(segmentRaw)) {
    if (match.start > cursor) {
      final segment = segmentRaw.substring(cursor, match.start).trim();
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

  if (cursor < segmentRaw.length) {
    final tail = segmentRaw.substring(cursor).trim();
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
    return [AiMessageBlock(kind: AiMessageBlockKind.text, content: trimmed)];
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
