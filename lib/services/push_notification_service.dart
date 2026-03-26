import 'package:flutter/material.dart';
import '../voice_call_receiving_page.dart';

class PushNotificationService {
  static late GlobalKey<NavigatorState> navigatorKey;

  static Future<void> initialize(GlobalKey<NavigatorState> key) async {
    navigatorKey = key;
    print('推送通知服务初始化 - 模拟模式');
    // 这里不使用Firebase，避免初始化失败导致应用崩溃
    // 实际使用时，需要在Firebase控制台创建项目并配置
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

  static Future<String> getToken() async {
    print('获取推送令牌 - 模拟模式');
    return 'mock_token';
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
