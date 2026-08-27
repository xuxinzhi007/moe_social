/// 私信在列表、通知等处的展示文案（与 [DirectChatPage] 的 `[IMG]`/`[VOICE]` 前缀约定一致）。
String formatDmPreviewForUi(String content) {
  final t = content.trim();
  if (t.startsWith('[IMG]')) {
    return '[图片]';
  }
  if (t.startsWith('[VOICE]')) {
    // 图标由 UI 层用 MoeIcon(name: 'mic') 渲染（见 isVoiceDmPreview），
    // 此处仅返回纯文本，供通知等无 Widget 上下文兜底。
    return '语音消息';
  }
  return t;
}

/// 判断私信原文是否为语音消息（`[VOICE]` 前缀约定）。
///
/// UI 层据此用 `MoeIcon(name: 'mic')` + 文案渲染预览，替代旧的 🎤 emoji。
/// 长度守卫与权威判定 DirectChatViewModel.isVoiceContent 对齐：裸 `[VOICE]`
/// 串（无后续内容）不算语音消息，避免列表显语音图标但会话内渲染
/// 文本气泡的不一致。
bool isVoiceDmPreview(String content) {
  final t = content.trim();
  return t.startsWith('[VOICE]') && t.length > '[VOICE]'.length;
}

/// 服务端常把 `sender_name` 填成 Moe 号（纯数字）；应用内展示应优先用昵称。
bool looksLikeMoeNoOrWeakSenderLabel(String name) {
  final t = name.trim();
  if (t.isEmpty || t == '用户') return true;
  return RegExp(r'^\d{6,}$').hasMatch(t);
}
