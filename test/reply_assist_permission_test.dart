import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/reply_assist/reply_assist_permission.dart';

void main() {
  test('first gap is accessibility when both missing', () {
    expect(
      firstReplyAssistPermGap(
        a11yEnabled: false,
        overlayPermissionGranted: false,
      ),
      ReplyAssistPermGap.accessibility,
    );
  });

  test('overlay is the remaining gap after accessibility', () {
    expect(
      firstReplyAssistPermGap(
        a11yEnabled: true,
        overlayPermissionGranted: false,
      ),
      ReplyAssistPermGap.overlay,
    );
  });

  test('no gap when both permissions are ready', () {
    expect(
      firstReplyAssistPermGap(
        a11yEnabled: true,
        overlayPermissionGranted: true,
      ),
      isNull,
    );
  });

  test('gap hints stay copy-only and non-automated', () {
    expect(
      replyAssistPermGapHint(ReplyAssistPermGap.accessibility),
      contains('只读'),
    );
    expect(
      replyAssistPermGapHint(ReplyAssistPermGap.overlay),
      contains('贴纸'),
    );
  });
}
