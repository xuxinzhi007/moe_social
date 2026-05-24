import 'dart:async';
import 'package:flutter/foundation.dart';

class StartupTask {
  final String name;
  final Future<void> Function() task;
  final bool critical;

  StartupTask({
    required this.name,
    required this.task,
    this.critical = true,
  });
}

class StartupManager {
  static final StartupManager _instance = StartupManager._internal();
  factory StartupManager() => _instance;
  StartupManager._internal();

  List<StartupTask> _tasks = [];
  Completer<void>? _completer;
  bool _isRunning = false;
  Map<String, bool> _taskResults = {};
  Map<String, dynamic> _taskErrors = {};

  void addTask(StartupTask task) {
    if (_isRunning) {
      throw StateError('Cannot add tasks after startup has started');
    }
    _tasks.add(task);
  }

  void addTasks(List<StartupTask> tasks) {
    if (_isRunning) {
      throw StateError('Cannot add tasks after startup has started');
    }
    _tasks.addAll(tasks);
  }

  Future<void> run({Duration? timeout}) async {
    if (_isRunning) {
      return _completer?.future ?? Future.value();
    }

    _isRunning = true;
    _completer = Completer<void>();
    _taskResults.clear();
    _taskErrors.clear();

    final stopwatch = Stopwatch()..start();

    try {
      final taskGroups = _groupTasksByPriority();
      final backgroundTasks = <StartupTask>[];

      Future<void> runCriticalGroups() async {
        for (final group in taskGroups) {
          final isBackgroundGroup =
              group.isNotEmpty && group.every((task) => !task.critical);
          if (isBackgroundGroup) {
            backgroundTasks.addAll(group);
            continue;
          }

          for (final task in group) {
            await _executeTask(task);
          }
        }
      }

      if (timeout != null) {
        await runCriticalGroups().timeout(timeout);
      } else {
        await runCriticalGroups();
      }

      _checkCriticalTasks();
      _completer?.complete();

      for (final task in backgroundTasks) {
        unawaited(_executeTask(task));
      }

      stopwatch.stop();
      debugPrint('✅ Startup completed in ${stopwatch.elapsedMilliseconds}ms');
      if (backgroundTasks.isNotEmpty) {
        debugPrint(
          '⏳ ${backgroundTasks.length} non-critical task(s) running in background',
        );
      }
      _printTaskResults();
    } catch (e) {
      stopwatch.stop();
      debugPrint(
          '❌ Startup failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      _completer?.completeError(e);
      rethrow;
    }

    return _completer?.future ?? Future.value();
  }

  List<List<StartupTask>> _groupTasksByPriority() {
    final criticalTasks = _tasks.where((t) => t.critical).toList();
    final nonCriticalTasks = _tasks.where((t) => !t.critical).toList();
    // 关键任务逐个 await，避免「API Config」与「Auth Service」并行时
    // Auth 先起 WebSocket 仍读到默认 local(127.0.0.1)。
    return [
      for (final t in criticalTasks) [t],
      if (nonCriticalTasks.isNotEmpty) nonCriticalTasks,
    ];
  }

  Future<void> _executeTask(StartupTask task) async {
    final taskStopwatch = Stopwatch()..start();
    try {
      await task.task();
      _taskResults[task.name] = true;
      taskStopwatch.stop();
      debugPrint('   ✅ ${task.name}: ${taskStopwatch.elapsedMilliseconds}ms');
    } catch (e, stack) {
      _taskResults[task.name] = false;
      _taskErrors[task.name] = {'error': e, 'stack': stack};
      taskStopwatch.stop();
      debugPrint(
          '   ❌ ${task.name}: ${taskStopwatch.elapsedMilliseconds}ms - $e');

      if (task.critical) {
        rethrow;
      }
    }
  }

  void _checkCriticalTasks() {
    final failedCritical = _tasks
        .where((t) => t.critical && _taskResults[t.name] == false)
        .map((t) => t.name)
        .toList();

    if (failedCritical.isNotEmpty) {
      throw StateError(
          'Critical startup tasks failed: ${failedCritical.join(', ')}');
    }
  }

  void _printTaskResults() {
    final successCount = _taskResults.values.where((v) => v).length;
    final totalCount = _taskResults.length;
    debugPrint(
        '📊 Startup Summary: $successCount/$totalCount tasks completed successfully');

    if (_taskErrors.isNotEmpty) {
      debugPrint('⚠️  Non-critical task errors:');
      _taskErrors.forEach((name, error) {
        debugPrint('   - $name: ${error['error']}');
      });
    }
  }

  bool get isRunning => _isRunning;
  Map<String, bool> get taskResults => Map.unmodifiable(_taskResults);
  Map<String, dynamic> get taskErrors => Map.unmodifiable(_taskErrors);

  void reset() {
    _tasks.clear();
    _completer = null;
    _isRunning = false;
    _taskResults.clear();
    _taskErrors.clear();
  }
}
