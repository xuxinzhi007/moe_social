import 'package:flutter/material.dart';
import 'dart:async';

/// 萌社风格轻量级 Toast 通知
class MoeToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, 
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
  }) {
    // 移除之前的 Toast
    _overlayEntry?.remove();
    _overlayEntry = null;
    _timer?.cancel();

    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  /// 成功提示
  static void success(BuildContext context, String message) {
    show(
      context, 
      message, 
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFFF0FDF4),
      textColor: const Color(0xFF16A34A),
    );
  }

  /// 错误提示
  static void error(BuildContext context, String message) {
    show(
      context, 
      message, 
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFFEF2F2),
      textColor: const Color(0xFFDC2626),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const _ToastWidget({
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _offset = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _opacity,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.textColor ?? Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.textColor ?? Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}