// Hallmark · layout: bottom-sheet · tone: kawaii-soft · scroll: draggable
import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../custom_button.dart';
import '../motion/moe_sheet.dart';

/// 首页不再常驻「TA 想你了」卡片；仅在需要回应时弹出一次，引导到底栏已有入口。
abstract final class CompanionAttentionSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String greeting,
    String? sourceLabel,
  }) {
    final body = greeting.trim();
    if (body.isEmpty) return Future<bool?>.value(false);

    return MoeSheet.show<bool>(
      context,
      isScrollControlled: true,
      backgroundColor: MoeTokens.surface1,
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceXl,
        0,
        MoeTokens.spaceXl,
        MoeTokens.spaceLg,
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(MoeTokens.spaceMd),
                decoration: BoxDecoration(
                  color: MoeTokens.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: MoeTokens.primary,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              const Text(
                'TA 想你了',
                style: TextStyle(
                  fontSize: MoeTokens.textLg,
                  fontWeight: MoeTokens.fontWeightTitle,
                  color: MoeTokens.titleText,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceXs),
              if (sourceLabel != null && sourceLabel.trim().isNotEmpty) ...[
                Text(
                  sourceLabel.trim(),
                  style: const TextStyle(
                    fontSize: MoeTokens.textSm,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                    color: MoeTokens.primary,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  MoeTokens.spaceLg,
                  MoeTokens.spaceMd,
                  MoeTokens.spaceLg,
                  MoeTokens.spaceMd,
                ),
                decoration: BoxDecoration(
                  color: MoeTokens.softLavenderBg,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  border: Border.all(
                    color: MoeTokens.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: MoeTokens.textMd,
                    fontWeight: MoeTokens.fontWeightBody,
                    color: MoeTokens.caption,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: MoeTokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: '稍后再聊',
                      isOutline: true,
                      onPressed: () => Navigator.pop(sheetContext, false),
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceSm),
                  Expanded(
                    child: CustomButton(
                      text: '打开聊天',
                      onPressed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
