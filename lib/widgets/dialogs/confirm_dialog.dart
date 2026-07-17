import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../custom_button.dart';

/// 萌社交统一确认对话框 — 双层阴影 + 渐变确认按钮。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = '取消',
  String confirmText = '确定',
  bool isDestructive = false,
  bool barrierDismissible = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: MoeTokens.surface2,
            borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            border: Border.all(color: MoeTokens.surfaceBorder, width: 1),
            boxShadow: MoeTokens.shadowElevated(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                title,
                style: const TextStyle(
                  fontSize: MoeTokens.textLg,
                  fontWeight: MoeTokens.fontWeightTitle,
                  color: MoeTokens.titleText,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              // 内容
              Text(
                message,
                style: const TextStyle(
                  fontSize: MoeTokens.textBase,
                  color: MoeTokens.bodyText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MoeTokens.space2xl),
              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 44,
                child: CustomButton(
                  text: confirmText,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  backgroundColor:
                      isDestructive ? MoeTokens.danger : null,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              // 取消按钮
              SizedBox(
                width: double.infinity,
                height: 44,
                child: CustomButton(
                  text: cancelText,
                  onPressed: () => Navigator.pop(dialogContext, false),
                  isOutline: true,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}
