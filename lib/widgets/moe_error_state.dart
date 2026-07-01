import 'package:flutter/material.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import '../utils/moe_error_copy.dart';
import 'custom_button.dart';
import 'fade_in_up.dart';

/// 统一错误态 UI（卡片 / 简洁两种布局）。
class MoeErrorState extends StatelessWidget {
  const MoeErrorState({
    super.key,
    required this.presentation,
    required this.onRetry,
    this.variant = MoeErrorVariant.card,
    this.padding,
    this.animate = true,
  });

  final MoeErrorPresentation presentation;
  final VoidCallback onRetry;
  final MoeErrorVariant variant;
  final EdgeInsetsGeometry? padding;

  /// 是否包裹入场动画（默认 true）。
  final bool animate;

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
    final content = switch (variant) {
        MoeErrorVariant.card => _buildCard(context),
        MoeErrorVariant.plain => _buildPlain(context),
      };
    return animate ? FadeInUp(child: content) : content;
  }

  Widget _buildCard(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: MoeTokens.space2xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          MoeTokens.spaceXl,
          MoeTokens.space2xl,
          MoeTokens.spaceXl,
          MoeTokens.spaceXl,
        ),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusCardLarge),
          boxShadow: MoeTokens.shadowMd(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBadge(moe, size: 74, iconSize: 38),
            SizedBox(height: MoeTokens.spaceLg),
            _title(),
            SizedBox(height: MoeTokens.spaceSm),
            _subtitle(),
            SizedBox(height: MoeTokens.spaceLg + MoeTokens.spaceXs),
            _primaryButton(moe),
          ],
        ),
      ),
    );
  }

  Widget _buildPlain(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.all(MoeTokens.space2xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBadge(moe, size: 64, iconSize: 32),
          SizedBox(height: MoeTokens.spaceMd + MoeTokens.spaceXs),
          _title(),
          SizedBox(height: MoeTokens.spaceSm),
          _subtitle(),
          SizedBox(height: MoeTokens.spaceLg),
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
        fontSize: MoeTokens.textLg,
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
        fontSize: MoeTokens.textBase,
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
