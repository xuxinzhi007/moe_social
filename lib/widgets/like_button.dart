import 'package:flutter/material.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/services/like_state_manager.dart';
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
  int _outstanding = 0;
  bool _syncing = false;

  Future<void> _toggleLike() async {
    if (widget.userId.isEmpty) {
      MoeToast.show(context, '请先登录');
      return;
    }
    LikeStateManager().toggleLike(widget.postId);
    _outstanding++;
    await _drain();
  }

  Future<void> _drain() async {
    if (_syncing) return;
    _syncing = true;
    final manager = LikeStateManager();
    while (mounted && _outstanding > 0) {
      try {
        final updated =
            await ApiService.toggleLike(widget.postId, widget.userId);
        if (!mounted) return;
        _outstanding--;
        if (_outstanding == 0) {
          manager.updateState(widget.postId, updated.isLiked, updated.likes);
          widget.onLikeChanged?.call(updated.isLiked, updated.likes);
        }
      } catch (_) {
        if (mounted) {
          manager.toggleLike(widget.postId);
          MoeToast.show(context, '操作失败，请稍后重试');
        }
        _outstanding = 0;
        break;
      }
    }
    _syncing = false;
    if (_outstanding > 0 && mounted) {
      await _drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoeLikeActionButton(
      isLiked: widget.isLiked,
      likeCount: widget.likeCount,
      onPressed: _toggleLike,
    );
  }
}
