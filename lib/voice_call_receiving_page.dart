import 'package:flutter/material.dart';
import 'voice_call_page.dart';
import '../services/api_service.dart';

class VoiceCallReceivingPage extends StatelessWidget {
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String callId;

  const VoiceCallReceivingPage({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.callId,
  });

  Future<void> _answerCall(BuildContext context) async {
    try {
      // 调用后端API接听呼叫
      await ApiService.answerCall(callId);
      
      // 跳转到通话页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallPage(
            channelName: callId,
            userName: callerName,
            userAvatar: callerAvatar,
          ),
        ),
      );
    } catch (e) {
      _showError(context, '接听呼叫失败: $e');
    }
  }

  Future<void> _rejectCall(BuildContext context) async {
    try {
      // 调用后端API拒绝呼叫
      await ApiService.rejectCall(callId);
      Navigator.pop(context);
    } catch (e) {
      _showError(context, '拒绝呼叫失败: $e');
      Navigator.pop(context);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '来电',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Text(
            callerName,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 100,
            backgroundImage: NetworkImage(callerAvatar),
            onBackgroundImageError: (_, __) {},
            child: callerAvatar.isEmpty
                ? const Icon(Icons.person, size: 100, color: Colors.white)
                : null,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () => _rejectCall(context),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                ),
              ),
              GestureDetector(
                onTap: () => _answerCall(context),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
