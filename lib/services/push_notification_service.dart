import 'package:flutter/material.dart';
import '../pages/chat/voice_call_receiving_page.dart';

class PushNotificationService {
  static late GlobalKey<NavigatorState> navigatorKey;

  static Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    print('推送通知服务初始化 - WebSocket模式');
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
            ),
          ),
        );
      }
    }
  }

  // 处理来自WebSocket的通知
  static void handleWebSocketNotification(Map<String, dynamic> data) {
    print('处理WebSocket推送通知: ${data['type']}');
    _handleMessage(data);
  }

  static Future<String> getToken() async {
    print('获取推送令牌 - WebSocket模式');
    // 在WebSocket模式下，我们不需要Firebase token
    return 'websocket_token';
  }

  // 模拟接收到来电通知
  static void simulateIncomingCall(String callerId, String callerName, String callerAvatar, String callId) {
    print('模拟收到来电通知');
    _handleMessage({
      'type': 'incoming_call',
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar': callerAvatar,
      'call_id': callId,
    });
  }
}
