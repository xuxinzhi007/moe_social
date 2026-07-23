import '../models/life_state.dart';
import '../providers/life_provider.dart';

/// AI 伙伴上下文 —— 连接 [LifeProvider] 与社交聊天体验的轻量包装层。
///
/// 将数字生命模拟器的原始数据转化为「社交 App 里的 AI 朋友」语境：
/// - [moodLabel]：心情一句话（模板驱动，不走 LLM）
/// - [activityLabel]：当前在做什么（社交化表达）
/// - [moments]：伙伴的「朋友圈」动态
class CompanionContext {
  final String name;
  final String emoji;
  final String moodLabel;
  final String activityLabel;
  final double mood;
  final double hunger;
  final double energy;
  final List<CompanionMoment> moments;
  final bool hasCompanion;

  const CompanionContext({
    required this.name,
    required this.emoji,
    required this.moodLabel,
    required this.activityLabel,
    required this.mood,
    required this.hunger,
    required this.energy,
    required this.moments,
    required this.hasCompanion,
  });

  /// 从 [LifeProvider] 构建伙伴上下文。
  factory CompanionContext.fromProvider(
    LifeProvider provider, {
    required int? entityId,
  }) {
    final entities = provider.entities;
    if (entities.isEmpty || entityId == null) {
      return const CompanionContext(
        name: '',
        emoji: '🐣',
        moodLabel: '',
        activityLabel: '',
        mood: 0,
        hunger: 0,
        energy: 0,
        moments: [],
        hasCompanion: false,
      );
    }

    LifeEntity? entity;
    for (final candidate in entities) {
      if (candidate.id == entityId) {
        entity = candidate;
        break;
      }
    }
    if (entity == null) {
      return const CompanionContext(
        name: '',
        emoji: '🐣',
        moodLabel: '',
        activityLabel: '',
        mood: 0,
        hunger: 0,
        energy: 0,
        moments: [],
        hasCompanion: false,
      );
    }
    final events = provider.getEventsForEntity(entity.id);

    return CompanionContext(
      name: entity.name,
      emoji: entity.emoji,
      moodLabel: _moodThought(entity),
      activityLabel: _activityPhrase(entity),
      mood: entity.mood,
      hunger: entity.hunger,
      energy: entity.energy,
      moments: _buildMoments(entity, events),
      hasCompanion: true,
    );
  }

  /// 构建注入 LLM system prompt 的状态片段。
  String toSystemPromptFragment() {
    if (!hasCompanion) return '';

    final buf = StringBuffer();
    buf.writeln('[当前状态] 你现在$moodLabel，正在$activityLabel。');

    if (moments.isNotEmpty) {
      buf.writeln('[最近发生] ${moments.take(3).map((m) => m.text).join('；')}');
    }

    return buf.toString();
  }
}

/// 伙伴动态卡片（类朋友圈）
class CompanionMoment {
  final String text;
  final String icon;
  final DateTime time;

  const CompanionMoment({
    required this.text,
    required this.icon,
    required this.time,
  });

  String get timeLabel {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}

// ── 私有工具函数 ──────────────────────────────────────────────────────────

/// 心情一句话（社交化表达，不走 LLM）
String _moodThought(LifeEntity entity) {
  final m = entity.mood;
  final h = entity.hunger;
  final e = entity.energy;

  // 低优先级状态优先表达
  if (h < 20) return '饿得前胸贴后背了';
  if (e < 20) return '困得不行了，好想睡觉';
  if (m < 25) return '有点闷闷不乐';
  if (m < 40) return '心情一般般';

  // 高心情
  if (m > 80) return '心情特别好，感觉今天什么都能聊';
  if (m > 60) return '心情不错，挺开心的';
  return '状态还行，平平淡淡的';
}

/// 当前在做什么（社交化表达）
String _activityPhrase(LifeEntity entity) {
  switch (entity.action) {
    case 'sleeping':
      return '午睡';
    case 'seeking_food':
    case 'eating':
      return '找东西吃';
    case 'wandering':
    case 'walking':
      return '到处逛逛';
    case 'talking':
      return '和朋友聊天';
    case 'seeking_rest':
      return '找个地方休息';
    default:
      // 根据时间段生成
      final hour = DateTime.now().hour;
      if (hour < 6) return '熬夜';
      if (hour < 9) return '吃早餐';
      if (hour < 12) return '忙上午的事';
      if (hour < 14) return '午休';
      if (hour < 18) return '做下午的事';
      if (hour < 21) return '享受傍晚';
      return '待着发呆';
  }
}

/// 从实体状态 + 事件生成伙伴动态
List<CompanionMoment> _buildMoments(
  LifeEntity entity,
  List<LifeEvent> events,
) {
  final moments = <CompanionMoment>[];

  // 从最近事件生成
  for (final event in events.take(3)) {
    if (event.desc.isEmpty) continue;
    moments.add(CompanionMoment(
      text: event.desc,
      icon: _eventIcon(event.type),
      time: event.timestamp,
    ));
  }

  // 如果事件太少，补充状态动态
  if (moments.isEmpty) {
    moments.add(CompanionMoment(
      text: _moodThought(entity),
      icon: entity.mood > 60 ? '😊' : (entity.mood > 35 ? '😐' : '😔'),
      time: DateTime.now(),
    ));
  }

  return moments;
}

String _eventIcon(String type) {
  switch (type) {
    case 'birth':
      return '🎉';
    case 'death':
      return '💔';
    case 'eat':
    case 'food':
      return '🍎';
    case 'sleep':
      return '💤';
    case 'social':
      return '💬';
    case 'growth':
      return '🌱';
    case 'weather':
      return '🌤️';
    default:
      return '✨';
  }
}
