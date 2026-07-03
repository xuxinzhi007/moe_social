import 'dart:async';
import 'package:flutter/foundation.dart';

/// AI 助手互动类型
enum AiActivityType { like, comment, recommendation }

/// AI 助手互动数据模型
class AiActivity {
  final String id;
  final AiActivityType type;
  final String summary; // "AI 助手赞了你的动态"
  final String? commentText; // 评论内容（仅 comment 类型）
  final String targetTitle; // 目标动态标题/摘要
  final DateTime timestamp;
  final bool isRead;

  const AiActivity({
    required this.id,
    required this.type,
    required this.summary,
    this.commentText,
    required this.targetTitle,
    required this.timestamp,
    this.isRead = false,
  });
}

/// AI 助手推荐数据模型
class AiRecommendation {
  final String id;
  final String type; // 'user' | 'topic' | 'content'
  final String title;
  final String subtitle;
  final String? avatarUrl;

  const AiRecommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
  });
}

class AiAssistantMockProvider extends ChangeNotifier {
  /// Feature Flag - 控制 AI 助手功能是否启用
  static const bool kAiAssistantEnabled = true;

  /// AI 虚拟用户名
  static const String assistantName = '小萌';
  static const String assistantAvatar = '🤖';

  bool _disposed = false;
  final List<AiActivity> _activities = [];
  final List<AiRecommendation> _recommendations = [];
  final List<Timer> _timers = [];
  Timer? _mockTimer;

  List<AiActivity> get activities => List.unmodifiable(_activities);
  List<AiRecommendation> get recommendations =>
      List.unmodifiable(_recommendations);
  int get unreadCount => _activities.where((a) => !a.isRead).length;

  AiAssistantMockProvider() {
    if (kAiAssistantEnabled) {
      _initMockData();
      _startMockSimulation();
    }
  }

  void _initMockData() {
    _recommendations.addAll([
      const AiRecommendation(
        id: 'rec_1',
        type: 'topic',
        title: '# 今日穿搭分享',
        subtitle: '2.3k 人正在讨论',
      ),
      const AiRecommendation(
        id: 'rec_2',
        type: 'user',
        title: '萌萌酱',
        subtitle: '你们可能有共同兴趣',
      ),
      const AiRecommendation(
        id: 'rec_3',
        type: 'content',
        title: '周末好去处推荐',
        subtitle: '根据你的兴趣为你推荐',
      ),
    ]);

    // 初始 2 条互动
    _activities.addAll([
      AiActivity(
        id: 'act_init_1',
        type: AiActivityType.like,
        summary: '$assistantName 赞了你的动态',
        targetTitle: '今天天气真好，出去走走~',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      AiActivity(
        id: 'act_init_2',
        type: AiActivityType.comment,
        summary: '$assistantName 评论了你的动态',
        commentText: '好棒的生活态度！继续保持哦~ ✨',
        targetTitle: '周末在家做了甜点',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ]);
  }

  /// 模拟 AI 互动延迟触发
  void _startMockSimulation() {
    // 8 秒后模拟一条新的点赞
    _timers.add(Timer(const Duration(seconds: 8), () {
      if (_disposed || !kAiAssistantEnabled) return;
      _activities.insert(
        0,
        AiActivity(
          id: 'act_sim_${DateTime.now().millisecondsSinceEpoch}',
          type: AiActivityType.like,
          summary: '$assistantName 赞了你的动态',
          targetTitle: '分享一首最近单曲循环的歌 🎵',
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    }));

    // 20 秒后模拟一条评论
    _timers.add(Timer(const Duration(seconds: 20), () {
      if (_disposed || !kAiAssistantEnabled) return;
      _activities.insert(
        0,
        AiActivity(
          id: 'act_sim_${DateTime.now().millisecondsSinceEpoch}',
          type: AiActivityType.comment,
          summary: '$assistantName 评论了你的动态',
          commentText: '这首歌我也超喜欢的！旋律太上头了 🎶',
          targetTitle: '分享一首最近单曲循环的歌 🎵',
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    }));
  }

  void markAsRead(String activityId) {
    if (_disposed) return;
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index >= 0 && !_activities[index].isRead) {
      _activities[index] = AiActivity(
        id: _activities[index].id,
        type: _activities[index].type,
        summary: _activities[index].summary,
        commentText: _activities[index].commentText,
        targetTitle: _activities[index].targetTitle,
        timestamp: _activities[index].timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _mockTimer?.cancel();
    super.dispose();
  }
}
