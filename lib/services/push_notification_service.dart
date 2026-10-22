import 'package:flutter/material.dart';
import 'enhanced_logger.dart';
import 'push_delivery_capabilities.dart';

class PushNotificationService {
  static late GlobalKey<NavigatorState> navigatorKey;

  static const PushDeliveryCapabilities capabilities =
      PushDeliveryCapabilities.current;

  static Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    EnhancedLogger().info('推送通知服务已初始化', category: LogCategory.network);
    // 现在使用WebSocket接收推送通知
  }

  // 处理来自WebSocket的通知
  static void handleWebSocketNotification(Map<String, dynamic> data) {
    EnhancedLogger().debug(
      '收到 WebSocket 通知',
      category: LogCategory.network,
      metadata: {'type': data['type']?.toString() ?? 'unknown'},
    );
  }

  static Future<String> getToken() async {
    EnhancedLogger().debug('获取 WebSocket 推送令牌', category: LogCategory.network);
    // 在WebSocket模式下，我们不需要Firebase token
    return 'websocket_token';
  }
}
