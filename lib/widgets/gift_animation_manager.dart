import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth_service.dart';
import '../constants/feature_flags.dart';
import '../models/gift.dart';
import 'gift_runway.dart';
import 'live_gift_effect.dart';
import 'lottie_gift_effect.dart';
import 'motion/lottie_motion_registry.dart';
import 'motion/moe_lottie_motion.dart';
import 'motion/moe_vfx_profile.dart';

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
  bool _precacheStarted = false;

  // Combo tracking
  int _comboCount = 0;
  DateTime? _lastSendTime;
  static const _comboWindow = Duration(seconds: 3);
  static const _minInterval = Duration(milliseconds: 150);
  DateTime? _lastEndTime;

  int get comboCount => _comboCount;
  bool get isPlaying => _isPlaying;

  /// 打开礼物面板时预载 Lottie 模板（可重复调用，仅首次生效）。
  void precacheGiftLottie() {
    if (_precacheStarted || !FeatureFlags.useLottieGiftEffects) return;
    _precacheStarted = true;
    unawaited(
        MoeLottieMotion.precache(LottieMotionRegistry.giftPrecacheAssets));
  }

  // ─── Public entry point ─────────────────────────────────────────────────

  /// Show a gift animation via the Overlay. Queues automatically.
  void showGiftAnimation(
    BuildContext context,
    Gift gift, {
    int comboCount = 1,
  }) {
    final overlay = resolveRootOverlay(context);
    if (overlay == null) return;
    _enqueue(overlay, gift, comboCount: comboCount, context: context);
  }

  /// 直接插入 root [OverlayState]（BottomSheet 关闭后推荐用这个）。
  void showOnOverlay(
    OverlayState overlay,
    Gift gift, {
    int comboCount = 1,
    MoeVfxProfile? vfxProfile,
  }) {
    _enqueue(
      overlay,
      gift,
      comboCount: comboCount,
      vfxProfile: vfxProfile,
    );
  }

  /// 全局 Navigator 的 root overlay（桌面 / 模拟器稳定）。
  static OverlayState? resolveRootOverlay([BuildContext? context]) {
    return AuthService.navigatorKey.currentState?.overlay ??
        (context != null ? Overlay.maybeOf(context, rootOverlay: true) : null);
  }

  void _enqueue(
    OverlayState overlay,
    Gift gift, {
    required int comboCount,
    BuildContext? context,
    MoeVfxProfile? vfxProfile,
  }) {
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _comboWindow) {
      _comboCount++;
    } else {
      _comboCount = comboCount;
    }
    _lastSendTime = now;

    for (final task in _queue) {
      if (task.gift.id == gift.id) {
        task.comboCount = _comboCount;
        GiftRunwayController().push(
          overlay,
          gift: gift,
          comboCount: _comboCount,
        );
        return;
      }
    }

    final profile = vfxProfile ??
        (context != null
            ? MoeVfxProfile.fromContext(context)
            : MoeVfxProfile.standard);
    if (profile.enableHaptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    PerformanceController().applyVfxProfile(profile);

    GiftRunwayController().push(
      overlay,
      gift: gift,
      comboCount: _comboCount,
    );

    final task = _AnimTask(
      gift: gift,
      overlay: overlay,
      priority: _priorityOf(gift),
      comboCount: _comboCount,
      vfxProfile: profile,
    );

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
    final useLottie =
        FeatureFlags.useLottieGiftEffects && !task.vfxProfile.reduceMotion;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.sizeOf(ctx);
        final effect = useLottie
            ? LottieGiftEffect(
                gift: task.gift,
                comboCount: task.comboCount,
                duration: task.gift.animationDuration,
                vfxProfile: task.vfxProfile,
                onComplete: () {
                  entry.remove();
                  _currentEntry = null;
                  if (!completer.isCompleted) completer.complete();
                },
              )
            : LiveGiftEffect(
                gift: task.gift,
                comboCount: task.comboCount,
                duration: task.gift.animationDuration,
                vfxProfile: task.vfxProfile,
                onComplete: () {
                  entry.remove();
                  _currentEntry = null;
                  if (!completer.isCompleted) completer.complete();
                },
              );

        return Positioned(
          left: 0,
          top: 0,
          width: screen.width,
          height: screen.height,
          child: IgnorePointer(
            child: Material(
              type: MaterialType.transparency,
              child: effect,
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    task.overlay.insert(entry);

    return completer.future.timeout(
      task.gift.animationDuration + const Duration(seconds: 2),
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
    GiftRunwayController().clear();
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
  final OverlayState overlay;
  final int priority;
  final MoeVfxProfile vfxProfile;
  int comboCount;

  _AnimTask({
    required this.gift,
    required this.overlay,
    required this.priority,
    required this.comboCount,
    required this.vfxProfile,
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

  void applyVfxProfile(MoeVfxProfile profile) {
    _animEnabled = !profile.reduceMotion;
    _maxParticles = profile.scaledBurstCount(40);
    _level = switch (profile.tier) {
      MoeVfxTier.low => DevicePerformanceLevel.low,
      MoeVfxTier.standard => DevicePerformanceLevel.medium,
      MoeVfxTier.high => DevicePerformanceLevel.high,
    };
  }
}
