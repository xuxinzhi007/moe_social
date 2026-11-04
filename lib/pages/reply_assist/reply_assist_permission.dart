/// 回复参谋桌宠所需的系统权限缺口（无障碍优先于悬浮窗）。
enum ReplyAssistPermGap {
  accessibility,
  overlay,
}

/// 返回第一项未就绪的权限；两权都齐则 `null`。
ReplyAssistPermGap? firstReplyAssistPermGap({
  required bool a11yEnabled,
  required bool overlayPermissionGranted,
}) {
  if (!a11yEnabled) return ReplyAssistPermGap.accessibility;
  if (!overlayPermissionGranted) return ReplyAssistPermGap.overlay;
  return null;
}

String replyAssistPermGapHint(ReplyAssistPermGap gap) {
  switch (gap) {
    case ReplyAssistPermGap.accessibility:
      return '请先开启无障碍（只读聊天，不代操作）';
    case ReplyAssistPermGap.overlay:
      return '请先开启悬浮窗（贴纸桌宠层）';
  }
}
