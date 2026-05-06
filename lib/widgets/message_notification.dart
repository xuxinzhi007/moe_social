import 'package:flutter/material.dart';
import 'dart:async';
import '../auth_service.dart';
import '../pages/chat/direct_chat_page.dart';
import '../utils/media_url.dart';

/// 消息通知组件 - 类似 iOS 的通知样式
class MessageNotification {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  /// 在部分路由/嵌套场景下 [Overlay.maybeOf] 可能为 null，依次尝试根 Overlay、Navigator.overlay。
  static OverlayState? _resolveOverlay(BuildContext context) {
    OverlayState? o = Overlay.maybeOf(context, rootOverlay: true);
    o ??= Overlay.maybeOf(context);
    if (o != null) return o;
    final navCtx = AuthService.navigatorKey.currentContext;
    if (navCtx != null && navCtx.mounted) {
      o = Navigator.maybeOf(navCtx, rootNavigator: true)?.overlay;
      o ??= Overlay.maybeOf(navCtx, rootOverlay: true);
    }
    return o;
  }

  static void show(
    BuildContext context,
    String senderName,
    String message,
    String avatarUrl,
    String senderId,
    {Duration duration = const Duration(seconds: 3)}
  ) {
    // 移除之前的通知
    _overlayEntry?.remove();
    _overlayEntry = null;
    _timer?.cancel();

    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      debugPrint(
        'MessageNotification: No Overlay found (context=$context), cannot show notification',
      );
      return;
    }

    final resolvedAvatar = resolveMediaUrl(avatarUrl);
    _overlayEntry = OverlayEntry(
      builder: (context) => _MessageNotificationWidget(
        senderName: senderName,
        message: message,
        avatarUrl: resolvedAvatar,
        senderId: senderId,
      ),
    );

    overlay.insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _timer?.cancel();
  }
}

class _MessageNotificationWidget extends StatefulWidget {
  final String senderName;
  final String message;
  final String avatarUrl;
  final String senderId;

  const _MessageNotificationWidget({
    required this.senderName,
    required this.message,
    required this.avatarUrl,
    required this.senderId,
  });

  @override
  State<_MessageNotificationWidget> createState() => _MessageNotificationWidgetState();
}

class _MessageNotificationWidgetState extends State<_MessageNotificationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {
                  // 点击通知跳转到聊天页面
                  MessageNotification.dismiss();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DirectChatPage(
                        userId: widget.senderId,
                        username: widget.senderName,
                        avatar: widget.avatarUrl,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 头像
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            image: widget.avatarUrl.isNotEmpty && widget.avatarUrl != 'null'
                                ? DecorationImage(
                                    image: NetworkImage(widget.avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[200],
                          ),
                          child: (widget.avatarUrl.isEmpty || widget.avatarUrl == 'null')
                              ? const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // 消息内容
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF606060),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // 关闭按钮
                        IconButton(
                          onPressed: MessageNotification.dismiss,
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}