import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/reply_assist_overlay_bridge.dart';

void main() {
  test('parseOverlaySnapshot keeps visible messages', () {
    final snap = parseOverlaySnapshot({
      'needs_screenshot_fallback': false,
      'app_package': 'com.tencent.mm',
      'messages': [
        {'role': 'peer', 'text': '今晚有空吗'},
        {'role': 'self', 'text': '可能晚点哦'},
        {'role': 'unknown', 'text': ''},
      ],
    });
    expect(snap.messages.length, 2);
    expect(snap.messages.first.text, '今晚有空吗');
    expect(snap.appPackage, 'com.tencent.mm');
    expect(snap.needsScreenshotFallback, isFalse);
  });

  test('empty tree overlay suggest returns fallback without crashing',
      () async {
    final out = await ReplyAssistOverlayBridge.handleOverlaySuggest({
      'needs_screenshot_fallback': true,
      'reason': 'empty_tree',
      'messages': <Object?>[],
    });
    expect(out['ok'], isFalse);
    expect(out['needs_screenshot_fallback'], isTrue);
    expect(out['message'], contains('贴图'));
  });

  test('not_wechat overlay suggest uses dedicated copy', () async {
    final out = await ReplyAssistOverlayBridge.handleOverlaySuggest({
      'needs_screenshot_fallback': false,
      'reason': 'not_wechat',
      'messages': <Object?>[],
    });
    expect(out['ok'], isFalse);
    expect(out['message'], contains('微信'));
  });
}
