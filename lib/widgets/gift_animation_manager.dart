import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift.dart';
import 'optimized_gift_animation.dart';

enum AnimationPriority {
  low,
  normal,
  high,
  luxury,
}

class AnimationTask {
  final Gift gift;
  final AnimationPriority priority;
  final DateTime timestamp;
  int comboCount;

  AnimationTask({
    required this.gift,
    this.priority = AnimationPriority.normal,
    this.comboCount = 1,
  }) : timestamp = DateTime.now();

  int get priorityValue {
    switch (priority) {
      case AnimationPriority.low:
        return 0;
      case AnimationPriority.normal:
        return 1;
      case AnimationPriority.high:
        return 2;
      case AnimationPriority.luxury:
        return 3;
    }
  }
}

class GiftAnimationManager {
  static final GiftAnimationManager _instance = GiftAnimationManager._internal();
  factory GiftAnimationManager() => _instance;
  GiftAnimationManager._internal();

  final List<AnimationTask> _animationQueue = [];
  bool _isPlaying = false;
  int _comboCount = 0;
  DateTime? _lastAnimationTime;
  static const _comboTimeWindow = Duration(seconds: 3);
  static const _minIntervalBetweenAnimations = Duration(milliseconds: 200);

  AnimationTask? _currentTask;
  DateTime? _lastAnimationEndTime;

  int get comboCount => _comboCount;
  bool get isPlaying => _isPlaying;
  int get queueLength => _animationQueue.length;

  void _updateCombo() {
    final now = DateTime.now();
    if (_lastAnimationTime != null &&
        now.difference(_lastAnimationTime!) < _comboTimeWindow) {
      _comboCount++;
    } else {
      _comboCount = 1;
    }
    _lastAnimationTime = now;
  }

  AnimationPriority _getPriorityForGift(Gift gift) {
    switch (gift.level) {
      case GiftLevel.basic:
        return AnimationPriority.low;
      case GiftLevel.medium:
        return AnimationPriority.normal;
      case GiftLevel.advanced:
        return AnimationPriority.high;
      case GiftLevel.luxury:
        return AnimationPriority.luxury;
    }
  }

  void addAnimation(Gift gift) {
    _updateCombo();

    final priority = _getPriorityForGift(gift);
    
    final now = DateTime.now();
    if (_currentTask != null && 
        _currentTask!.gift.id == gift.id &&
        _lastAnimationEndTime != null &&
        now.difference(_lastAnimationEndTime!) < _comboTimeWindow) {
      _currentTask!.comboCount++;
      return;
    }

    for (var task in _animationQueue) {
      if (task.gift.id == gift.id) {
        task.comboCount++;
        return;
      }
    }

    final task = AnimationTask(
      gift: gift,
      priority: priority,
      comboCount: _comboCount,
    );

    if (_animationQueue.isEmpty) {
      _animationQueue.add(task);
    } else {
      int insertIndex = _animationQueue.length;
      for (int i = 0; i < _animationQueue.length; i++) {
        if (task.priorityValue > _animationQueue[i].priorityValue) {
          insertIndex = i;
          break;
        }
      }
      _animationQueue.insert(insertIndex, task);
    }

    if (!_isPlaying) {
      _startPlaying();
    }
  }

  void _startPlaying() {
    if (_isPlaying) return;
    _playNextAnimation();
  }

  Future<void> _playNextAnimation() async {
    if (_animationQueue.isEmpty) {
      _isPlaying = false;
      _currentTask = null;
      return;
    }

    _isPlaying = true;
    _currentTask = _animationQueue.removeAt(0);

    if (_lastAnimationEndTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastAnimationEndTime!);
      if (elapsed < _minIntervalBetweenAnimations) {
        await Future.delayed(_minIntervalBetweenAnimations - elapsed);
      }
    }

    await _executeAnimation(_currentTask!);
    _lastAnimationEndTime = DateTime.now();

    _playNextAnimation();
  }

  Future<void> _executeAnimation(AnimationTask task) async {
    final completer = Completer<void>();
    
    if (_currentContext != null) {
      showDialog(
        context: _currentContext!,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (ctx) => Center(
          child: OptimizedGiftAnimation(
            gift: task.gift,
            comboCount: task.comboCount,
            onAnimationComplete: () {
              Navigator.of(ctx).pop();
              completer.complete();
            },
          ),
        ),
      );
    } else {
      await Future.delayed(task.gift.animationDuration);
      completer.complete();
    }

    return completer.future;
  }

  AnimationTask? getNextAnimation() {
    if (_animationQueue.isEmpty) {
      return null;
    }
    return _animationQueue.removeAt(0);
  }

  void clearQueue() {
    _animationQueue.clear();
    _comboCount = 0;
  }

  void startPlaying() {
    _isPlaying = true;
  }

  void stopPlaying() {
    _isPlaying = false;
    _comboCount = 0;
    _animationQueue.clear();
    _currentTask = null;
  }

  bool shouldPlayNext() {
    return _animationQueue.isNotEmpty && !_isPlaying;
  }

  BuildContext? _currentContext;

  void setContext(BuildContext context) {
    _currentContext = context;
  }

  void playAnimationSequence(
    BuildContext context,
    List<Gift> gifts, {
    VoidCallback? onComplete,
  }) {
    _currentContext = context;
    
    if (gifts.isEmpty) {
      onComplete?.call();
      return;
    }

    _isPlaying = true;
    _playNextGiftInSequence(context, gifts, 0, onComplete);
  }

  void _playNextGiftInSequence(
    BuildContext context,
    List<Gift> gifts,
    int index,
    VoidCallback? onComplete,
  ) {
    if (index >= gifts.length) {
      _isPlaying = false;
      onComplete?.call();
      return;
    }

    final navigatorState = Navigator.of(context, rootNavigator: true);
    final gift = gifts[index];
    
    navigatorState.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, animation, secondaryAnimation) => Center(
          child: OptimizedGiftAnimation(
            gift: gift,
            duration: gift.animationDuration,
            onAnimationComplete: () {
              navigatorState.pop();
            },
          ),
        ),
      ),
    ).then((_) {
      Future.delayed(_minIntervalBetweenAnimations, () {
        if (navigatorState.mounted) {
          _playNextGiftInSequence(navigatorState.context, gifts, index + 1, onComplete);
        }
      });
    });
  }

  Map<String, dynamic> getPerformanceStats() {
    return {
      'queueLength': _animationQueue.length,
      'isPlaying': _isPlaying,
      'comboCount': _comboCount,
      'lastAnimationTime': _lastAnimationTime?.toIso8601String(),
      'currentTask': _currentTask?.gift.name,
    };
  }

  void resetCombo() {
    _comboCount = 0;
    _lastAnimationTime = null;
  }
}

class PerformanceController {
  static final PerformanceController _instance = PerformanceController._internal();
  factory PerformanceController() => _instance;
  PerformanceController._internal();

  DevicePerformanceLevel _performanceLevel = DevicePerformanceLevel.medium;
  bool _animationEnabled = true;
  int _maxParticles = 40;
  double _animationSpeed = 1.0;

  DevicePerformanceLevel get performanceLevel => _performanceLevel;
  bool get animationEnabled => _animationEnabled;
  int get maxParticles => _maxParticles;
  double get animationSpeed => _animationSpeed;

  void setPerformanceLevel(DevicePerformanceLevel level) {
    _performanceLevel = level;
    _applyPerformanceSettings();
  }

  void _applyPerformanceSettings() {
    switch (_performanceLevel) {
      case DevicePerformanceLevel.low:
        _maxParticles = 10;
        _animationSpeed = 0.8;
        break;
      case DevicePerformanceLevel.medium:
        _maxParticles = 25;
        _animationSpeed = 1.0;
        break;
      case DevicePerformanceLevel.high:
        _maxParticles = 40;
        _animationSpeed = 1.0;
        break;
    }
  }

  void setAnimationEnabled(bool enabled) {
    _animationEnabled = enabled;
  }

  int getAdjustedParticleCount(int baseCount) {
    if (baseCount <= _maxParticles) {
      return baseCount;
    }
    return _maxParticles;
  }

  Duration getAdjustedDuration(Duration baseDuration) {
    final milliseconds = (baseDuration.inMilliseconds / _animationSpeed).round();
    return Duration(milliseconds: milliseconds);
  }

  void autoDetectPerformanceLevel() {
    _performanceLevel = DevicePerformanceLevel.medium;
    _applyPerformanceSettings();
  }
}

enum DevicePerformanceLevel {
  low,
  medium,
  high,
}
