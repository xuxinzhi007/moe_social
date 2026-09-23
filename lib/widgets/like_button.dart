import 'package:flutter/material.dart';
import 'package:moe_social/services/post_service.dart';
import 'package:moe_social/theme/moe_tokens.dart';
import 'package:moe_social/widgets/motion/moe_motion.dart';
import 'package:moe_social/widgets/motion/moe_pressable.dart';
import 'package:moe_social/widgets/moe_toast.dart';

class LikeButton extends StatefulWidget {
  final String postId;
  final String userId;
  final bool isLiked;
  final int likeCount;
  final Function(bool, int)? onLikeChanged;

  const LikeButton({
    super.key,
    required this.postId,
    required this.userId,
    required this.isLiked,
    required this.likeCount,
    this.onLikeChanged,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  int _countDirection = 1;
  bool _isLoading = false;
  bool _animateLike = false;
  late final AnimationController _animationController;
  late final Animation<double> _likeScaleAnimation;
  late final Animation<double> _unlikeScaleAnimation;
  late final Animation<double> _ringScaleAnimation;
  late final Animation<double> _ringOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;

    _animationController = AnimationController(
      vsync: this,
      duration: MoeTokens.motionSlow,
    );
    _likeScaleAnimation = TweenSequence<double>([
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
    ]).animate(_animationController);
    _unlikeScaleAnimation = TweenSequence<double>([
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
    ]).animate(_animationController);
    _ringScaleAnimation = Tween<double>(begin: 0.65, end: 1.65).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _ringOpacityAnimation = Tween<double>(begin: 0.34, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) {
      _isLiked = widget.isLiked;
    }
    if (oldWidget.likeCount != widget.likeCount) {
      _countDirection = widget.likeCount > oldWidget.likeCount ? 1 : -1;
      _likeCount = widget.likeCount;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playAnimation(bool liked) {
    if (moeReduceMotion(context)) return;
    _animateLike = liked;
    _animationController.forward(from: 0);
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    _playAnimation(!_isLiked);
    setState(() => _isLoading = true);
    try {
      final updatedPost =
          await PostService.toggleLike(widget.postId, widget.userId);
      if (!mounted) return;
      setState(() {
        _isLiked = updatedPost.isLiked;
        _likeCount = updatedPost.likes;
      });
      widget.onLikeChanged?.call(_isLiked, _likeCount);
    } catch (e) {
      if (mounted) MoeToast.show(context, '操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    final motionDuration = reduceMotion ? Duration.zero : MoeTokens.motionFast;

    return Semantics(
      button: true,
      label: _isLiked ? '取消点赞' : '点赞',
      value: '$_likeCount',
      onTap: _isLoading ? null : _toggleLike,
      child: ExcludeSemantics(
        child: MoePressable(
          onTap: _toggleLike,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final scale = reduceMotion
                        ? 1.0
                        : (_animateLike
                            ? _likeScaleAnimation.value
                            : _unlikeScaleAnimation.value);

                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (!reduceMotion && _animateLike)
                          Opacity(
                            opacity: _ringOpacityAnimation.value,
                            child: Transform.scale(
                              scale: _ringScaleAnimation.value,
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: MoeTokens.pastelPink
                                        .withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        AnimatedContainer(
                          duration: motionDuration,
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLiked
                                ? MoeTokens.pastelPink.withValues(alpha: 0.14)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Transform.scale(
                              scale: scale,
                              child: AnimatedSwitcher(
                                duration: motionDuration,
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
                                  _isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey<bool>(_isLiked),
                                  color: _isLiked
                                      ? MoeTokens.pastelPink
                                      : MoeTokens.inkMuted
                                          .withValues(alpha: 0.78),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isLoading)
                          Positioned(
                            top: 1,
                            right: 1,
                            child: SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: MoeTokens.pastelPink,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: MoeTokens.spaceXs),
              Flexible(
                child: AnimatedSwitcher(
                  duration: motionDuration,
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
                        child: SlideTransition(position: offset, child: child),
                      ),
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _likeCount.toString(),
                      key: ValueKey<int>(_likeCount),
                      style: TextStyle(
                        color: _isLiked
                            ? MoeTokens.pastelPink
                            : MoeTokens.inkMuted.withValues(alpha: 0.82),
                        fontSize: MoeTokens.textBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
