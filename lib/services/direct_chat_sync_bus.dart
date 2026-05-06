import 'package:flutter/foundation.dart';

/// [DirectChatPage] 写入本地会话缓存后 bump，供消息列表等合并展示最新预览。
class DirectChatSyncBus {
  DirectChatSyncBus._();

  static final ValueNotifier<int> threadsTick = ValueNotifier(0);

  static void bump() {
    threadsTick.value++;
  }
}
