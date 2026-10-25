import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';

/// 萌社风格轻量级 Toast 通知。
class MoeToast {
  static OverlayEntry? _overlayEntry;

  /// 主动移除当前 Toast，常用于页面切换、退出登录等场景。
  static void dismiss() {
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
      dismiss();

      final overlay =
          Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
      if (overlay == null) {
        debugPrint('MoeToast: No Overlay found, cannot show toast');
        return;
      }

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) => _ToastWidget(
          message: message,
          icon: icon,
          backgroundColor: backgroundColor,
          textColor: textColor,
          duration: duration,
          onClose: () {
            if (_overlayEntry == entry) {
              entry.remove();
              _overlayEntry = null;
            }
          },
        ),
      );

      _overlayEntry = entry;
      overlay.insert(entry);
    }

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

  /// 成功提示。
  static void success(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFFF0FDF4),
      textColor: const Color(0xFF16A34A),
    );
  }

  /// 错误提示。
  static void error(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFFEF2F2),
      textColor: const Color(0xFFDC2626),
    );
  }

  /// 信息提示。
  static void info(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFFEFF6FF),
      textColor: const Color(0xFF2563EB),
    );
  }

  /// 警告提示。
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
  final Duration duration;
  final VoidCallback onClose;

  const _ToastWidget({
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
    required this.duration,
    required this.onClose,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MoeTokens.motionMedium,
      reverseDuration: MoeTokens.motionFast,
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moeReduceMotion(context)) {
        _autoCloseTimer = Timer(widget.duration, widget.onClose);
        return;
      }
      _controller.forward();
      _autoCloseTimer = Timer(widget.duration, _dismissAnimated);
    });
  }

  Future<void> _dismissAnimated() async {
    _autoCloseTimer?.cancel();
    if (!mounted) return;
    if (moeReduceMotion(context) ||
        _controller.status == AnimationStatus.dismissed) {
      widget.onClose();
      return;
    }
    await _controller.reverse();
    if (mounted) {
      widget.onClose();
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.textColor ?? Colors.white;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 6,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const iconSize = 14.0;
              const gap = 6.0;
              const padH = 12.0;
              final textMax = (constraints.maxWidth - padH * 2 - iconSize - gap)
                  .clamp(72.0, 280.0);
              final toastBody = Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.backgroundColor ??
                            Colors.black.withValues(alpha: 0.82))
                        .withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    border: Border.all(color: ink.withValues(alpha: 0.12)),
                    boxShadow: MoeTokens.shadowSm(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: ink, size: iconSize),
                        const SizedBox(width: gap),
                      ],
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: textMax),
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: ink,
                            fontSize: MoeTokens.textSm,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (moeReduceMotion(context)) return toastBody;
              return ScaleTransition(
                scale: _scale,
                child: SlideTransition(
                  position: _offset,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: toastBody,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
