import 'package:flutter/material.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import 'custom_button.dart';
import 'motion/moe_reveal.dart';

class MoeEmptyStateAction {
  const MoeEmptyStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// 全局空态 / 错误态占位（图标或插图 + 文案 + 可选 CTA）。
///
/// 支持两种插图方式：
/// - [icon]（默认圆形渐变背景 + IconData）
/// - [image]（自定义 Widget，如 Image.asset / Lottie 等）
class MoeEmptyState extends StatelessWidget {
  const MoeEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.image,
    this.primaryAction,
    this.secondaryAction,
    this.compact = false,
    this.showCard = true,
    this.animate = true,
  });

  /// 未登录引导空态：统一的「去登录」入口 + 功能说明。
  ///
  /// [featureDescription] 描述登录后可用的功能，如「签到领奖励」「查看好友」等。
  /// [context] 用于获取主题和执行导航。
  factory MoeEmptyState.requireLogin({
    required BuildContext context,
    required String featureDescription,
    bool compact = false,
  }) {
    return MoeEmptyState(
      title: '请先登录',
      subtitle: featureDescription,
      icon: Icons.lock_outline_rounded,
      compact: compact,
      showCard: true,
      animate: true,
      primaryAction: MoeEmptyStateAction(
        label: '去登录',
        onPressed: () {
          Navigator.pushNamed(context, '/login');
        },
      ),
    );
  }

  final String title;
  final String? subtitle;
  final IconData icon;

  /// 自定义插图 Widget，优先级高于 [icon]。
  final Widget? image;

  final MoeEmptyStateAction? primaryAction;
  final MoeEmptyStateAction? secondaryAction;
  final bool compact;

  /// 是否显示圆角卡片背景（默认 true）。
  final bool showCard;

  /// 是否包裹入场动画（默认 true）。
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);

    Widget content;
    if (!showCard) {
      content = _buildContent(moe, inCard: false);
    } else {
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? MoeTokens.spaceLg : MoeTokens.space2xl,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: MoeTokens.space2xl,
            vertical: compact ? MoeTokens.spaceLg : MoeTokens.space3xl,
          ),
          decoration: BoxDecoration(
            color: MoeTokens.cardBackground,
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            border: Border.all(color: MoeTokens.surfaceBorder, width: 1),
            boxShadow: MoeTokens.shadowCard(),
          ),
          child: _buildContent(moe, inCard: true),
        ),
      );
    }
    return animate ? MoeReveal(child: content) : content;
  }

  Widget _buildContent(MoeTheme moe, {required bool inCard}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIllustration(moe),
        SizedBox(height: compact ? MoeTokens.spaceMd : MoeTokens.spaceXl),
        _buildTitle(),
        if (subtitle != null) ...[
          SizedBox(height: MoeTokens.spaceSm),
          _buildSubtitle(),
        ],
        if (primaryAction != null) ...[
          SizedBox(height: compact ? MoeTokens.spaceLg : MoeTokens.space2xl),
          CustomButton(
            text: primaryAction!.label,
            onPressed: primaryAction!.onPressed,
            backgroundColor: moe.primary,
            width: 200,
            elevation: 0,
          ),
        ],
        if (secondaryAction != null) ...[
          SizedBox(height: MoeTokens.spaceMd),
          TextButton.icon(
            onPressed: secondaryAction!.onPressed,
            icon: Icon(secondaryAction!.icon ?? Icons.arrow_forward_rounded),
            label: Text(secondaryAction!.label),
          ),
        ],
      ],
    );
  }

  Widget _buildIllustration(MoeTheme moe) {
    if (image != null) {
      return SizedBox(
        width: compact ? 80 : 120,
        height: compact ? 80 : 120,
        child: image,
      );
    }
    return Container(
      width: compact ? 64 : 88,
      height: compact ? 64 : 88,
      decoration: BoxDecoration(
        gradient: MoeTokens.gradientSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: compact ? 30 : 40,
        color: moe.primary,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: compact ? MoeTokens.textMd : MoeTokens.textLg,
        fontWeight: MoeTokens.fontWeightSubtitle,
        color: MoeTokens.titleText,
        height: 1.4,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      subtitle!,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: MoeTokens.textBase,
        color: MoeTokens.hintText,
        height: 1.5,
      ),
    );
  }
}
