import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 语音消息录制服务（单例）。
///
/// 录制 AAC（m4a 容器）；最长时长由调用方计时控制（见 DirectChatPage）。
class VoiceMessageService {
  static final VoiceMessageService _instance = VoiceMessageService._();

  factory VoiceMessageService() => _instance;

  VoiceMessageService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  DateTime? _startTime;

  bool get isRecording => _isRecording;

  Duration get elapsed =>
      _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;

  /// 开始录音（AAC 格式，最长 60 秒由调用方计时控制）。
  Future<void> startRecording() async {
    if (_isRecording) return;
    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _currentPath!,
    );
    _isRecording = true;
    _startTime = DateTime.now();
  }

  /// 停止录音，返回文件路径和时长（秒）；未录音或不足 1 秒返回 null。
  Future<(String path, int durationSec)?> stopRecording() async {
    if (!_isRecording) return null;
    await _recorder.stop();
    _isRecording = false;
    final duration = elapsed.inSeconds;
    _startTime = null;
    final path = _currentPath;
    if (path == null || duration < 1) return null;
    return (path, duration);
  }

  /// 取消录音（删除临时文件）。
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      _currentPath = null;
      return;
    }
    await _recorder.cancel();
    _isRecording = false;
    _startTime = null;
    final path = _currentPath;
    _currentPath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
