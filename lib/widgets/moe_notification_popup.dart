import 'package:flutter/material.dart';

/// 可复用的轻量通知提示弹窗（统一视觉，业务方传入未读数与跳转）。
Future<void> showMoeNotificationPopup({
  required BuildContext context,
  required int unreadCount,
  required VoidCallback onView,
  required VoidCallback onLater,
}) {
  if (unreadCount <= 0) {
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7FD5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF7F7FD5),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '新消息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        unreadCount == 1
            ? '你有 1 条未读通知，是否前往通知中心查看？'
            : '你有 $unreadCount 条未读通知，是否前往通知中心查看？',
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onLater();
          },
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            onView();
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7F7FD5),
            foregroundColor: Colors.white,
          ),
          child: const Text('查看'),
        ),
      ],
    ),
  );
}
