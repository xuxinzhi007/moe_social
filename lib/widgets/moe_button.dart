import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import 'moe_loading.dart';
import 'motion/moe_pressable.dart';

/// 统一精致主按钮（带微按压缩放、加载态与克制圆角阴影）。
class MoePrimaryButton extends StatelessWidget {
  const MoePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height = 46,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double height;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    final enabled = onPressed != null && !isLoading;
    final bgColor = isDestructive ? MoeTokens.danger : moe.primary;

    final button = MoePressable(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            }
          : null,
      borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      child: AnimatedContainer(
        duration: MoeTokens.motionFast,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceXl),
        decoration: BoxDecoration(
          color: enabled ? bgColor : MoeTokens.softChipBg,
          borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
          boxShadow: enabled ? MoeTokens.shadowSm() : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const MoeSmallLoading(color: Colors.white, size: 18)
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: enabled ? Colors.white : MoeTokens.hintText,
                    ),
                    const SizedBox(width: MoeTokens.spaceSm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? Colors.white : MoeTokens.hintText,
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// 统一精致次级描边按钮（1px 极细冷灰边框 + 纯白/浅灰底）。
class MoeSecondaryButton extends StatelessWidget {
  const MoeSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.height = 42,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final button = MoePressable(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed?.call();
            }
          : null,
      borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
        decoration: BoxDecoration(
          color: MoeTokens.surface1,
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          border: Border.all(color: MoeTokens.surfaceBorder),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: enabled ? MoeTokens.titleText : MoeTokens.hintText,
              ),
              const SizedBox(width: MoeTokens.spaceXs + 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? MoeTokens.titleText : MoeTokens.hintText,
                  fontSize: MoeTokens.textBase,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
