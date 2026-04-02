import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class VoiceCallInitiationPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const VoiceCallInitiationPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  State<VoiceCallInitiationPage> createState() => _VoiceCallInitiationPageState();
}

class _VoiceCallInitiationPageState extends State<VoiceCallInitiationPage> {
  bool _isCalling = false;
  bool _isCancelled = false;
  String _callStatus = '正在呼叫...';

  @override
  void initState() {
    super.initState();
    _initiateCall();
  }

  Future<void> _initiateCall() async {
    setState(() => _isCalling = true);

    try {
      // 调用后端API发起呼叫
      final response = await ApiService.initiateCall(widget.receiverId);
      final callId = response['call_id'];
      
      // 等待对方响应
      await _waitForAnswer(callId);
    } catch (e) {
      _showError('发起呼叫失败: $e');
      Navigator.pop(context);
    }
  }

  Future<void> _waitForAnswer(String callId) async {
    // 模拟等待对方响应
    // 实际实现中应该使用WebSocket或轮询来监听呼叫状态
    await Future.delayed(const Duration(seconds: 30));
    
    if (!_isCancelled) {
      _showError('对方未接听');
      Navigator.pop(context);
    }
  }

  void _cancelCall() async {
    setState(() {
      _isCancelled = true;
      _callStatus = '取消呼叫...';
    });
    
    try {
      // 调用后端API取消呼叫
      await ApiService.cancelCall();
    } catch (e) {
      print('取消呼叫失败: $e');
    } finally {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _callStatus,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Text(
            widget.receiverName,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 80,
            backgroundImage: NetworkImage(widget.receiverAvatar),
            onBackgroundImageError: (_, __) {},
            child: widget.receiverAvatar.isEmpty
                ? const Icon(Icons.person, size: 80, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 32),
          if (_isCalling)
            const CircularProgressIndicator(color: Colors.white),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: GestureDetector(
              onTap: _cancelCall,
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
          ),
        ],
      ),
    );
  }
}
