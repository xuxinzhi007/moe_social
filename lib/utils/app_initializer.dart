import 'package:flutter/material.dart';
import 'package:moe_social/utils/svg_gift_manager.dart';

/// 应用初始化类
class AppInitializer {
  /// 初始化应用资源
  static Future<void> initialize() async {
    try {
      // 预加载SVG礼物资源
      await SvgGiftManager.preloadAll();
      print('SVG礼物资源预加载完成');
    } catch (e) {
      print('SVG礼物资源预加载失败: $e');
    }
  }
}
