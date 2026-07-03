import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../ai/ai_brand_tokens.dart';
import '../moe_input_field.dart';

/// 游戏输入栏（输入框 + 发送按钮）
class GameInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const GameInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: MoeInputField(
                controller: controller,
                focusNode: focusNode,
                readOnly: isSending,
                style: TextStyle(
                  color: MoeTokens.caption,
                  fontSize: 15,
                ),
                hintText: '描述你的行动…',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                fillColor: Colors.transparent,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => onSend(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient:
                    isSending ? null : AiBrandTokens.heroGradient,
                color: isSending ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
              ),
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
