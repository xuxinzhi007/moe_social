import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../constants/feature_flags.dart';
import '../../models/life_state.dart';
import '../../models/post.dart';
import '../../services/companion_service.dart';
import '../../services/companion_interaction_coordinator.dart';
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

  /// `world` | `moment` | `post` | `chat` | `memory` | `relationship` | `topic`
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

class CompanionPulseData {
  const CompanionPulseData({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.kind,
    this.memoryId,
    this.postId,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final String kind;
  final int? memoryId;
  final String? postId;
}

class CompanionDailySummaryData {
  const CompanionDailySummaryData({
    required this.title,
    required this.body,
    required this.sceneLabel,
    this.continuationHint,
  });

  final String title;
  final String body;
  final String sceneLabel;
  final String? continuationHint;
}

/// AI 伙伴关系首页状态（陪伴为主，世界/动态为日常流）。
class CompanionHubViewModel extends ChangeNotifier {
  CompanionHubViewModel({
    CompanionService? companionService,
    CompanionInteractionCoordinator? coordinator,
  })  : _companion = companionService ?? CompanionService(),
        _coordinator = coordinator ?? CompanionInteractionCoordinator.instance {
    _interactionSubscription = _coordinator.events.listen(_onInteraction);
  }

  final CompanionService _companion;
  final CompanionInteractionCoordinator _coordinator;
  late final StreamSubscription<CompanionInteractionEvent>
      _interactionSubscription;

  bool _isLoading = true;
  String? _loadError;
  CompanionProfileData _profile = const CompanionProfileData();
  CompanionStateData _state = const CompanionStateData();
  List<CompanionDailyItem> _dailyItems = const [];
  CompanionDailySummaryData? _dailySummary;
  String _worldSummaryLine = '';
  bool _worldBound = false;
  String _worldBindStatus = 'unbound';
  bool _disposed = false;
  bool _refreshQueued = false;
  bool _dashboardRequestInFlight = false;
  bool _refreshAfterDashboard = false;
  Timer? _interactionRefreshTimer;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  CompanionProfileData get profile => _profile;
  CompanionStateData get state => _state;
  List<CompanionDailyItem> get dailyItems => _dailyItems;
  CompanionDailySummaryData? get dailySummary => _dailySummary;
  CompanionDailyItem? get latestDailyItem =>
      _dailyItems.isNotEmpty ? _dailyItems.first : null;
  String get worldSummaryLine => _worldSummaryLine;

  /// 是否已绑定世界居民（以 profile.life_entity_id > 0 为准）。
  bool get worldBound => _worldBound;

  /// unbound | bound_ok | bound_missing
  String get worldBindStatus => _worldBindStatus;

  bool get worldBindMissing =>
      _worldBound && _worldBindStatus == 'bound_missing';

  static CompanionPulseData buildPulseData({
    required CompanionProfileData profile,
    required CompanionStateData state,
    required List<CompanionDailyItem> dailyItems,
    required bool hasAttention,
  }) {
    final leadItem = dailyItems.isNotEmpty ? dailyItems.first : null;
    final greeting = state.greeting.trim();
    final mood = state.moodThought.trim();
    final activity = state.activityLabel.trim();

    if (hasAttention) {
      final who = profile.name.trim().isNotEmpty ? profile.name.trim() : 'TA';
      final body = greeting.isNotEmpty
          ? greeting
          : (mood.isNotEmpty ? mood : 'TA 正在等你来聊聊。');
      return CompanionPulseData(
        title: '$who 想和你说',
        body: body,
        ctaLabel: '去聊天',
        kind: 'attention',
      );
    }

    if (leadItem == null) {
      final who = profile.name.trim().isNotEmpty ? profile.name.trim() : 'TA';
      final fallback = greeting.isNotEmpty
          ? greeting
          : (mood.isNotEmpty ? mood : '$who 今天先陪你聊聊，看看最近的变化。');
      return CompanionPulseData(
        title: '今天的 TA',
        body: fallback,
        ctaLabel: '开始聊天',
        kind: 'idle',
      );
    }

    switch (leadItem.kind) {
      case 'memory':
        return CompanionPulseData(
          title: 'TA 记得的事',
          body: leadItem.body,
          ctaLabel: '看记忆',
          kind: leadItem.kind,
          memoryId: leadItem.memoryId,
        );
      case 'world':
      case 'moment':
        return CompanionPulseData(
          title: activity.isNotEmpty ? activity : 'TA 的近况',
          body: leadItem.body,
          ctaLabel: '去世界',
          kind: leadItem.kind,
        );
      case 'post':
        return CompanionPulseData(
          title: 'TA 刚发了动态',
          body: leadItem.body,
          ctaLabel: '看动态',
          kind: leadItem.kind,
          postId: leadItem.postId,
        );
      case 'chat':
        return CompanionPulseData(
          title: '刚聊过的话',
          body: leadItem.body,
          ctaLabel: '继续聊天',
          kind: leadItem.kind,
        );
      case 'topic':
        return CompanionPulseData(
          title: '未完成的话题',
          body: leadItem.body,
          ctaLabel: '继续聊天',
          kind: leadItem.kind,
        );
      default:
        return CompanionPulseData(
          title: '今天的 TA',
          body: leadItem.body,
          ctaLabel: '继续陪伴',
          kind: leadItem.kind,
          memoryId: leadItem.memoryId,
          postId: leadItem.postId,
        );
    }
  }

  Future<void> loadDashboard() async {
    if (_dashboardRequestInFlight) {
      _refreshAfterDashboard = true;
      return;
    }
    _dashboardRequestInFlight = true;
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
        daily.addAll(_unfinishedTopicItems(history));
      } catch (_) {}

      try {
        final memories = await _companion.listMemories(limit: 4);
        daily.addAll(_memoryDailyItems(memories));
      } catch (_) {}

      try {
        final events = await _companion.listTimeline(limit: 12);
        daily.addAll(_unifiedEventDailyItems(events));
      } catch (_) {}

      daily.sort((a, b) {
        final at = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      final compressedDaily = _compressDailyItems(daily);
      final dailySummary = _buildDailySummary(
        profile: snapshot.profile,
        state: snapshot.state,
        dailyItems: compressedDaily,
      );

      if (_disposed) return;
      _profile = snapshot.profile;
      _state = snapshot.state;
      _dailyItems = compressedDaily.take(16).toList(growable: false);
      _dailySummary = dailySummary;
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
    } finally {
      _dashboardRequestInFlight = false;
      if (_refreshAfterDashboard && !_disposed) {
        _refreshAfterDashboard = false;
        _scheduleInteractionRefresh();
      }
    }
  }

  void _onInteraction(CompanionInteractionEvent event) {
    if (_disposed || event.type == CompanionInteractionType.presenceChanged) {
      return;
    }
    if (_refreshQueued) return;
    _refreshQueued = true;
    _scheduleInteractionRefresh();
  }

  void _scheduleInteractionRefresh() {
    _interactionRefreshTimer?.cancel();
    _interactionRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      _refreshQueued = false;
      if (!_disposed) unawaited(loadDashboard());
    });
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

  static List<CompanionDailyItem> _unfinishedTopicItems(
    List<CompanionChatLogData> history,
  ) {
    final seen = <String>{};
    final items = <CompanionDailyItem>[];
    for (var index = history.length - 1;
        index >= 0 && items.length < 3;
        index--) {
      final entry = history[index];
      if (entry.role != 'user') continue;
      final text = entry.content.trim();
      if (text.isEmpty || !_hasUnfinishedTopicMarker(text)) continue;
      final key = text.toLowerCase();
      if (!seen.add(key)) continue;
      items.add(
        CompanionDailyItem(
          kind: 'topic',
          title: '未完成的话题',
          body: _clip(text, 96),
          fullBody: text,
          at: DateTime.tryParse(entry.createdAt),
        ),
      );
    }
    return items;
  }

  static bool _hasUnfinishedTopicMarker(String value) {
    const markers = <String>[
      '下次',
      '之后',
      '以后',
      '继续',
      '还没',
      '未完',
      '计划',
      '准备',
      '打算',
      'todo',
      'follow up',
    ];
    final normalized = value.toLowerCase();
    return markers.any(normalized.contains);
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

  static List<CompanionDailyItem> _unifiedEventDailyItems(
    List<CompanionEventData> events,
  ) {
    return events
        .take(6)
        .map((event) {
          final payload = _decodeEventPayload(event.payloadJson);
          final relationshipTitle = payload['title']?.toString().trim() ?? '';
          final relationshipBody = payload['content']?.toString().trim() ?? '';
          final eventType = event.eventType;
          String kind;
          String title;
          String body;
          switch (eventType) {
            case 'first_chat':
            case 'level_up':
            case 'relationship_level_up':
              kind = 'relationship';
              title = relationshipTitle.isEmpty ? '关系有新变化' : relationshipTitle;
              body = relationshipBody;
              break;
            case 'chat_turn_completed':
              kind = 'chat';
              title = '刚聊过的事';
              body = payload['input_mode']?.toString() == 'voice'
                  ? '语音对话已完成'
                  : '对话已完成';
              break;
            case 'voice_turn_completed':
              kind = 'chat';
              title = '语音陪伴';
              body = '语音互动已完成';
              break;
            case 'memory_created':
            case 'memory_updated':
            case 'memory_confirmed':
            case 'memory_corrected':
            case 'memory_pinned_changed':
            case 'memory_deleted':
            case 'memory_conflict_detected':
            case 'memory_conflict_resolved':
              kind = 'memory';
              title = '记忆有更新';
              body = payload['memory_key']?.toString().trim() ?? '';
              if (body.isEmpty) body = eventType.replaceAll('_', ' ');
              break;
            case 'life_moment_created':
            case 'life_care_completed':
              kind = 'world';
              title = 'Life 有新动态';
              body = payload['description']?.toString().trim() ?? '';
              if (body.isEmpty) {
                body = payload['life_event_type']?.toString().trim() ?? '';
              }
              break;
            case 'post_created':
            case 'post_liked':
            case 'comment_created':
            case 'comment_liked':
              kind = 'post';
              title = '社交有新动态';
              body = eventType.replaceAll('_', ' ');
              break;
            case 'friend_request_sent':
              kind = 'relationship';
              title = '发出了好友申请';
              body = '等待对方回应';
              break;
            case 'friend_request_received':
              kind = 'relationship';
              title = '收到好友申请';
              body = '去好友页查看';
              break;
            case 'friend_request_accepted':
              kind = 'relationship';
              title = '好友申请已接受';
              body = '关系有了新的进展';
              break;
            case 'friend_request_rejected':
              kind = 'relationship';
              title = '好友申请已处理';
              body = '关系状态已同步';
              break;
            case 'follow_created':
              kind = 'relationship';
              title = '你关注了一位用户';
              body = '已写入关系时间线';
              break;
            case 'follow_removed':
              kind = 'relationship';
              title = '你取消了关注';
              body = '关系状态已同步';
              break;
            case 'proactive_delivered':
              kind = 'relationship';
              title = 'TA 主动联系你了';
              body = payload['reason']?.toString().trim() ?? '';
              break;
            default:
              return null;
          }
          if (title.isEmpty && body.isEmpty) return null;
          return CompanionDailyItem(
            kind: kind,
            title: title,
            body: body,
            at: DateTime.tryParse(
              event.occurredAt.isNotEmpty ? event.occurredAt : event.createdAt,
            ),
            fullBody: body,
            memoryId:
                kind == 'memory' && event.sourceId > 0 ? event.sourceId : null,
          );
        })
        .whereType<CompanionDailyItem>()
        .toList(growable: false);
  }

  static Map<String, dynamic> _decodeEventPayload(String value) {
    if (value.trim().isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static CompanionDailySummaryData? _buildDailySummary({
    required CompanionProfileData profile,
    required CompanionStateData state,
    required List<CompanionDailyItem> dailyItems,
  }) {
    if (dailyItems.isEmpty && state.moodThought.trim().isEmpty) return null;

    final relationship = dailyItems.cast<CompanionDailyItem?>().firstWhere(
          (item) => item?.kind == 'relationship',
          orElse: () => null,
        );
    final memory = dailyItems.cast<CompanionDailyItem?>().firstWhere(
          (item) => item?.kind == 'memory',
          orElse: () => null,
        );
    final chat = dailyItems.cast<CompanionDailyItem?>().firstWhere(
          (item) => item?.kind == 'chat',
          orElse: () => null,
        );
    final who = profile.name.trim().isNotEmpty ? profile.name.trim() : 'TA';
    final mood = state.moodThought.trim();
    final summaryBody = relationship != null
        ? relationship.body
        : (mood.isNotEmpty ? mood : '$who 今天也在和你保持联系。');
    final continuation = _findContinuationHint(chat?.body);
    final detail = memory != null && memory.body.trim().isNotEmpty
        ? 'TA 还记得：${memory.body.trim()}'
        : null;

    return CompanionDailySummaryData(
      title: relationship?.title ?? '今天的关系摘要',
      body: detail == null ? summaryBody : '$summaryBody\n$detail',
      sceneLabel: _companionSceneLabel(DateTime.now(), state.mood),
      continuationHint: continuation,
    );
  }

  @visibleForTesting
  static List<CompanionDailyItem> unifiedEventDailyItemsForTest(
    List<CompanionEventData> events,
  ) {
    return _unifiedEventDailyItems(events);
  }

  @visibleForTesting
  static String companionSceneLabelForTest(DateTime now, double mood) {
    return _companionSceneLabel(now, mood);
  }

  static String _companionSceneLabel(DateTime now, double mood) {
    final normalizedMood = mood <= 1 ? mood * 100 : mood;
    if (normalizedMood < 40) return '情绪安抚';
    if (now.hour >= 22 || now.hour < 6) return '睡前陪伴';
    if (now.hour < 11) return '早晨问候';
    if (now.weekday >= DateTime.saturday) return '周末陪伴';
    return '日常陪伴';
  }

  @visibleForTesting
  static CompanionDailySummaryData? buildDailySummaryForTest({
    required CompanionProfileData profile,
    required CompanionStateData state,
    required List<CompanionDailyItem> dailyItems,
  }) {
    return _buildDailySummary(
      profile: profile,
      state: state,
      dailyItems: dailyItems,
    );
  }

  static String? _findContinuationHint(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.contains('?') || text.contains('？')) return text;
    const markers = ['下次', '明天', '后来', '记得告诉我', '还好吗'];
    if (markers.any(text.contains)) return text;
    return null;
  }

  static List<CompanionDailyItem> _compressDailyItems(
    List<CompanionDailyItem> items,
  ) {
    if (items.length < 2) return List<CompanionDailyItem>.unmodifiable(items);

    final output = <CompanionDailyItem>[];
    for (final item in items) {
      if (output.isEmpty) {
        output.add(item);
        continue;
      }

      final last = output.last;
      if (_sameDay(last.at, item.at) && last.kind == item.kind) {
        output[output.length - 1] = CompanionDailyItem(
          kind: last.kind,
          title: last.title,
          body: _mergeDailyBody(last.body, item.body),
          at: last.at ?? item.at,
          postId: last.postId ?? item.postId,
          fullBody: _mergeDailyBody(
              last.fullBody ?? last.body, item.fullBody ?? item.body),
          memoryId: last.memoryId ?? item.memoryId,
        );
      } else {
        output.add(item);
      }
    }
    return List<CompanionDailyItem>.unmodifiable(output);
  }

  @visibleForTesting
  static List<CompanionDailyItem> compressDailyItemsForTest(
    List<CompanionDailyItem> items,
  ) {
    return _compressDailyItems(items);
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  static String _mergeDailyBody(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    if (left == right) return left;
    return '$left · $right';
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
    _interactionRefreshTimer?.cancel();
    _interactionSubscription.cancel();
    super.dispose();
  }
}
