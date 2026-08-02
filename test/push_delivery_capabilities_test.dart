import 'package:flutter_test/flutter_test.dart';

import 'package:moe_social/services/push_delivery_capabilities.dart';

void main() {
  test('current delivery capabilities describe the existing fallback chain',
      () {
    expect(
      PushDeliveryCapabilities.current.supports(PushDeliveryChannel.webSocket),
      isTrue,
    );
    expect(
      PushDeliveryCapabilities.current
          .supports(PushDeliveryChannel.localNotification),
      isTrue,
    );
    expect(
      PushDeliveryCapabilities.current.supports(PushDeliveryChannel.remotePush),
      isFalse,
    );
  });
}
