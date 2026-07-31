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
    this.postId,
    this.fullBody,
    this.memoryId,
  });

  /// `world` | `moment` | `post` | `chat` | `memory`
  final String kind;
  final String title;
  final String body;
  final DateTime? at;

  /// `post` 深链用。
  final String? postId;

  /// `memory` 全文（body 可能截断）。
  final String? fullBody;

  /// `memory` 深链到记忆专页。
  final int? memoryId;
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
  bool _worldBound = false;
  String _worldBindStatus = 'unbound';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  CompanionProfileData get profile => _profile;
  CompanionStateData get state => _state;
  List<CompanionDailyItem> get dailyItems => _dailyItems;
  String get worldSummaryLine => _worldSummaryLine;

  /// 是否已绑定世界居民（以 profile.life_entity_id > 0 为准）。
  bool get worldBound => _worldBound;

  /// unbound | bound_ok | bound_missing
  String get worldBindStatus => _worldBindStatus;

  bool get worldBindMissing =>
      _worldBound && _worldBindStatus == 'bound_missing';

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
      var worldBound = snapshot.profile.lifeEntityId > 0;
      var bindStatus = snapshot.profile.worldBindStatus;
      if (bindStatus.isEmpty) {
        bindStatus = worldBound ? 'bound_ok' : 'unbound';
      }
      if (snapshot.state.worldBindStatus.isNotEmpty) {
        bindStatus = snapshot.state.worldBindStatus;
      }

      // 后端 moments 优先（life_event_logs，含离场居民历史）；无则回退 Life 事件。
      final momentItems = _momentDailyItems(snapshot.state.moments);
      if (momentItems.isNotEmpty) {
        daily.addAll(momentItems);
      }

      if (FeatureFlags.showLifeEngine) {
        try {
          final life = await LifeService.getInitialState();
          // 绑定 SSOT = profile.life_entity_id；勿因 Life 列表短暂为空/未同步而降级为「未绑定」。
          worldBound = snapshot.profile.lifeEntityId > 0;
          worldLine = _buildWorldSummaryLine(
            life,
            snapshot.profile.lifeEntityId,
            profileName: snapshot.profile.name,
            profileEmoji: snapshot.profile.emoji,
            bindStatus: bindStatus,
            entityAlive: snapshot.state.entityAlive,
          );
          if (momentItems.isEmpty) {
            daily.addAll(_worldDailyItems(life, snapshot.profile.lifeEntityId));
          }
        } catch (_) {
          if (worldBound) {
            final who = snapshot.profile.name.trim().isNotEmpty
                ? snapshot.profile.name.trim()
                : 'TA';
            worldLine = bindStatus == 'bound_missing'
                ? '$who 绑定还在 · 居民暂时不在舞台'
                : '$who 已绑定 · 点进世界看看';
          }
        }
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
                postId: post.id,
              ),
            );
          }
        } catch (_) {}
      }

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
      _worldBound = worldBound;
      _worldBindStatus = bindStatus;
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

  /// WS 实时问候/状态补丁（不全量刷新日常流）。
  void applyLivePresence({
    String? greeting,
    String? moodThought,
    String? activityLabel,
  }) {
    if (_disposed) return;
    final next = _state.copyWith(
      greeting: (greeting != null && greeting.trim().isNotEmpty)
          ? greeting.trim()
          : null,
      moodThought: (moodThought != null && moodThought.trim().isNotEmpty)
          ? moodThought.trim()
          : null,
      activityLabel: (activityLabel != null && activityLabel.trim().isNotEmpty)
          ? activityLabel.trim()
          : null,
    );
    if (identical(next, _state) ||
        (next.greeting == _state.greeting &&
            next.moodThought == _state.moodThought &&
            next.activityLabel == _state.activityLabel)) {
      return;
    }
    _state = next;
    _notify();
  }

  static LifeEntity? _findBoundEntity(LifeInitialState life, int lifeEntityId) {
    if (lifeEntityId <= 0) return null;
    for (final e in life.entities) {
      if (e.id == lifeEntityId) return e;
    }
    return null;
  }

  static String _buildWorldSummaryLine(
    LifeInitialState life,
    int lifeEntityId, {
    String profileName = '',
    String profileEmoji = '',
    String bindStatus = 'unbound',
    bool entityAlive = true,
  }) {
    final bound = _findBoundEntity(life, lifeEntityId);
    if (bound != null) {
      final action = bound.action.trim().isEmpty ? '发呆' : bound.action.trim();
      return '${bound.emoji} ${bound.name} · $action · ${bound.growthStageLabel}';
    }
    final who = profileName.trim().isNotEmpty ? profileName.trim() : 'TA';
    final emoji = profileEmoji.trim();
    // 已绑定但本轮 Life 列表未带回实体：区分「同步中」与「居民失踪/离场」。
    if (lifeEntityId > 0) {
      final head = emoji.isNotEmpty ? '$emoji $who' : who;
      if (bindStatus == 'bound_missing' || !entityAlive) {
        return '$head 绑定还在 · 居民暂时不在舞台，点进世界可改绑';
      }
      if (life.entities.isEmpty) {
        return '$head 已绑定 · 世界同步中';
      }
      return '$head 已绑定 · 点地图可切换居民';
    }
    if (life.entities.isEmpty) {
      return '世界还很安静';
    }
    return '点进世界，选一位居民设为$who的伙伴';
  }

  static List<CompanionDailyItem> _momentDailyItems(
    List<CompanionMomentData> moments,
  ) {
    return moments
        .where((m) => m.text.trim().isNotEmpty)
        .take(8)
        .map(
          (m) => CompanionDailyItem(
            kind: 'moment',
            title: m.timeLabel.trim().isNotEmpty ? m.timeLabel.trim() : '近况',
            body: m.text.trim(),
          ),
        )
        .toList(growable: false);
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
        fullBody: e.content.trim(),
      );
    }).toList(growable: false);
  }

  static List<CompanionDailyItem> _memoryDailyItems(
    List<CompanionMemoryData> memories,
  ) {
    return memories.where((m) => m.content.trim().isNotEmpty).take(3).map(
      (m) {
        final text = m.content.trim();
        return CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: _clip(text, 96),
          at: DateTime.tryParse(m.createdAt),
          fullBody: text,
          memoryId: m.id > 0 ? m.id : null,
        );
      },
    ).toList(growable: false);
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
