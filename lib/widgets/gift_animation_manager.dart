import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift.dart';
import 'optimized_gift_animation.dart';

/// Public API: call `GiftAnimationManager().showGiftAnimation(context, gift)`
/// from wherever a gift is sent. The animation runs in an Overlay layer
/// so it never covers content with a black barrier.
class GiftAnimationManager {
  static final GiftAnimationManager _instance =
      GiftAnimationManager._internal();
  factory GiftAnimationManager() => _instance;
  GiftAnimationManager._internal();

  final List<_AnimTask> _queue = [];
  bool _isPlaying = false;
  OverlayEntry? _currentEntry;

  // Combo tracking
  int _comboCount = 0;
  DateTime? _lastSendTime;
  static const _comboWindow = Duration(seconds: 3);
  static const _minInterval = Duration(milliseconds: 150);
  DateTime? _lastEndTime;

  int get comboCount => _comboCount;
  bool get isPlaying => _isPlaying;

  // ─── Public entry point ─────────────────────────────────────────────────

  /// Show a gift animation via the Overlay. Queues automatically.
  void showGiftAnimation(
    BuildContext context,
    Gift gift, {
    int comboCount = 1,
  }) {
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _comboWindow) {
      _comboCount++;
    } else {
      _comboCount = comboCount;
    }
    _lastSendTime = now;

    // Dedup: if same gift already in queue, bump its combo
    for (final task in _queue) {
      if (task.gift.id == gift.id) {
        task.comboCount = _comboCount;
        return;
      }
    }

    final priority = _priorityOf(gift);
    final task = _AnimTask(
      gift: gift,
      context: context,
      priority: priority,
      comboCount: _comboCount,
    );

    // Insert by priority
    int insertAt = _queue.length;
    for (int i = 0; i < _queue.length; i++) {
      if (task.priority > _queue[i].priority) {
        insertAt = i;
        break;
      }
    }
    _queue.insert(insertAt, task);

    if (!_isPlaying) _processQueue();
  }

  // ─── Internal queue processor ────────────────────────────────────────────

  void _processQueue() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      return;
    }
    _isPlaying = true;

    if (_lastEndTime != null) {
      final elapsed = DateTime.now().difference(_lastEndTime!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }

    final task = _queue.removeAt(0);
    await _playTask(task);
    _lastEndTime = DateTime.now();
    _processQueue();
  }

  Future<void> _playTask(_AnimTask task) async {
    final completer = Completer<void>();

    // Resolve overlay from the task's context
    OverlayState? overlay;
    try {
      overlay = Overlay.of(task.context, rootOverlay: true);
    } catch (_) {
      await Future.delayed(task.gift.animationDuration);
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: OptimizedGiftAnimation(
              gift: task.gift,
              comboCount: task.comboCount,
              duration: task.gift.animationDuration,
              onAnimationComplete: () {
                entry.remove();
                _currentEntry = null;
                completer.complete();
              },
            ),
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    return completer.future.timeout(
      task.gift.animationDuration + const Duration(seconds: 1),
      onTimeout: () {
        if (_currentEntry == entry) {
          try {
            entry.remove();
          } catch (_) {}
          _currentEntry = null;
        }
      },
    );
  }

  int _priorityOf(Gift gift) {
    switch (gift.level) {
      case GiftLevel.basic:
        return 0;
      case GiftLevel.medium:
        return 1;
      case GiftLevel.advanced:
        return 2;
      case GiftLevel.luxury:
        return 3;
    }
  }

  void clearQueue() {
    _queue.clear();
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
    _isPlaying = false;
    _comboCount = 0;
  }

  void resetCombo() {
    _comboCount = 0;
    _lastSendTime = null;
  }

  Map<String, dynamic> getStats() => {
        'queueLength': _queue.length,
        'isPlaying': _isPlaying,
        'comboCount': _comboCount,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal task model
// ─────────────────────────────────────────────────────────────────────────────

class _AnimTask {
  final Gift gift;
  final BuildContext context;
  final int priority;
  int comboCount;

  _AnimTask({
    required this.gift,
    required this.context,
    required this.priority,
    required this.comboCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PerformanceController (kept for any callers that still reference it)
// ─────────────────────────────────────────────────────────────────────────────

enum DevicePerformanceLevel { low, medium, high }

class PerformanceController {
  static final PerformanceController _instance =
      PerformanceController._internal();
  factory PerformanceController() => _instance;
  PerformanceController._internal();

  DevicePerformanceLevel _level = DevicePerformanceLevel.medium;
  bool _animEnabled = true;
  int _maxParticles = 40;

  DevicePerformanceLevel get performanceLevel => _level;
  bool get animationEnabled => _animEnabled;
  int get maxParticles => _maxParticles;

  void setPerformanceLevel(DevicePerformanceLevel lvl) {
    _level = lvl;
    _maxParticles = lvl == DevicePerformanceLevel.low
        ? 10
        : lvl == DevicePerformanceLevel.medium
            ? 25
            : 40;
  }

  void setAnimationEnabled(bool v) => _animEnabled = v;
  int getAdjustedParticleCount(int base) => base.clamp(0, _maxParticles);
  Duration getAdjustedDuration(Duration d) => d;
  void autoDetectPerformanceLevel() {}
}
