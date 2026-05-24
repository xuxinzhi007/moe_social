import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart';

/// Lazily initializes Rive native runtime; safe to call multiple times.
class RiveBootstrap {
  RiveBootstrap._();

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() {
    if (kIsWeb) return Future<void>.value();
    _initFuture ??= RiveNative.init().catchError((Object e, StackTrace st) {
      debugPrint('RiveNative.init failed: $e');
    });
    return _initFuture!;
  }
}
