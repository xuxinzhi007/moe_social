import 'package:flutter/material.dart';

/// 原「未读通知居中摘要弹窗」与顶部 [MessageNotification] / 角标重复，已关闭居中弹窗，仅透传子树。
///
/// 若将来需要恢复居中提示，可再接入 [showMoeNotificationPopup] 并做与私信的互斥策略。
class NotificationPopupHost extends StatelessWidget {
  const NotificationPopupHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
