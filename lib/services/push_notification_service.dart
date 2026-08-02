import 'package:flutter/material.dart';
import '../pages/chat/voice_call_receiving_page.dart';
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

  static void _handleMessage(Map<String, dynamic> data) {
    if (data['type'] == 'incoming_call') {
      final callerId = data['caller_id'];
      final callerName = data['caller_name'];
      final callerAvatar = data['caller_avatar'];
      final callId = data['call_id'];

      if (callerId != null && callerName != null && callId != null) {
        // 导航到来电页面
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => VoiceCallReceivingPage(
              callerId: callerId,
              callerName: callerName,
              callerAvatar: callerAvatar ?? '',
              callId: callId,
              channelName: data['channel_name']?.toString() ?? callId,
            ),
          ),
        );
      }
    }
  }

  // 处理来自WebSocket的通知
  static void handleWebSocketNotification(Map<String, dynamic> data) {
    EnhancedLogger().debug(
      '收到 WebSocket 通知',
      category: LogCategory.network,
      metadata: {'type': data['type']?.toString() ?? 'unknown'},
    );
    _handleMessage(data);
  }

  static Future<String> getToken() async {
    EnhancedLogger().debug('获取 WebSocket 推送令牌', category: LogCategory.network);
    // 在WebSocket模式下，我们不需要Firebase token
    return 'websocket_token';
  }

  // 模拟接收到来电通知
  static void simulateIncomingCall(
      String callerId, String callerName, String callerAvatar, String callId) {
    EnhancedLogger().debug('模拟收到来电通知', category: LogCategory.network);
    _handleMessage({
      'type': 'incoming_call',
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar': callerAvatar,
      'call_id': callId,
    });
  }
}
