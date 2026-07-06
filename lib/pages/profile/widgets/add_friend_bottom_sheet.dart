import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth_service.dart';
import '../../../services/api_service.dart';
import '../../../theme/moe_theme_extension.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/motion/moe_pressable.dart';
import '../../../widgets/motion/moe_reveal.dart';

class AddFriendBottomSheet extends StatefulWidget {
  const AddFriendBottomSheet({
    super.key,
    required this.rootContext,
    required this.myMoe,
    required this.onReloadFriends,
  });

  final BuildContext rootContext;
  final String myMoe;
  final VoidCallback onReloadFriends;

  @override
  State<AddFriendBottomSheet> createState() => _AddFriendBottomSheetState();
}

class _AddFriendBottomSheetState extends State<AddFriendBottomSheet> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyLine(BuildContext ctx, String text, String toast) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (ctx.mounted) {
      MoeToast.success(ctx, toast);
    }
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = '请输入邮箱或 Moe 号');
      return;
    }

    final currentUserId = AuthService.currentUser;
    if (currentUserId == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (widget.rootContext.mounted) {
        MoeToast.error(widget.rootContext, '请先登录');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (raw.contains('@')) {
        final targetUser = await ApiService.checkUserByEmail(raw);
        if (targetUser.id == currentUserId) {
          setState(() {
            _isLoading = false;
            _error = '不能添加自己为好友';
          });
          return;
        }
        final relation = await ApiService.getFriendRelation(
          currentUserId,
          targetUser.id,
        );
        if (relation == 'friend') {
          setState(() {
            _isLoading = false;
            _error = '你们已经是好友了';
          });
          return;
        }
        if (relation == 'pending_out') {
          setState(() {
            _isLoading = false;
            _error = '好友申请已发送，请等待对方确认';
          });
          return;
        }
        if (relation == 'pending_in') {
          setState(() {
            _isLoading = false;
            _error = '对方已经向你发送申请，请在申请列表中处理';
          });
          return;
        }
        await ApiService.sendFriendRequestByUserId(currentUserId, targetUser.id);
      } else if (RegExp(r'^\d{10}$').hasMatch(raw)) {
        await ApiService.sendFriendRequestByMoeNo(currentUserId, raw);
      } else {
        setState(() {
          _isLoading = false;
          _error = '请输入有效邮箱或 10 位 Moe 号';
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.rootContext.mounted) {
        MoeToast.success(widget.rootContext, '好友申请已发送');
        widget.onReloadFriends();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myMoe = widget.myMoe;
    final moe = MoeTheme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoeReveal(
            child: Text(
              '添加好友',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          MoeReveal(
            delay: const Duration(milliseconds: 40),
            child: Text(
              '输入对方注册邮箱或 10 位 Moe 号，我们会向对方发送好友申请。',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 20),
          MoeReveal(
            delay: const Duration(milliseconds: 80),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isLoading) {
                  _submit();
                }
              },
              decoration: InputDecoration(
                labelText: '邮箱或 Moe 号',
                hintText: '例如 name@example.com 或 1234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            MoeReveal(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (myMoe.isNotEmpty) ...[
            MoeReveal(
              delay: const Duration(milliseconds: 120),
              child: Text(
                '我的 Moe 号（可复制发给对方）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 8),
            MoeReveal(
              delay: const Duration(milliseconds: 160),
              child: MoePressable(
                onTap: () => _copyLine(context, myMoe, '已复制我的 Moe 号'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: moe.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          myMoe,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: moe.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          MoeReveal(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: moe.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('发送申请'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
