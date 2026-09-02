import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/companion_service.dart';
import '../services/companion_interaction_coordinator.dart';
import '../services/companion_ws_service.dart';
import '../services/notification_service.dart';

enum CompanionAttentionSource {
  none,
  proactiveMessage,
  unreadChat,
}

/// 全局伙伴存在感：WS 问候/状态 + 「TA 想你了」角标。
///
/// 登录后 [start]，登出 [stop]。UI 用 Provider 订阅。
class CompanionPresenceProvider extends ChangeNotifier {
  CompanionPresenceProvider._();

  static final CompanionPresenceProvider instance =
      CompanionPresenceProvider._();

  final CompanionWsService _ws = CompanionWsService();
  final CompanionService _companion = CompanionService();
  final CompanionInteractionCoordinator _coordinator =
      CompanionInteractionCoordinator.instance;

  String _greeting = '';
  String _moodThought = '';
  String _activityLabel = '';
  String _attentionMessage = '';
  CompanionAttentionSource _attentionSource = CompanionAttentionSource.none;
  int _attentionCount = 0;
  bool _started = false;
  bool _viewingCompanion = false;
  bool _syncingRecentEvents = false;

  String get greeting => _greeting;
  String get moodThought => _moodThought;
  String get activityLabel => _activityLabel;
  String get attentionMessage => _attentionMessage;
  CompanionAttentionSource get attentionSource => _attentionSource;
  String get attentionSourceLabel => switch (_attentionSource) {
        CompanionAttentionSource.proactiveMessage => '刚刚收到的主动回访',
        CompanionAttentionSource.unreadChat => '聊天里有一条新回复',
        CompanionAttentionSource.none => '',
      };
  int get attentionCount => _attentionCount;
  bool get hasAttention => _attentionCount > 0;
  bool get started => _started;

  /// 登录后 / 进主壳时调用。
  void start() {
    if (_started) return;
    _started = true;
    _ws.onPresence = _onPresence;
    _ws.onEvent = _onEvent;
    _ws.onConnected = _onConnected;
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
    _attentionMessage = '';
    _attentionSource = CompanionAttentionSource.none;
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
    _attentionMessage = '';
    _attentionSource = CompanionAttentionSource.none;
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

    final attentionMessage = _attentionMessageFor(event);

    // 只有 WS 携带了真实内容，才点亮「TA 想你了」。
    if (event.type == 'proactive' &&
        attentionMessage.isNotEmpty &&
        !_viewingCompanion) {
      final attentionChanged = _attentionMessage != attentionMessage ||
          _attentionSource != CompanionAttentionSource.proactiveMessage ||
          _attentionCount != 1;
      _attentionMessage = attentionMessage;
      _attentionSource = CompanionAttentionSource.proactiveMessage;
      _attentionCount = 1;
      changed = changed || attentionChanged;
    }

    if (event.type == 'proactive' &&
        attentionMessage.isNotEmpty &&
        !_viewingCompanion) {
      unawaited(
        NotificationService.showCompanionProactiveNotification(
          message: attentionMessage,
          reason: event.activityLabel,
          notificationId: event.notificationId,
        ),
      );
    }

    if (changed) notifyListeners();
    if (changed) {
      _coordinator.publishPresenceChanged(eventType: event.type);
    }
  }

  String _attentionMessageFor(CompanionPresenceEvent event) {
    final greeting = event.greeting.trim();
    if (greeting.isNotEmpty) return greeting;
    final mood = event.moodThought.trim();
    if (mood.isNotEmpty) return mood;
    return '';
  }

  void _onEvent(CompanionWsEvent event) {
    _coordinator.publishBackendEvent(
      eventType: event.eventType,
      sourceDomain: event.sourceDomain,
      eventId: event.eventId,
      sourceId: event.sourceId,
      dedupeKey: event.dedupeKey,
      payloadJson: event.payloadJson,
      visibility: event.visibility,
      sensitivity: event.sensitivity,
      relationshipDelta: event.relationshipDelta,
      occurredAt: event.occurredAt,
    );
  }

  void _onConnected() {
    _coordinator.publishBackendEvent(
      eventType: 'connection_restored',
      sourceDomain: 'companion_ws',
    );
    unawaited(_syncRecentEvents());
  }

  Future<void> _syncRecentEvents() async {
    if (_syncingRecentEvents || !_started) return;
    _syncingRecentEvents = true;
    try {
      final events = await _companion.listEvents(limit: 32);
      if (!_started) return;
      for (final event in events.reversed) {
        _coordinator.publishBackendEvent(
          eventType: event.eventType,
          sourceDomain: event.sourceDomain,
          eventId: event.id,
          sourceId: event.sourceId,
          dedupeKey: event.dedupeKey,
          payloadJson: event.payloadJson,
          visibility: event.visibility,
          sensitivity: event.sensitivity,
          relationshipDelta: event.relationshipDelta,
          occurredAt: DateTime.tryParse(event.occurredAt),
        );
      }
    } catch (_) {
    } finally {
      _syncingRecentEvents = false;
    }
  }

  Future<void> _syncUnreadFromHistory() async {
    try {
      final readAt = await _companion.loadChatReadAt();
      final history = await _companion.listChatHistory(limit: 8);
      CompanionChatLogData? latestAssistant;
      DateTime? latestAssistantAt;
      for (final item in history) {
        if (item.role == 'user' || item.content.trim().isEmpty) continue;
        final at = DateTime.tryParse(item.createdAt);
        if (at == null) continue;
        if (latestAssistantAt == null || at.isAfter(latestAssistantAt)) {
          latestAssistant = item;
          latestAssistantAt = at;
        }
      }
      if (!_started || _viewingCompanion) return;
      if (latestAssistant == null || latestAssistantAt == null) return;
      if (readAt == null || latestAssistantAt.isAfter(readAt)) {
        if (_attentionSource == CompanionAttentionSource.proactiveMessage) {
          return;
        }
        final message = latestAssistant.content.trim();
        final attentionChanged = _attentionMessage != message ||
            _attentionSource != CompanionAttentionSource.unreadChat ||
            _attentionCount != 1;
        _attentionMessage = message;
        _attentionSource = CompanionAttentionSource.unreadChat;
        _attentionCount = 1;
        if (attentionChanged) {
          notifyListeners();
        }
      }
    } catch (_) {}
  }
}
