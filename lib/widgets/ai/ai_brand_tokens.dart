import 'package:flutter/material.dart';

/// AI 模块与「AI 酒馆」列表页一致的视觉 token。
abstract final class AiBrandTokens {
  static const pageBackground = Color(0xFFF3F5FB);
  static const chatBackground = Color(0xFFF5F7FA);
  static const primary = Color(0xFF7F7FD5);
  static const secondary = Color(0xFF86A8E7);
  static const accent = Color(0xFF91EAE4);
  static const gradientPink = Color(0xFF8A2387);
  static const gradientCoral = Color(0xFFE94057);
  static const titleColor = Color(0xFF1F2430);

  static const userBubbleGradient = LinearGradient(
    colors: [gradientPink, gradientCoral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent],
  );

  static const identityGradient = LinearGradient(
    colors: [Color(0x1A8A2387), Color(0x14E94057)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
