import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../auth_service.dart';
import 'api_service.dart';
import '../utils/behavior_screens.dart';

class BehaviorAnalyticsService {
  BehaviorAnalyticsService._();

  static final BehaviorAnalyticsService instance = BehaviorAnalyticsService._();

  static const _maxQueueSize = 40;
  static const _flushInterval = Duration(seconds: 30);

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  bool _enabled = false;
  String? _sessionId;
  String? _activeRouteName;
  DateTime? _activeRouteEnteredAt;

  void start() {
    if (!AuthService.isLoggedIn) return;
    _enabled = true;
    _sessionId ??= _newSessionId();
    _flushTimer ??= Timer.periodic(_flushInterval, (_) {
      unawaited(flush());
    });
  }

  Future<void> stop() async {
    _enabled = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
    _sessionId = null;
    _activeRouteName = null;
    _activeRouteEnteredAt = null;
  }

  void onRouteEnter(String routeName) {
    if (!_enabled) return;
    _activeRouteName = routeName;
    _activeRouteEnteredAt = DateTime.now();
  }

  void onRouteLeave(String routeName) {
    if (!_enabled) return;
    final enteredAt = _activeRouteEnteredAt;
    if (_activeRouteName != routeName || enteredAt == null) {
      return;
    }
    final durationMs = DateTime.now().difference(enteredAt).inMilliseconds;
    if (durationMs >= 500) {
      trackScreenView(
        BehaviorScreens.fromRouteName(routeName),
        durationMs: durationMs,
      );
    }
    _activeRouteName = null;
    _activeRouteEnteredAt = null;
  }

  void trackScreenView(String screen, {int durationMs = 0}) {
    _enqueue(
      event: 'screen_view',
      screen: screen,
      durationMs: durationMs,
    );
  }

  void trackTap(String screen, {Map<String, String>? params}) {
    _enqueue(
      event: 'tap',
      screen: screen,
      params: params,
      durationMs: 0,
    );
  }

  void _enqueue({
    required String event,
    required String screen,
    Map<String, String>? params,
    int durationMs = 0,
  }) {
    if (!_enabled || !AuthService.isLoggedIn) return;
    final normalized = screen.trim();
    if (normalized.isEmpty) return;

    _queue.add({
      'event': event,
      'screen': normalized,
      if (params != null && params.isNotEmpty) 'params': params,
      'duration_ms': durationMs,
      'session_id': _sessionId ?? _newSessionId(),
      'client_ts': DateTime.now().millisecondsSinceEpoch,
    });

    if (_queue.length >= _maxQueueSize) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (!_enabled || !AuthService.isLoggedIn || _queue.isEmpty) return;
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await ApiService.trackBehaviorEvents(userId, batch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BehaviorAnalytics flush failed: $e');
      }
      if (_queue.length + batch.length <= _maxQueueSize * 2) {
        _queue.insertAll(0, batch);
      }
    }
  }

  String _newSessionId() {
    final rand = Random().nextInt(999999);
    return '${DateTime.now().millisecondsSinceEpoch}_$rand';
  }
}
