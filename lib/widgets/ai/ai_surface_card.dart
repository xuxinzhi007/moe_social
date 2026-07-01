import 'package:flutter/material.dart';

import 'ai_theme.dart';

class AiSurfaceCard extends StatelessWidget {
  const AiSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: AiTheme.sectionGap),
      padding: padding ?? const EdgeInsets.all(AiTheme.cardPadding),
      decoration: BoxDecoration(
        color: gradient == null ? AiTheme.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
        boxShadow: AiTheme.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
        child: content,
      ),
    );
  }
}
