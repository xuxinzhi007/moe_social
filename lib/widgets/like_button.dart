import 'package:flutter/material.dart';
import 'package:moe_social/services/api_service.dart';
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

class _LikeButtonState extends State<LikeButton> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
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

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedPost = await ApiService.toggleLike(widget.postId, widget.userId);
      setState(() {
        _isLiked = updatedPost.isLiked;
        _likeCount = updatedPost.likes ?? 0;
      });
      widget.onLikeChanged?.call(_isLiked, _likeCount);
    } catch (e) {
      MoeToast.show(context, '操作失败，请稍后重试');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            _likeCount.toString(),
            style: TextStyle(
              color: _isLiked ? Colors.red : Colors.grey,
              fontSize: 16,
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
