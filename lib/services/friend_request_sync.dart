import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth_service.dart';
import 'user_service.dart';

/// 好友申请角标 / 列表的实时同步总线。
///
/// - WS `friend_request` 事件 → [onRealtimeEvent] → 刷新计数并 [tick]++
/// - 本地同意/拒绝后也应调用 [refreshIncomingCount]
class FriendRequestSync {
  FriendRequestSync._();

  /// 列表页监听：有新事件时递增，触发重新拉申请列表。
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  /// 枢纽角标用的待处理数量。
  static final ValueNotifier<int> incomingCount = ValueNotifier<int>(0);

  static bool _refreshing = false;

  static void bumpTick() {
    tick.value++;
  }

  /// ChatPushService 收到 `friend_request` 时调用。
  static void onRealtimeEvent([Map<String, dynamic>? data]) {
    bumpTick();
    unawaited(refreshIncomingCount());
  }

  /// 拉取待处理申请数量（无轮询；由 WS / 生命周期 / 本地操作触发）。
  static Future<void> refreshIncomingCount() async {
    final uid = AuthService.currentUser;
    if (uid == null) {
      if (incomingCount.value != 0) incomingCount.value = 0;
      return;
    }
    if (_refreshing) return;
    _refreshing = true;
    try {
      final list = await UserService.getIncomingFriendRequests(uid);
      incomingCount.value = list.length;
    } catch (e) {
      debugPrint('FriendRequestSync.refreshIncomingCount failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  static void clear() {
    incomingCount.value = 0;
  }
}
