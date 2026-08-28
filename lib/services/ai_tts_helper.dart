import 'dart:async';
import 'dart:io';

import 'package:edge_tts/edge_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/ai_message_format_parser.dart';

/// 陪伴朗读：Microsoft Edge 神经 TTS
/// （协议同源 [rany2/edge-tts](https://github.com/rany2/edge-tts)，Dart 包 `edge_tts`）
/// + [just_audio] 播放。
class AiTtsHelper {
  AiTtsHelper();

  static const defaultVoice = 'zh-CN-XiaoxiaoNeural';

  static const chineseVoices = <({String id, String label})>[
    (id: 'zh-CN-XiaoxiaoNeural', label: '晓晓 · 温柔女声'),
    (id: 'zh-CN-XiaoyiNeural', label: '晓伊 · 活泼女声'),
    (id: 'zh-CN-YunxiNeural', label: '云希 · 清朗男声'),
    (id: 'zh-CN-YunyangNeural', label: '云扬 · 沉稳男声'),
    (id: 'zh-CN-XiaochenNeural', label: '晓辰 · 知性女声'),
  ];

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;

  bool _ready = false;
  bool _speaking = false;
  bool _suppressComplete = false;
  int _generation = 0;
  int? _activePlayGen;

  String _voice = defaultVoice;
  double _volume = 1.0;
  double _pitch = 1.0;
  double _speechRate = 0.5;

  VoidCallback? _onComplete;
  VoidCallback? _onStart;
  VoidCallback? _onCancel;

  bool get isReady => _ready;
  bool get isSpeaking => _speaking;
  String get voice => _voice;
  double get volume => _volume;
  double get pitch => _pitch;
  double get speechRate => _speechRate;

  Future<void> initialize() async {
    _playerSub ??= _player.playerStateStream.listen((state) {
      if (state.processingState != ProcessingState.completed) return;
      // stop()/换轨时的 completed 不能清掉「正在朗读」UI。
      if (_suppressComplete) return;
      if (_activePlayGen == null) return;
      _activePlayGen = null;
      if (!_speaking) return;
      _speaking = false;
      _onComplete?.call();
    });
    try {
      await _player.setVolume(_volume.clamp(0.0, 1.0));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void bindHandlers({
    required VoidCallback onComplete,
    void Function(String msg)? onError,
    VoidCallback? onStart,
    VoidCallback? onCancel,
  }) {
    _onComplete = onComplete;
    _onStart = onStart;
    _onCancel = onCancel;
    onError;
  }

  Future<void> setVoice(String voiceId) async {
    _voice = voiceId.trim().isEmpty ? defaultVoice : voiceId.trim();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> setPitch(double value) async {
    _pitch = value.clamp(0.5, 2.0);
  }

  Future<void> setSpeechRate(double value) async {
    _speechRate = value.clamp(0.2, 1.0);
  }

  String get _rateTag {
    final pct = ((_speechRate - 0.5) * 100).round().clamp(-50, 100);
    return '${pct >= 0 ? '+' : ''}$pct%';
  }

  String get _pitchTag {
    final hz = ((_pitch - 1.0) * 50).round().clamp(-50, 50);
    return '${hz >= 0 ? '+' : ''}${hz}Hz';
  }

  String get _volumeTag {
    final pct = ((_volume - 1.0) * 100).round().clamp(-50, 100);
    return '${pct >= 0 ? '+' : ''}$pct%';
  }

  Future<void> _quietStop() async {
    _suppressComplete = true;
    try {
      await _player.stop();
    } catch (_) {
    } finally {
      _suppressComplete = false;
    }
  }

  /// 合成并开始播放后立即返回 true（不阻塞到播完，避免 UI 状态被卡死）。
  Future<bool> speak(String raw) async {
    final text = plainTextForSpeech(raw);
    if (text.isEmpty) {
      throw Exception('没有可朗读的文本');
    }
    if (kIsWeb) {
      throw Exception('当前平台暂不支持神经朗读，请用手机或模拟器');
    }
    if (!_ready) {
      await initialize();
    }
    if (!_ready) {
      throw Exception('播放器未就绪');
    }

    final gen = ++_generation;
    _activePlayGen = null;
    await _quietStop();
    _speaking = false;

    late final Uint8List bytes;
    try {
      final communicate = Communicate(
        text: text,
        voice: _voice,
        rate: _rateTag,
        pitch: _pitchTag,
        volume: _volumeTag,
      );
      bytes = await communicate.toBytes();
    } catch (e) {
      if (gen != _generation) return false;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      throw Exception(
        msg.isEmpty ? '朗读合成失败，请检查网络' : '朗读合成失败：$msg',
      );
    }

    if (gen != _generation) return false;
    if (bytes.isEmpty) {
      throw Exception('朗读合成结果为空');
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/moe_edge_tts_$gen.mp3');
      await file.writeAsBytes(bytes, flush: true);
      if (gen != _generation) return false;

      await _player.setFilePath(file.path);
      if (gen != _generation) return false;

      _activePlayGen = gen;
      _speaking = true;
      _onStart?.call();
      // 不 await 播完：播完靠 playerStateStream；停止靠 generation。
      unawaited(_player.play().catchError((_) {}));
      return true;
    } catch (e) {
      if (gen != _generation) return false;
      _speaking = false;
      _activePlayGen = null;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      throw Exception(msg.isEmpty ? '朗读播放失败' : '朗读播放失败：$msg');
    }
  }

  Future<void> stop() async {
    _generation++;
    _activePlayGen = null;
    final wasSpeaking = _speaking;
    _speaking = false;
    await _quietStop();
    if (wasSpeaking) {
      _onCancel?.call();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _playerSub?.cancel();
    _playerSub = null;
    await _player.dispose();
  }
}
