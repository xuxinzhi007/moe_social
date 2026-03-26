import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AccessibilityOverlayService {
  static StreamSubscription? _subscription;

  static void init() {
    if (kIsWeb || !Platform.isAndroid) return;
    // 简化：不再自动监听输入框事件弹球，避免影响第三方App输入焦点（例如QQ无法点击输入框）。
    // 悬浮球由「输入辅助悬浮球」设置页开关直接控制显示/关闭。
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
