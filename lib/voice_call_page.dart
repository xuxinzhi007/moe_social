import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../auth_service.dart';
import '../services/api_service.dart';

class VoiceCallPage extends StatefulWidget {
  final String channelName;
  final String userName;
  final String userAvatar;

  const VoiceCallPage({
    super.key,
    required this.channelName,
    required this.userName,
    required this.userAvatar,
  });

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  String? _appId;
  String? _token;
  RtcEngine? _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = true;
  final List<int> _remoteUsers = [];

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    final userAccount = AuthService.currentUser;
    if (userAccount == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // 1. 请求权限
    await [Permission.microphone].request();

    // 2. 获取 Token 和 AppID
    try {
      final response = await ApiService.getRtcToken(widget.channelName);
      _token = response['token'];
      _appId = response['app_id'];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取通话凭证失败: $e')),
        );
        Navigator.pop(context);
      }
      return;
    }

    if (_appId == null || _token == null) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通话配置无效')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // 3. 创建引擎
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 4. 注册事件回调
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          if (mounted) {
            setState(() {
              _isJoined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          if (mounted) {
            setState(() {
              _remoteUsers.add(remoteUid);
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          if (mounted) {
            setState(() {
              _remoteUsers.remove(remoteUid);
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora Error: $err, $msg");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('通话出错: $msg')),
          );
          Navigator.pop(context);
        },
      ),
    );

    // 5. 加入频道
    try {
      await _engine!.joinChannelWithUserAccount(
        token: _token!,
        channelId: widget.channelName,
        userAccount: userAccount,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入通话失败: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Future<void> _dispose() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
    }
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _onToggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
    _engine?.setEnableSpeakerphone(_isSpeaker);
  }

  void _onCallEnd() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            // 顶部状态栏
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'End-to-end encrypted',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            const Spacer(),

            // 用户头像和名称
            Center(
              child: Column(
                children: [
                   CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(widget.userAvatar),
                    onBackgroundImageError: (_, __) {},
                    child: widget.userAvatar.isEmpty
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isJoined 
                      ? (_remoteUsers.isNotEmpty ? '通话中' : '等待对方加入...') 
                      : '连接中...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 底部控制栏
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 48),
              decoration: const BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 静音按钮
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.white : Colors.white24,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onTap: _onToggleMute,
                  ),

                  // 挂断按钮
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    iconColor: Colors.white,
                    size: 72,
                    onTap: _onCallEnd,
                  ),

                  // 扬声器按钮
                  _buildControlButton(
                    icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                    color: _isSpeaker ? Colors.white : Colors.white24,
                    iconColor: _isSpeaker ? Colors.black : Colors.white,
                    onTap: _onToggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}
