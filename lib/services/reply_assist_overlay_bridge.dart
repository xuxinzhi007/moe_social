import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/feature_flags.dart';
import '../models/reply_assist_models.dart';
import 'reply_assist_service.dart';

/// Native 桌宠点脸后传入的读屏快照。
class OverlaySnapshot {
  const OverlaySnapshot({
    required this.needsScreenshotFallback,
    required this.reason,
    required this.appPackage,
    required this.messages,
  });

  final bool needsScreenshotFallback;
  final String reason;
  final String appPackage;
  final List<ReplyAssistChatMessage> messages;
}

OverlaySnapshot parseOverlaySnapshot(Object? raw) {
  final map = <String, dynamic>{};
  if (raw is Map) {
    raw.forEach((key, value) {
      map[key.toString()] = value;
    });
  }
  final messagesRaw = map['messages'];
  final messages = <ReplyAssistChatMessage>[];
  if (messagesRaw is List) {
    for (final item in messagesRaw) {
      if (item is! Map) continue;
      final text = item['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      messages.add(
        ReplyAssistChatMessage(
          role: item['role']?.toString() ?? 'unknown',
          text: text,
        ),
      );
    }
  }
  return OverlaySnapshot(
    needsScreenshotFallback: map['needs_screenshot_fallback'] == true,
    reason: map['reason']?.toString() ?? '',
    appPackage: map['app_package']?.toString() ?? '',
    messages: messages,
  );
}

/// 启动时挂上 Native→Dart `onOverlaySuggest`，让桌宠当场闭环。
class ReplyAssistOverlayBridge {
  ReplyAssistOverlayBridge._();

  static const MethodChannel channel =
      MethodChannel('com.moe_social/reply_assist');

  static bool _attached = false;
  static final ReplyAssistService _service = ReplyAssistService();

  static void ensureAttached() {
    if (_attached) return;
    if (kIsWeb) return;
    if (!FeatureFlags.replyAssistPrototype) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _attached = true;
    channel.setMethodCallHandler(_onMethodCall);
  }

  static Future<bool> _invokeBool(String method) async {
    try {
      return await channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAccessibilityEnabled() =>
      _invokeBool('isAccessibilityEnabled');

  static Future<bool> isOverlayPermissionGranted() =>
      _invokeBool('isOverlayPermissionGranted');

  static Future<bool> isOverlayVisible() => _invokeBool('isOverlayVisible');

  static Future<void> openAccessibilitySettings() async {
    await channel.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await channel.invokeMethod<void>('openOverlaySettings');
  }

  static Future<bool> toggleOverlay() async {
    return await channel.invokeMethod<bool>('toggleOverlay') ?? false;
  }

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onOverlaySuggest') {
      throw MissingPluginException(call.method);
    }
    return handleOverlaySuggest(call.arguments);
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> handleOverlaySuggest(Object? raw) async {
    final snap = parseOverlaySnapshot(raw);
    if (snap.needsScreenshotFallback || snap.messages.isEmpty) {
      final notWeChat = snap.reason == 'not_wechat';
      return <String, dynamic>{
        'ok': false,
        'fallback': snap.reason.isEmpty ? 'empty_tree' : snap.reason,
        'needs_screenshot_fallback': !notWeChat,
        'message': notWeChat ? '现在不在微信聊天页～' : '读不到字，去 App 贴图～',
      };
    }
    try {
      final result = await _service.suggest(
        source: 'a11y',
        messages: snap.messages,
        appPackage:
            snap.appPackage.isEmpty ? 'com.tencent.mm' : snap.appPackage,
      );
      if (result.needsScreenshotFallback || result.options.isEmpty) {
        return <String, dynamic>{
          'ok': false,
          'fallback': 'empty_tree',
          'needs_screenshot_fallback': true,
          'message': '读不到字，去 App 贴图～',
        };
      }
      return <String, dynamic>{
        'ok': true,
        'options': [
          for (final o in result.options.take(3))
            <String, String>{'label': o.label, 'text': o.text},
        ],
      };
    } catch (e) {
      return <String, dynamic>{
        'ok': false,
        'fallback': 'error',
        'message': e.toString(),
      };
    }
  }
}
