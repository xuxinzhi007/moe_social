import 'package:flutter/foundation.dart';

import '../../services/companion_service.dart';

/// TA 记得的事 — 列表状态。
class CompanionMemoriesViewModel extends ChangeNotifier {
  CompanionMemoriesViewModel({
    CompanionService? companionService,
    this.focusMemoryId,
  }) : _companion = companionService ?? CompanionService();

  final CompanionService _companion;

  /// 从日常流点进时滚动/高亮的记忆 id。
  final int? focusMemoryId;

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  List<CompanionMemoryData> _items = const [];
  bool _disposed = false;

  bool get isLoading => _loading;
  bool get isMutating => _mutating;
  String? get error => _error;
  List<CompanionMemoryData> get items => _items;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final list = await _companion.listMemories(limit: 40);
      if (_disposed) return;
      _items = list;
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      _notify();
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
