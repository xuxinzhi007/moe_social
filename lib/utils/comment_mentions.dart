import 'package:flutter/painting.dart';

/// 评论 @ 规则：必须在开头或空白之后，用户名最长 50，避免拆开邮箱。
final RegExp commentMentionPattern = RegExp(
  r'(?:^|\s)@([\p{L}\p{N}_]{1,50})',
  unicode: true,
);

const int maxCommentMentionSuggestions = 6;

/// 光标前正在输入的 @ 片段。没有进行中的提及时返回 null。
String? activeCommentMentionQuery(String text, int cursor) {
  if (text.isEmpty) return null;
  if (cursor < 0 || cursor > text.length) cursor = text.length;
  final head = text.substring(0, cursor);
  final at = head.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0 && !RegExp(r'\s').hasMatch(head[at - 1])) return null;
  final query = head.substring(at + 1);
  if (query.contains(RegExp(r'\s'))) return null;
  if (query.length > 50) return null;
  return query;
}

class CommentMentionEdit {
  const CommentMentionEdit({required this.text, required this.cursor});

  final String text;
  final int cursor;
}

/// 把光标处的 @片段 换成 `@username `。
CommentMentionEdit applyCommentMention(
    String text, int cursor, String username) {
  if (cursor < 0 || cursor > text.length) cursor = text.length;
  final head = text.substring(0, cursor);
  final at = head.lastIndexOf('@');
  if (at < 0) {
    return CommentMentionEdit(text: text, cursor: cursor);
  }
  final insert = '@$username ';
  final next = head.substring(0, at) + insert + text.substring(cursor);
  return CommentMentionEdit(text: next, cursor: at + insert.length);
}

/// 把正文里的 @用户名 拆成可着色的片段。
List<InlineSpan> commentMentionSpans(
  String text,
  TextStyle base,
  TextStyle mention,
) {
  if (text.isEmpty) {
    return [TextSpan(text: text, style: base)];
  }
  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in commentMentionPattern.allMatches(text)) {
    final nameStart = match.start + (text[match.start] == '@' ? 0 : 1);
    if (nameStart > start) {
      spans.add(TextSpan(text: text.substring(start, nameStart), style: base));
    }
    spans.add(
        TextSpan(text: text.substring(nameStart, match.end), style: mention));
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: base));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: base));
  }
  return spans;
}
