import 'package:flutter/material.dart';
import 'package:moe_social/services/post_service.dart';
import 'package:moe_social/widgets/moe_like_action_button.dart';
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

class _LikeButtonState extends State<LikeButton> {
  late bool _isLiked = widget.isLiked;
  late int _likeCount = widget.likeCount;
  bool _isLoading = false;

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
    return MoeLikeActionButton(
      isLiked: _isLiked,
      likeCount: _likeCount,
      onPressed: _isLoading ? null : _toggleLike,
    );
  }
}
