import 'package:flutter/material.dart';
import 'ai_brand_tokens.dart';

/// 聊天区域浅色装饰背景，与酒馆页 hero 光晕呼应。
class AiChatBackground extends StatelessWidget {
  const AiChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AiBrandTokens.chatBackground),
        Positioned(
          right: -40,
          top: -30,
          child: _glowOrb(
            160,
            AiBrandTokens.primary.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          left: -50,
          bottom: 120,
          child: _glowOrb(
            140,
            AiBrandTokens.secondary.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 80,
          child: _glowOrb(
            90,
            AiBrandTokens.accent.withValues(alpha: 0.06),
          ),
        ),
        child,
      ],
    );
  }

  Widget _glowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
