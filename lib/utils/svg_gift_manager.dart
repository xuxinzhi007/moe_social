import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG资源管理类
class SvgGiftManager {
  static final Map<String, String> _svgCache = {};
  static const String _basePath = 'assets/svg/';

  /// 预加载所有SVG资源
  static Future<void> preloadAll() async {
    final gifts = [
      'heart',
      'flower',
      'thumbsup',
      'clap',
      'hug',
      'coffee',
      'cake',
      'ice_cream',
      'wine',
      'diamond',
      'crown',
      'rocket',
      'rainbow',
      'fireworks',
      'unicorn',
    ];

    for (final giftId in gifts) {
      await loadSvg(giftId);
    }
  }

  /// 加载指定礼物的SVG
  static Future<String> loadSvg(String giftId) async {
    if (_svgCache.containsKey(giftId)) {
      return _svgCache[giftId]!;
    }

    try {
      final svgContent = await rootBundle.loadString('\$_basePath$giftId.svg');
      _svgCache[giftId] = svgContent;
      return svgContent;
    } catch (e) {
      print('Failed to load SVG for gift $giftId: $e');
      return '';
    }
  }

  /// 获取SVG内容
  static String? getSvg(String giftId) {
    return _svgCache[giftId];
  }

  /// 检查SVG是否已加载
  static bool isSvgLoaded(String giftId) {
    return _svgCache.containsKey(giftId);
  }

  /// 清除缓存
  static void clearCache() {
    _svgCache.clear();
  }
}
