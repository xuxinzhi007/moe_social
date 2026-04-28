import 'package:flutter/material.dart';
import 'package:moe_social/services/post_service.dart';
import 'package:moe_social/widgets/moe_toast.dart';

class LikeButton extends StatefulWidget {
  final String postId;
  final String userId;
  final bool isLiked;
  final int likeCount;
  final Function(bool, int)? onLikeChanged;

  const LikeButton({
    Key? key,
    required this.postId,
    required this.userId,
    required this.isLiked,
    required this.likeCount,
    this.onLikeChanged,
  }) : super(key: key);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked != widget.isLiked) {
      _isLiked = widget.isLiked;
    }
    if (oldWidget.likeCount != widget.likeCount) {
      _likeCount = widget.likeCount;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });
    try {
      final updatedPost = await PostService.toggleLike(widget.postId, widget.userId);
      // LikeStateManager 已由 PostService 更新，本地跟服务端对齐
      setState(() {
        _isLiked = updatedPost.isLiked;
        _likeCount = updatedPost.likes;
      });
      if (_isLiked) {
        _animationController.forward().then((_) => _animationController.reverse());
      }
      widget.onLikeChanged?.call(_isLiked, _likeCount);
    } catch (e) {
      MoeToast.show(context, '操作失败，请稍后重试');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoeBouncingButton(
      onTap: _toggleLike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _opacityAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? const Color(0xFFFF4757) : Colors.grey[500],
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: Text(
              _likeCount.toString(),
              key: ValueKey<int>(_likeCount),
              style: TextStyle(
                color: _isLiked ? const Color(0xFFFF4757) : Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF4757),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MoeBouncingButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final Duration duration;

  const MoeBouncingButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.9,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => _animateTap(context, scaleFactor),
      onTapUp: (_) => _animateTap(context, 1.0),
      onTapCancel: () => _animateTap(context, 1.0),
      child: child,
    );
  }

  void _animateTap(BuildContext context, double scale) {
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject != null) {
      renderObject.markNeedsPaint();
    }
  }
}
