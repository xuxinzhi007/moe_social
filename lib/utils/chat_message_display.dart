/// 私信在列表、通知等处的展示文案（与 [DirectChatPage] 的 `[IMG]` 前缀约定一致）。
String formatDmPreviewForUi(String content) {
  final t = content.trim();
  if (t.startsWith('[IMG]')) {
    return '[图片]';
  }
  return t;
}

/// 服务端常把 `sender_name` 填成 Moe 号（纯数字）；应用内展示应优先用昵称。
bool looksLikeMoeNoOrWeakSenderLabel(String name) {
  final t = name.trim();
  if (t.isEmpty || t == '用户') return true;
  return RegExp(r'^\d{6,}$').hasMatch(t);
}
