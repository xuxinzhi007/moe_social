import 'package:flutter/foundation.dart';

import '../../services/companion_service.dart';
import '../../utils/api_datetime.dart';

/// 历程时间线条目：关系事件 + milestone 记忆合并后的统一视图。
class CompanionJourneyEntry {
  const CompanionJourneyEntry({
    required this.kind,
    required this.title,
    required this.content,
    required this.relationshipLevel,
    required this.at,
  });

  /// first_chat / level_up / milestone_memory / 其他事件类型
  final String kind;
  final String title;
  final String content;
  final int relationshipLevel;
  final DateTime at;
}

class CompanionJourneyViewModel extends ChangeNotifier {
  CompanionJourneyViewModel({CompanionService? companionService})
      : _companion = companionService ?? CompanionService();

  final CompanionService _companion;

  bool _loading = true;
  Object? _error;
  List<CompanionJourneyEntry> _entries = const [];
  bool _disposed = false;

  bool get isLoading => _loading;
  Object? get error => _error;
  List<CompanionJourneyEntry> get entries => _entries;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        _companion.listRelationshipEvents(limit: 50),
        _companion.listMemories(limit: 40),
      ]);
      if (_disposed) return;
      final events = results[0] as List<CompanionRelationshipEventData>;
      final memories = results[1] as List<CompanionMemoryData>;
      final entries = <CompanionJourneyEntry>[
        for (final e in events)
          CompanionJourneyEntry(
            kind: e.eventType,
            title: e.title,
            content: e.content,
            relationshipLevel: e.relationshipLevel,
            at: _parseTime(e.createdAt),
          ),
        for (final m in memories)
          if (m.memoryType.trim().toLowerCase() == 'milestone')
            CompanionJourneyEntry(
              kind: 'milestone_memory',
              title: '共同回忆',
              content: m.content,
              relationshipLevel: 0,
              at: _parseTime(m.createdAt),
            ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      _entries = List.unmodifiable(entries);
      _loading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _error = e;
      _loading = false;
      _notify();
    }
  }

  static DateTime _parseTime(String raw) {
    try {
      return parseApiDateTime(raw);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
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
