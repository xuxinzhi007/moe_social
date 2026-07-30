import 'package:flutter/foundation.dart';

/// 未捕获错误的内存环形缓冲，便于调试与后续接 Crashlytics/Sentry。
///
/// 不上传远端；正式 SDK 接入前作为可观测最小实现。
abstract final class CrashReportBuffer {
  static const int _maxEntries = 40;
  static final List<String> _entries = <String>[];

  /// 最近错误快照（只读）。
  static List<String> get entries => List<String>.unmodifiable(_entries);

  static void record(
    Object error,
    StackTrace? stack, {
    String source = 'unknown',
  }) {
    final stackBrief = stack == null
        ? ''
        : stack.toString().split('\n').take(6).join(' | ');
    final line =
        '${DateTime.now().toIso8601String()} [$source] $error :: $stackBrief';
    _entries.add(line);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    debugPrint('CrashReportBuffer: $line');
  }
}
