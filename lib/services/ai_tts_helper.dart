import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../utils/ai_message_format_parser.dart';

/// 统一 TTS 初始化与朗读，避免各聊天页行为不一致。
class AiTtsHelper {
  AiTtsHelper(this._tts);

  final FlutterTts _tts;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        await _tts.awaitSpeakCompletion(true);
      }
      final lang = await _resolveLanguage();
      if (lang != null) {
        await _tts.setLanguage(lang);
      }
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<String?> _resolveLanguage() async {
    const candidates = ['zh-CN', 'zh_CN', 'cmn-cn', 'zh-TW', 'en-US'];
    for (final code in candidates) {
      try {
        final ok = await _tts.isLanguageAvailable(code);
        if (ok == true) return code;
      } catch (_) {}
    }
    try {
      final langs = await _tts.getLanguages;
      if (langs is List && langs.isNotEmpty) {
        for (final code in candidates) {
          if (langs.map((e) => e.toString()).contains(code)) return code;
        }
        return langs.first.toString();
      }
    } catch (_) {}
    return 'zh-CN';
  }

  void bindHandlers({
    required VoidCallback onComplete,
    void Function(String msg)? onError,
  }) {
    _tts.setCompletionHandler(onComplete);
    _tts.setErrorHandler((msg) => onError?.call(msg));
  }

  Future<void> speak(String raw) async {
    final text = plainTextForSpeech(raw);
    if (text.isEmpty) {
      throw Exception('没有可朗读的文本');
    }
    if (!_ready) {
      await initialize();
    }
    await _tts.stop();
    final lang = await _resolveLanguage();
    if (lang != null) {
      await _tts.setLanguage(lang);
    }
    await _tts.setSpeechRate(0.48);
    final result = await _tts.speak(text);
    if (result == 0) return;
    if (result == -1) {
      throw Exception('当前设备不支持语音朗读');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
