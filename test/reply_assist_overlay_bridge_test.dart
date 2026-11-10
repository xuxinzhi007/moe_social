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

  test('legacy not_wechat reason still offers screenshot fallback', () async {
    final out = await ReplyAssistOverlayBridge.handleOverlaySuggest({
      'needs_screenshot_fallback': false,
      'reason': 'not_wechat',
      'messages': <Object?>[],
    });
    expect(out['ok'], isFalse);
    expect(out['needs_screenshot_fallback'], isTrue);
    expect(out['message'], contains('贴图'));
    expect(out['message'], isNot(contains('微信')));
  });

  test('parseOverlaySnapshot reads adult_intimate flag', () {
    final off = parseOverlaySnapshot({
      'needs_screenshot_fallback': false,
      'messages': [
        {'role': 'peer', 'text': '在吗'},
      ],
    });
    expect(off.adultIntimate, isFalse);

    final on = parseOverlaySnapshot({
      'needs_screenshot_fallback': false,
      'adult_intimate': true,
      'messages': [
        {'role': 'peer', 'text': '在吗'},
      ],
    });
    expect(on.adultIntimate, isTrue);
  });

  test('parseOverlaySnapshot reads target_message', () {
    final snap = parseOverlaySnapshot({
      'needs_screenshot_fallback': false,
      'messages': [
        {'role': 'self', 'text': '我到了'},
        {'role': 'peer', 'text': '哥哥在吗', 'target': true},
      ],
      'target_message': {'role': 'peer', 'text': '哥哥在吗'},
    });
    expect(snap.targetMessage?.role, 'peer');
    expect(snap.targetMessage?.text, '哥哥在吗');
  });
}
