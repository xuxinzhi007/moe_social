import 'package:flutter/material.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import '../utils/moe_error_copy.dart';
import 'custom_button.dart';

/// 统一错误态 UI（卡片 / 简洁两种布局）。
class MoeErrorState extends StatelessWidget {
  const MoeErrorState({
    super.key,
    required this.presentation,
    required this.onRetry,
    this.variant = MoeErrorVariant.card,
    this.padding,
  });

  final MoeErrorPresentation presentation;
  final VoidCallback onRetry;
  final MoeErrorVariant variant;
  final EdgeInsetsGeometry? padding;

  /// 从异常直接构建。
  factory MoeErrorState.fromError(
    Object? error, {
    required VoidCallback onRetry,
    MoeErrorScene scene = MoeErrorScene.generic,
    MoeErrorVariant variant = MoeErrorVariant.card,
    EdgeInsetsGeometry? padding,
  }) {
    return MoeErrorState(
      presentation: MoeErrorCopy.resolve(error, scene: scene),
      onRetry: onRetry,
      variant: variant,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      MoeErrorVariant.card => _buildCard(context),
      MoeErrorVariant.plain => _buildPlain(context),
    };
  }

  Widget _buildCard(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusCardLarge),
          boxShadow: MoeTokens.cardShadow(tint: moe.primary, blur: 18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBadge(moe, size: 74, iconSize: 38),
            const SizedBox(height: 16),
            _title(),
            const SizedBox(height: 8),
            _subtitle(),
            const SizedBox(height: 18),
            _primaryButton(moe),
          ],
        ),
      ),
    );
  }

  Widget _buildPlain(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBadge(moe, size: 64, iconSize: 32),
          const SizedBox(height: 14),
          _title(),
          const SizedBox(height: 8),
          _subtitle(),
          const SizedBox(height: 16),
          _primaryButton(moe),
        ],
      ),
    );
  }

  Widget _iconBadge(MoeTheme moe,
      {required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            moe.primary.withValues(alpha: 0.18),
            moe.secondary.withValues(alpha: 0.14),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        presentation.icon,
        size: iconSize,
        color: moe.primary,
      ),
    );
  }

  Widget _title() {
    return Text(
      presentation.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: MoeTokens.titleText,
        height: 1.35,
      ),
    );
  }

  Widget _subtitle() {
    return Text(
      presentation.subtitle,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: MoeTokens.hintText,
        fontSize: 14,
        height: 1.45,
      ),
    );
  }

  Widget _primaryButton(MoeTheme moe) {
    return CustomButton(
      text: presentation.actionLabel,
      onPressed: onRetry,
      backgroundColor: moe.primary,
      width: 200,
      elevation: 0,
    );
  }
}

enum MoeErrorVariant {
  card,
  plain,
}
