import 'package:flutter/foundation.dart';

import '../../constants/feature_flags.dart';
import '../../models/life_state.dart';
import '../../models/post.dart';
import '../../services/companion_service.dart';
import '../../services/life_service.dart';
import '../../services/post_service.dart';

/// 关系首页「TA 的日常」一条。
class CompanionDailyItem {
  const CompanionDailyItem({
    required this.kind,
    required this.title,
    required this.body,
    this.at,
  });

  /// `world` | `post` | `chat` | `memory`
  final String kind;
  final String title;
  final String body;
  final DateTime? at;
}

/// AI 伙伴关系首页状态（陪伴为主，世界/动态为日常流）。
class CompanionHubViewModel extends ChangeNotifier {
  CompanionHubViewModel({CompanionService? companionService})
      : _companion = companionService ?? CompanionService();

  final CompanionService _companion;

  bool _isLoading = true;
  String? _loadError;
  CompanionProfileData _profile = const CompanionProfileData();
  CompanionStateData _state = const CompanionStateData();
  List<CompanionDailyItem> _dailyItems = const [];
  String _worldSummaryLine = '';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  CompanionProfileData get profile => _profile;
  CompanionStateData get state => _state;
  List<CompanionDailyItem> get dailyItems => _dailyItems;
  String get worldSummaryLine => _worldSummaryLine;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _loadError = null;
    _notify();

    try {
      final snapshot = await _companion.getSnapshot();

      CompanionCommunityIdentityData? identity;
      if (snapshot.profile.agentId.trim().isNotEmpty) {
        try {
          identity = await _companion.getCommunityIdentity();
        } catch (_) {}
      }

      final daily = <CompanionDailyItem>[];
      var worldLine = '';

      if (FeatureFlags.showLifeEngine) {
        try {
          final life = await LifeService.getInitialState();
          worldLine = _buildWorldSummaryLine(life, snapshot.profile.lifeEntityId);
          daily.addAll(_worldDailyItems(life, snapshot.profile.lifeEntityId));
        } catch (_) {}
      }

      if (identity != null && identity.isValid) {
        try {
          final result = await PostService.getPosts(
            page: 1,
            pageSize: 5,
            authorUserId: identity.userId,
          );
          final raw = result['posts'];
          final posts = raw is List<Post>
              ? raw
              : (raw is List
                  ? raw.whereType<Post>().toList(growable: false)
                  : const <Post>[]);
          for (final post in posts) {
            final text = post.content.trim();
            if (text.isEmpty) continue;
            daily.add(
              CompanionDailyItem(
                kind: 'post',
                title: '发了动态',
                body: text,
                at: post.createdAt,
              ),
            );
          }
        } catch (_) {}
      }

      // 二期：聊天高光 + 记忆碎片并入日常流（不再单独铺记忆列表）。
      try {
        final history = await _companion.listChatHistory(limit: 12);
        daily.addAll(_chatHighlightItems(history));
      } catch (_) {}

      try {
        final memories = await _companion.listMemories(limit: 4);
        daily.addAll(_memoryDailyItems(memories));
      } catch (_) {}

      daily.sort((a, b) {
        final at = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

      if (_disposed) return;
      _profile = snapshot.profile;
      _state = snapshot.state;
      _dailyItems = daily.take(16).toList(growable: false);
      _worldSummaryLine = worldLine;
      _isLoading = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _loadError = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      _notify();
    }
  }

  Future<void> applyUpdatedProfile(CompanionProfileData profile) async {
    final result = await _companion.updateProfile(profile);
    if (_disposed) return;
    _profile = result;
    _notify();
    await loadDashboard();
  }

  static String _buildWorldSummaryLine(LifeInitialState life, int lifeEntityId) {
    LifeEntity? bound;
    if (lifeEntityId > 0) {
      for (final e in life.entities) {
        if (e.id == lifeEntityId) {
          bound = e;
          break;
        }
      }
    }
    bound ??= life.entities.isNotEmpty ? life.entities.first : null;
    if (bound == null) {
      return life.summary.entityCount > 0
          ? '世界里有 ${life.summary.entityCount} 位生命在活动'
          : '世界还很安静';
    }
    final action = bound.action.trim().isEmpty ? '发呆' : bound.action.trim();
    return '${bound.emoji} ${bound.name} 正在$action · ${bound.growthStageLabel}';
  }

  static List<CompanionDailyItem> _worldDailyItems(
    LifeInitialState life,
    int lifeEntityId,
  ) {
    final events = life.events;
    if (events.isEmpty) return const [];

    Iterable<LifeEvent> filtered = events;
    if (lifeEntityId > 0) {
      final mine = events.where((e) => e.entityId == lifeEntityId).toList();
      if (mine.isNotEmpty) filtered = mine;
    }

    final sorted = filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sorted.take(6).map((e) {
      final desc = e.desc.trim().isNotEmpty ? e.desc.trim() : e.type;
      return CompanionDailyItem(
        kind: 'world',
        title: '世界近况',
        body: desc,
        at: e.timestamp,
      );
    }).toList(growable: false);
  }

  /// 优先展示伙伴侧发言，作为「和你聊过」的高光。
  static List<CompanionDailyItem> _chatHighlightItems(
    List<CompanionChatLogData> history,
  ) {
    final assistant = history
        .where((e) => e.role != 'user' && e.content.trim().isNotEmpty)
        .toList(growable: false);
    final source = assistant.isNotEmpty
        ? assistant
        : history.where((e) => e.content.trim().isNotEmpty).toList();

    return source.take(4).map((e) {
      final isUser = e.role == 'user';
      return CompanionDailyItem(
        kind: 'chat',
        title: isUser ? '你说过' : '和你聊过',
        body: _clip(e.content.trim(), 96),
        at: DateTime.tryParse(e.createdAt),
      );
    }).toList(growable: false);
  }

  static List<CompanionDailyItem> _memoryDailyItems(
    List<CompanionMemoryData> memories,
  ) {
    return memories
        .where((m) => m.content.trim().isNotEmpty)
        .take(3)
        .map(
          (m) => CompanionDailyItem(
            kind: 'memory',
            title: '记得的事',
            body: _clip(m.content.trim(), 96),
            at: DateTime.tryParse(m.createdAt),
          ),
        )
        .toList(growable: false);
  }

  static String _clip(String text, int maxChars) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ');
    if (oneLine.length <= maxChars) return oneLine;
    return '${oneLine.substring(0, maxChars)}…';
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
