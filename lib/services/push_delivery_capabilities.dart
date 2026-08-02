enum PushDeliveryChannel {
  webSocket,
  localNotification,
  remotePush,
}

class PushDeliveryCapabilities {
  const PushDeliveryCapabilities({
    required this.webSocket,
    required this.localNotification,
    required this.remotePush,
  });

  static const current = PushDeliveryCapabilities(
    webSocket: true,
    localNotification: true,
    remotePush: false,
  );

  final bool webSocket;
  final bool localNotification;
  final bool remotePush;

  bool supports(PushDeliveryChannel channel) {
    switch (channel) {
      case PushDeliveryChannel.webSocket:
        return webSocket;
      case PushDeliveryChannel.localNotification:
        return localNotification;
      case PushDeliveryChannel.remotePush:
        return remotePush;
    }
  }
}
