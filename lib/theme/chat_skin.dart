import 'package:flutter/material.dart';

import 'moe_tokens.dart';

/// 聊天主题皮肤的深色变体覆写（仅记录与浅色不同的部分）。
@immutable
class ChatSkinDark {
  const ChatSkinDark({
    required this.chatBackground,
    required this.bubblePeerColor,
    required this.bubblePeerBorder,
  });

  /// 深色模式下的聊天页背景色。
  final Color chatBackground;

  /// 深色模式下的对方气泡底色。
  final Color bubblePeerColor;

  /// 深色模式下的对方气泡描边。
  final Color bubblePeerBorder;
}

/// 一套聊天主题皮肤（immutable）。
///
/// 浅色字段为基准；[dark] 非空时提供深色模式覆写，
/// 通过 [backgroundFor] / [peerColorFor] / [peerBorderFor] 按亮度取值。
@immutable
class ChatSkin {
  const ChatSkin({
    required this.id,
    required this.name,
    required this.chatBackground,
    required this.bubbleMeGradient,
    required this.bubblePeerColor,
    required this.bubblePeerBorder,
    this.dark,
    this.isDarkSkin = false,
  });

  /// 皮肤唯一标识（持久化用）。
  final String id;

  /// 皮肤中文名。
  final String name;

  /// 聊天页背景色。
  final Color chatBackground;

  /// 我方气泡渐变。
  final LinearGradient bubbleMeGradient;

  /// 对方气泡底色。
  final Color bubblePeerColor;

  /// 对方气泡描边。
  final Color bubblePeerBorder;

  /// 深色变体覆写；null 表示深浅色共用同一套配色。
  final ChatSkinDark? dark;

  /// 本身即深色皮肤（如「暗夜」），不随系统亮度切换。
  final bool isDarkSkin;

  Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark && dark != null && !isDarkSkin
          ? dark!.chatBackground
          : chatBackground;

  Color peerColorFor(Brightness brightness) =>
      brightness == Brightness.dark && dark != null && !isDarkSkin
          ? dark!.bubblePeerColor
          : bubblePeerColor;

  Color peerBorderFor(Brightness brightness) =>
      brightness == Brightness.dark && dark != null && !isDarkSkin
          ? dark!.bubblePeerBorder
          : bubblePeerBorder;

  @override
  bool operator ==(Object other) => other is ChatSkin && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 预设聊天皮肤集合。
abstract final class ChatSkins {
  /// 薰衣草 — 默认皮肤：跟随 Moe 主色体系。
  static const ChatSkin lavender = ChatSkin(
    id: 'lavender',
    name: '薰衣草',
    chatBackground: MoeTokens.pageBackground,
    bubbleMeGradient: LinearGradient(
      colors: [MoeTokens.primary, MoeTokens.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    bubblePeerColor: Colors.white,
    bubblePeerBorder: Color(0x337F7FD5),
    dark: ChatSkinDark(
      chatBackground: Color(0xFF20203A),
      bubblePeerColor: Color(0xFF32324F),
      bubblePeerBorder: Color(0x33FFFFFF),
    ),
  );

  /// 蜜桃 — 暖粉甜系。
  static const ChatSkin peach = ChatSkin(
    id: 'peach',
    name: '蜜桃',
    chatBackground: Color(0xFFFBF4F4),
    bubbleMeGradient: LinearGradient(
      colors: [Color(0xFFD9899A), Color(0xFFE8C4BC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    bubblePeerColor: Colors.white,
    bubblePeerBorder: Color(0x33D9899A),
    dark: ChatSkinDark(
      chatBackground: Color(0xFF2B2024),
      bubblePeerColor: Color(0xFF3D2C30),
      bubblePeerBorder: Color(0x1FFFFFFF),
    ),
  );

  /// 深海 — 蓝紫冷调。
  static const ChatSkin ocean = ChatSkin(
    id: 'ocean',
    name: '深海',
    chatBackground: Color(0xFFF3F6FC),
    bubbleMeGradient: LinearGradient(
      colors: [MoeTokens.primary, MoeTokens.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    bubblePeerColor: Colors.white,
    bubblePeerBorder: Color(0x33667EEA),
    dark: ChatSkinDark(
      chatBackground: Color(0xFF1A2035),
      bubblePeerColor: Color(0xFF273049),
      bubblePeerBorder: Color(0x1FFFFFFF),
    ),
  );

  /// 薄荷 — 清爽绿调。
  static const ChatSkin mint = ChatSkin(
    id: 'mint',
    name: '薄荷',
    chatBackground: Color(0xFFF3F8F6),
    bubbleMeGradient: LinearGradient(
      colors: [MoeTokens.pastelTeal, MoeTokens.accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    bubblePeerColor: Colors.white,
    bubblePeerBorder: Color(0x334ECDC4),
    dark: ChatSkinDark(
      chatBackground: Color(0xFF1B2B22),
      bubblePeerColor: Color(0xFF27392E),
      bubblePeerBorder: Color(0x1FFFFFFF),
    ),
  );

  /// 暗夜 — 原生深色皮肤。
  static const ChatSkin night = ChatSkin(
    id: 'night',
    name: '暗夜',
    chatBackground: Color(0xFF1A1A2E),
    bubbleMeGradient: LinearGradient(
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    bubblePeerColor: Color(0xFF2D2D44),
    bubblePeerBorder: Color(0x33FFFFFF),
    isDarkSkin: true,
  );

  /// 全部预设皮肤（顺序即展示顺序，薰衣草为首项/默认）。
  static const List<ChatSkin> all = [lavender, peach, ocean, mint, night];

  /// 按 id 查找皮肤；未命中返回 null。
  static ChatSkin? byId(String id) {
    for (final skin in all) {
      if (skin.id == id) return skin;
    }
    return null;
  }
}
