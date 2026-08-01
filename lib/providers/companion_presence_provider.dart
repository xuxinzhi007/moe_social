import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/companion_service.dart';
import '../services/companion_ws_service.dart';

/// 全局伙伴存在感：WS 问候/状态 + 「TA 想你了」角标。
///
/// 登录后 [start]，登出 [stop]。UI 用 Provider 订阅。
class CompanionPresenceProvider extends ChangeNotifier {
  CompanionPresenceProvider._();

  static final CompanionPresenceProvider instance =
      CompanionPresenceProvider._();

  final CompanionWsService _ws = CompanionWsService();
  final CompanionService _companion = CompanionService();

  String _greeting = '';
  String _moodThought = '';
  String _activityLabel = '';
  int _attentionCount = 0;
  bool _started = false;
  bool _viewingCompanion = false;

  String get greeting => _greeting;
  String get moodThought => _moodThought;
  String get activityLabel => _activityLabel;
  int get attentionCount => _attentionCount;
  bool get hasAttention => _attentionCount > 0;
  bool get started => _started;

  /// 登录后 / 进主壳时调用。
  void start() {
    if (_started) return;
    _started = true;
    _ws.onPresence = _onPresence;
    _ws.connect();
    unawaited(_syncUnreadFromHistory());
  }

  /// 登出时调用。
  void stop() {
    _started = false;
    _ws.disconnect();
    _greeting = '';
    _moodThought = '';
    _activityLabel = '';
    _attentionCount = 0;
    _viewingCompanion = false;
    notifyListeners();
  }

  /// 正在看 AI 伙伴 Tab / 聊天时：抑制新推送角标叠加；已有提示留给 Hub 横幅展示。
  /// 真正清角标请调 [clearAttention] / [markCompanionChatSeen]。
  void setViewingCompanion(bool viewing) {
    _viewingCompanion = viewing;
  }

  void clearAttention() {
    if (_attentionCount == 0) return;
    _attentionCount = 0;
    notifyListeners();
  }

  /// 聊天页已读后调用。
  Future<void> markCompanionChatSeen() async {
    try {
      await _companion.markChatRead();
    } catch (_) {}
    clearAttention();
  }

  void _onPresence(CompanionPresenceEvent event) {
    var changed = false;
    if (event.greeting.trim().isNotEmpty &&
        event.greeting.trim() != _greeting) {
      _greeting = event.greeting.trim();
      changed = true;
    }
    if (event.moodThought.trim().isNotEmpty &&
        event.moodThought.trim() != _moodThought) {
      _moodThought = event.moodThought.trim();
      changed = true;
    }
    if (event.activityLabel.trim().isNotEmpty &&
        event.activityLabel.trim() != _activityLabel) {
      _activityLabel = event.activityLabel.trim();
      changed = true;
    }

    // 问候/主动回访且用户不在伙伴页 → 点亮「TA 想你了」
    if ((event.type == 'greeting' || event.type == 'proactive') &&
        !_viewingCompanion) {
      if (_attentionCount != 1) {
        _attentionCount = 1;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  Future<void> _syncUnreadFromHistory() async {
    try {
      final readAt = await _companion.loadChatReadAt();
      final history = await _companion.listChatHistory(limit: 8);
      final lastAssistant = history
          .where((e) => e.role != 'user' && e.content.trim().isNotEmpty)
          .map((e) => DateTime.tryParse(e.createdAt))
          .whereType<DateTime>()
          .fold<DateTime?>(null, (best, t) {
        if (best == null || t.isAfter(best)) return t;
        return best;
      });
      if (!_started || _viewingCompanion) return;
      if (lastAssistant == null) return;
      if (readAt == null || lastAssistant.isAfter(readAt)) {
        if (_attentionCount != 1) {
          _attentionCount = 1;
          notifyListeners();
        }
      }
    } catch (_) {}
  }
}
