import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 聊天画图风格配置（全局持久化 + 实时通知气泡卡片切换）。
///
/// 默认 `'anime'`（动漫二次元，匹配 MeinaMix 等底模与 CLIP Skip -2），
/// 可切换为 `'realistic'`（写实照片，匹配 Realistic_Vision 与 CLIP Skip -1）。
class ComfyDrawPreferences {
  ComfyDrawPreferences._();

  static const String _prefKey = 'companion_comfy_draw_style';
  static const String styleAnime = 'anime';
  static const String styleRealistic = 'realistic';

  /// 当前生效的画风（默认动漫 `'anime'`）。
  static final ValueNotifier<String> styleNotifier =
      ValueNotifier<String>(styleAnime);

  static String get currentStyle => styleNotifier.value;

  static String get currentStyleLabel =>
      styleNotifier.value == styleRealistic ? '写实' : '动漫';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey)?.trim().toLowerCase();
      if (saved == styleRealistic || saved == styleAnime) {
        styleNotifier.value = saved!;
      } else {
        styleNotifier.value = styleAnime;
      }
    } catch (_) {}
  }

  static Future<void> setStyle(String style) async {
    final normalized = style.trim().toLowerCase() == styleRealistic
        ? styleRealistic
        : styleAnime;
    if (styleNotifier.value != normalized) {
      styleNotifier.value = normalized;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, normalized);
    } catch (_) {}
  }

  static Future<String> toggleStyle() async {
    final next =
        styleNotifier.value == styleAnime ? styleRealistic : styleAnime;
    await setStyle(next);
    return next;
  }
}
