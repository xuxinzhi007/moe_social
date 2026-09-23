import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_motion.dart';
import 'motion/moe_pressable.dart';

/// Shared post/comment like action with a compact variant for reply threads.
class MoeLikeActionButton extends StatefulWidget {
  const MoeLikeActionButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onPressed,
    this.compact = false,
    this.showCountWhenZero = true,
  });

  final bool isLiked;
  final int likeCount;
  final Future<void> Function()? onPressed;
  final bool compact;
  final bool showCountWhenZero;

  @override
  State<MoeLikeActionButton> createState() => _MoeLikeActionButtonState();
}

class _MoeLikeActionButtonState extends State<MoeLikeActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _likeScale;
  late final Animation<double> _unlikeScale;
  bool _actionPending = false;
  bool _animateLike = false;
  int _countDirection = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MoeTokens.motionSlow,
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.78)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.78, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 34,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 48,
      ),
    ]).animate(_controller);
    _unlikeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.82)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant MoeLikeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likeCount != widget.likeCount) {
      _countDirection = widget.likeCount > oldWidget.likeCount ? 1 : -1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final onPressed = widget.onPressed;
    if (_actionPending || onPressed == null) return;

    if (!moeReduceMotion(context)) {
      _animateLike = !widget.isLiked;
      _controller.forward(from: 0);
    }
    setState(() => _actionPending = true);
    try {
      await onPressed();
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final transitionDuration =
        reduceMotion ? Duration.zero : MoeTokens.motionFast;
    final enabled = widget.onPressed != null && !_actionPending;
    final onTap = enabled ? _activate : null;
    final areaSize = widget.compact ? 32.0 : 40.0;
    final circleSize = widget.compact ? 26.0 : 34.0;
    final heartSize = widget.compact ? 16.0 : 22.0;
    final showCount = widget.showCountWhenZero || widget.likeCount > 0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.isLiked ? '取消点赞' : '点赞',
      value: '${widget.likeCount}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: MoePressable(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: areaSize,
                height: areaSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final scale = reduceMotion
                        ? 1.0
                        : (_animateLike
                            ? _likeScale.value
                            : _unlikeScale.value);

                    return AnimatedContainer(
                      duration: transitionDuration,
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isLiked
                            ? MoeTokens.pastelPink.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: scale,
                          child: AnimatedSwitcher(
                            duration: transitionDuration,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              widget.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey<bool>(widget.isLiked),
                              color: widget.isLiked
                                  ? MoeTokens.pastelPink
                                  : MoeTokens.inkMuted.withValues(alpha: 0.78),
                              size: heartSize,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (showCount) ...[
                SizedBox(
                    width: widget.compact
                        ? MoeTokens.spaceXs / 2
                        : MoeTokens.spaceXs),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: transitionDuration,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: Offset(0, _countDirection > 0 ? 0.65 : -0.65),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                      return ClipRect(
                        child: FadeTransition(
                          opacity: animation,
                          child:
                              SlideTransition(position: offset, child: child),
                        ),
                      );
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.likeCount.toString(),
                        key: ValueKey<int>(widget.likeCount),
                        style: TextStyle(
                          color: widget.isLiked
                              ? MoeTokens.pastelPink
                              : MoeTokens.inkMuted.withValues(alpha: 0.82),
                          fontSize: widget.compact
                              ? MoeTokens.textSm
                              : MoeTokens.textBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
