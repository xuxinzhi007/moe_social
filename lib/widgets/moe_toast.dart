import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';

/// 萌社风格轻量级 Toast 通知
class MoeToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  /// 主动移除当前 Toast，常用于页面切换/登出等场景
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void show(
    BuildContext context, 
    String message, {
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
  }) {
    void mount() {
      // 移除之前的 Toast
      dismiss();

      final overlay = Overlay.maybeOf(context);
      if (overlay == null) {
        print('MoeToast: No Overlay found, cannot show toast');
        return;
      }

      _overlayEntry = OverlayEntry(
        builder: (context) => _ToastWidget(
          message: message,
          icon: icon,
          backgroundColor: backgroundColor,
          textColor: textColor,
        ),
      );

      overlay.insert(_overlayEntry!);

      _timer = Timer(duration, () {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }

    // 避免在 layout/build 阶段直接改 Overlay，与 setState 同帧时易触发
    // Duplicate GlobalKeys / _OverlayEntryWidgetState 类问题。
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        mount();
      });
    } else {
      mount();
    }
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

  /// 信息提示
  static void info(BuildContext context, String message) {
    show(
      context, 
      message, 
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFFEFF6FF),
      textColor: const Color(0xFF2563EB),
    );
  }

  /// 警告提示
  static void warning(BuildContext context, String message) {
    show(
      context, 
      message, 
      icon: Icons.warning_rounded,
      backgroundColor: const Color(0xFFFFFBEB),
      textColor: const Color(0xFFD97706),
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
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
    _offset = Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOut,
    ));
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOut,
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
      top: MediaQuery.of(context).padding.top + 40,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: ScaleTransition(
          scale: _scale,
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _opacity,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
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
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.textColor ?? Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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