import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../services/companion_service.dart';
import '../../services/companion_interaction_coordinator.dart';

/// TA 记得的事 — 列表状态。
class CompanionMemoriesViewModel extends ChangeNotifier {
  CompanionMemoriesViewModel({
    CompanionService? companionService,
    this.focusMemoryId,
  }) : _companion = companionService ?? CompanionService() {
    _interactionSubscription = _coordinator.events.listen(_onInteraction);
  }

  final CompanionService _companion;
  final CompanionInteractionCoordinator _coordinator =
      CompanionInteractionCoordinator.instance;
  StreamSubscription<CompanionInteractionEvent>? _interactionSubscription;
  Timer? _interactionRefreshTimer;

  /// 从日常流点进时滚动/高亮的记忆 id。
  final int? focusMemoryId;

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  List<CompanionMemoryData> _items = const [];
  List<CompanionMemoryConflictData> _conflicts = const [];
  bool _disposed = false;

  bool get isLoading => _loading;
  bool get isMutating => _mutating;
  String? get error => _error;
  List<CompanionMemoryData> get items => _items;
  List<CompanionMemoryConflictData> get conflicts => _conflicts;

  void _onInteraction(CompanionInteractionEvent event) {
    if (_disposed ||
        _mutating ||
        event.type != CompanionInteractionType.companionEvent) {
      return;
    }
    final eventType = event.payload['event_type']?.toString() ?? '';
    const memoryEvents = <String>{
      'memory_created',
      'memory_updated',
      'memory_corrected',
      'memory_confirmed',
      'memory_deleted',
      'memory_pinned_changed',
      'memory_conflict_detected',
      'memory_conflict_resolved',
    };
    if (!memoryEvents.contains(eventType)) return;
    _interactionRefreshTimer?.cancel();
    _interactionRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_disposed && !_mutating) unawaited(load());
    });
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final list = await _companion.listMemories(limit: 40);
      if (_disposed) return;
      _items = list;
      try {
        _conflicts = await _companion.listMemoryConflicts(limit: 40);
      } catch (_) {
        _conflicts = const [];
      }
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      _notify();
    }
  }

  Future<void> resolveConflict(
    CompanionMemoryConflictData conflict,
    String resolution,
  ) async {
    if (_mutating || conflict.id <= 0) return;
    _mutating = true;
    _notify();
    try {
      await _companion.resolveMemoryConflict(
        conflictId: conflict.id,
        resolution: resolution,
      );
      if (_disposed) return;
      _conflicts = _conflicts
          .where((item) => item.id != conflict.id)
          .toList(growable: false);
      if (resolution == 'accepted') {
        final memories = await _companion.listMemories(limit: 40);
        if (!_disposed) _items = memories;
      }
      _coordinator.publishMemoryChanged(
        action: 'conflict_$resolution',
        memoryId: conflict.memoryId,
      );
    } finally {
      if (!_disposed) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<void> deleteMemory(int memoryId) async {
    if (_mutating || memoryId <= 0) return;
    _mutating = true;
    _notify();
    try {
      await _companion.deleteMemory(memoryId);
      if (_disposed) return;
      _items = _items.where((m) => m.id != memoryId).toList(growable: false);
      _coordinator.publishMemoryChanged(action: 'deleted', memoryId: memoryId);
    } finally {
      if (!_disposed) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<CompanionMemoryData> togglePinned(CompanionMemoryData memory) async {
    if (_mutating || memory.id <= 0) {
      return memory;
    }
    _mutating = true;
    _notify();
    try {
      final updated = await _companion.setMemoryPinned(
        memoryId: memory.id,
        pinned: !memory.pinned,
      );
      if (_disposed) return updated;
      _replaceAndSort(updated);
      _coordinator.publishMemoryChanged(
        action: updated.pinned ? 'pinned' : 'unpinned',
        memoryId: updated.id,
      );
      return updated;
    } finally {
      if (!_disposed) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<CompanionMemoryData> updateContent(
    CompanionMemoryData memory,
    String content,
  ) async {
    if (_mutating || memory.id <= 0) {
      return memory;
    }
    _mutating = true;
    _notify();
    try {
      final updated = await _companion.updateMemoryContent(
        memoryId: memory.id,
        content: content,
      );
      if (_disposed) return updated;
      _replaceAndSort(updated);
      _coordinator.publishMemoryChanged(
          action: 'updated', memoryId: updated.id);
      return updated;
    } finally {
      if (!_disposed) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<CompanionMemoryData> confirmMemory(CompanionMemoryData memory) async {
    if (_mutating || memory.id <= 0 || memory.userConfirmed) {
      return memory;
    }
    _mutating = true;
    _notify();
    try {
      final updated = await _companion.confirmMemory(memory.id);
      if (_disposed) return updated;
      _replaceAndSort(updated);
      _coordinator.publishMemoryChanged(
          action: 'confirmed', memoryId: updated.id);
      return updated;
    } finally {
      if (!_disposed) {
        _mutating = false;
        _notify();
      }
    }
  }

  void _replaceAndSort(CompanionMemoryData updated) {
    _items = _items
        .map((m) => m.id == updated.id ? updated : m)
        .toList(growable: true)
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        if (a.importance != b.importance) {
          return b.importance.compareTo(a.importance);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    _items = List<CompanionMemoryData>.unmodifiable(_items);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _interactionRefreshTimer?.cancel();
    _interactionSubscription?.cancel();
    super.dispose();
  }
}

/// 记忆类型展示文案。
String companionMemoryTypeLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case 'preference':
      return '偏好';
    case 'fact':
      return '事实';
    case 'milestone':
      return '里程碑';
    case 'conversation':
      return '对话';
    default:
      return type.trim().isEmpty ? '记忆' : type.trim();
  }
}

String companionMemoryImportanceLabel(int importance) {
  switch (importance) {
    case 2:
      return '长久';
    case 1:
      return '重要';
    default:
      return '日常';
  }
}
