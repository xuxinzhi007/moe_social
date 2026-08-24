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
  ///
  /// 无论 stop 是否异常都复位状态（finally 语义），避免录音状态卡死。
  Future<(String path, int durationSec)?> stopRecording() async {
    if (!_isRecording) return null;
    final duration = elapsed.inSeconds;
    final path = _currentPath;
    try {
      await _recorder.stop();
    } catch (_) {
      // stop 失败也要清理临时文件，避免泄漏。
      await _deleteIfExists(path);
      return null;
    } finally {
      _isRecording = false;
      _startTime = null;
      _currentPath = null;
    }
    if (path == null || duration < 1) {
      await _deleteIfExists(path);
      return null;
    }
    return (path, duration);
  }

  /// 取消录音（删除临时文件）。
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      _currentPath = null;
      return;
    }
    final path = _currentPath;
    try {
      await _recorder.cancel();
    } catch (_) {
      // cancel 失败也照常复位状态并删除临时文件。
    } finally {
      _isRecording = false;
      _startTime = null;
      _currentPath = null;
    }
    await _deleteIfExists(path);
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
