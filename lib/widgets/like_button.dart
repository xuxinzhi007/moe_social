import 'package:flutter/material.dart';

// 带有弹性动画的点赞按钮
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50), // 放大
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50), // 恢复
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != _isLiked) {
      _isLiked = widget.isLiked;
      if (_isLiked) {
        _controller.forward().then((_) => _controller.reset());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onTap();
        if (!widget.isLiked) {
          _controller.forward().then((_) => _controller.reset());
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: widget.isLiked ? Colors.pinkAccent : Colors.grey[600],
                size: 22,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.likeCount}',
              style: TextStyle(
                color: widget.isLiked ? Colors.pinkAccent : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
