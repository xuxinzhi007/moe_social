// Hallmark · layout: top-banner · tone: kawaii-soft · scroll: none
import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../theme/moe_tokens.dart';
import '../motion/moe_motion.dart';
import '../motion/moe_pressable.dart';

/// 顶部轻量气泡通知（「TA 想你了」），替代原本阻塞操作的底部弹窗。
///
/// - 空白区域穿透点击，不打断浏览/输入；
/// - 点击气泡或「去聊聊」返回 `true`（引导切到 AI 伙伴 Tab）；
/// - 点击关闭、上滑或自动超时返回 `false`。
abstract final class CompanionAttentionSheet {
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;
  static Completer<bool?>? _activeCompleter;

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

  static Future<bool?> show(
    BuildContext context, {
    required String greeting,
    String? sourceLabel,
    Duration duration = const Duration(seconds: 5),
  }) {
    final body = greeting.trim();
    if (body.isEmpty) return Future<bool?>.value(false);

    dismiss(result: false);

    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      return Future<bool?>.value(false);
    }

    final completer = Completer<bool?>();
    _activeCompleter = completer;

    _entry = OverlayEntry(
      builder: (ctx) => _CompanionAttentionBubble(
        greeting: body,
        sourceLabel: sourceLabel?.trim(),
        duration: duration,
        onTap: () => dismiss(result: true),
        onClose: () => dismiss(result: false),
      ),
    );

    overlay.insert(_entry!);

    _dismissTimer = Timer(duration, () {
      dismiss(result: false);
    });

    return completer.future;
  }

  static void dismiss({bool result = false}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
    final c = _activeCompleter;
    _activeCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(result);
    }
  }
}

class _CompanionAttentionBubble extends StatefulWidget {
  const _CompanionAttentionBubble({
    required this.greeting,
    required this.duration,
    required this.onTap,
    required this.onClose,
    this.sourceLabel,
  });

  final String greeting;
  final String? sourceLabel;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_CompanionAttentionBubble> createState() =>
      _CompanionAttentionBubbleState();
}

class _CompanionAttentionBubbleState extends State<_CompanionAttentionBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MoeTokens.motionMedium,
      reverseDuration: MoeTokens.motionFast,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOut(VoidCallback after) async {
    if (!mounted) {
      after();
      return;
    }
    if (!moeReduceMotion(context)) {
      try {
        await _controller.reverse();
      } catch (_) {}
    }
    after();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = moeReduceMotion(context);
    final label = (widget.sourceLabel != null && widget.sourceLabel!.isNotEmpty)
        ? 'TA 想你了 · ${widget.sourceLabel}'
        : 'TA 想你了';

    final card = Dismissible(
      key: const ValueKey('companion_attention_bubble'),
      direction: DismissDirection.up,
      onDismissed: (_) => widget.onClose(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceLg,
            MoeTokens.spaceSm,
            MoeTokens.spaceLg,
            0,
          ),
          child: MoePressable(
            onTap: () => unawaited(_animateOut(widget.onTap)),
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: MoeTokens.surface1.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                border: Border.all(
                  color: MoeTokens.primary.withValues(alpha: 0.22),
                ),
                boxShadow: MoeTokens.shadowMd(),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: MoeTokens.primaryGradient,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: MoeTokens.textXs,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.greeting,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: MoeTokens.textBase,
                            fontWeight: FontWeight.w600,
                            color: MoeTokens.titleText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MoeTokens.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: const Text(
                      '去聊聊',
                      style: TextStyle(
                        fontSize: MoeTokens.textXs,
                        fontWeight: FontWeight.w800,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => unawaited(_animateOut(widget.onClose)),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(ignoring: true, child: SizedBox.expand()),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.topCenter,
                child: reduce
                    ? card
                    : FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(position: _slide, child: card),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
