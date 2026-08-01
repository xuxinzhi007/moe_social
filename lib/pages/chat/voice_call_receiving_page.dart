import 'package:flutter/material.dart';
import 'voice_call_launcher.dart';
import '../../services/chat_service.dart';
import '../../services/chat_push_service.dart';
import '../../utils/media_url.dart';
import '../../widgets/moe_toast.dart';

class VoiceCallReceivingPage extends StatelessWidget {
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String callId;
  final String channelName;

  const VoiceCallReceivingPage({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.callId,
    required this.channelName,
  });

  Future<void> _answerCall(BuildContext context) async {
    try {
      // 调用后端API接听呼叫
      await ChatService.answerCall(callId);
      if (!context.mounted) return;

      // 跳转到通话页面
      ChatPushService.clearActiveIncomingCall();
      await replaceWithVoiceCallPage(
        context,
        channelName: channelName,
        userName: callerName,
        userAvatar: callerAvatar,
      );
    } catch (e) {
      if (context.mounted) _showError(context, '接听呼叫失败: $e');
    }
  }

  Future<void> _rejectCall(BuildContext context) async {
    try {
      // 调用后端API拒绝呼叫
      await ChatService.rejectCall(callId);
      ChatPushService.clearActiveIncomingCall();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) _showError(context, '拒绝呼叫失败: $e');
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) MoeToast.error(context, message);
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
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 100,
            backgroundImage: callerAvatar.isNotEmpty
                ? NetworkImage(resolveMediaUrl(callerAvatar))
                : null,
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
                  child:
                      const Icon(Icons.call_end, color: Colors.white, size: 32),
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
