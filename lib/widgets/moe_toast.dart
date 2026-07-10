import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';

/// 钀岀ぞ椋庢牸杞婚噺绾?Toast 閫氱煡
class MoeToast {
  static OverlayEntry? _overlayEntry;

  /// 涓诲姩绉婚櫎褰撳墠 Toast锛屽父鐢ㄤ簬椤甸潰鍒囨崲/鐧诲嚭绛夊満鏅?
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

  /// 鎴愬姛鎻愮ず
  static void success(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFFF0FDF4),
      textColor: const Color(0xFF16A34A),
    );
  }

  /// 閿欒鎻愮ず
  static void error(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFFEF2F2),
      textColor: const Color(0xFFDC2626),
    );
  }

  /// 淇℃伅鎻愮ず
  static void info(BuildContext context, String message) {
    show(
      context,
      message,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFFEFF6FF),
      textColor: const Color(0xFF2563EB),
    );
  }

  /// 璀﹀憡鎻愮ず
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
    final toastBody = Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
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
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top + 40,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: moeReduceMotion(context)
            ? toastBody
            : ScaleTransition(
                scale: _scale,
                child: SlideTransition(
                  position: _offset,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: toastBody,
                  ),
                ),
              ),
      ),
    );
  }
}
