// 数字生命模拟器 - 数据模型
import 'package:flutter/material.dart';

/// 数字生命实体状态
class LifeEntity {
  final int id;
  final String name;
  final String emoji;
  final double hunger;
  final double energy;
  final double mood;
  final String action;
  final double x;
  final double y;
  final String growthStage; // 成长阶段: juvenile/adolescent/adult/elderly
  final double experience;  // 经验值
  final int age;            // 年龄（tick 数）
  final List<ActiveEffectSummary> activeEffects; // 活跃 buff 效果

  const LifeEntity({
    required this.id,
    required this.name,
    required this.emoji,
    this.hunger = 80,
    this.energy = 80,
    this.mood = 70,
    this.action = 'idle',
    this.x = 640,
    this.y = 360,
    this.growthStage = 'juvenile',
    this.experience = 0,
    this.age = 0,
    this.activeEffects = const [],
  });

  factory LifeEntity.fromJson(Map<String, dynamic> json) {
    return LifeEntity(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🐣',
      hunger: _asDouble(json['hunger'], fallback: 80),
      energy: _asDouble(json['energy'], fallback: 80),
      mood: _asDouble(json['mood'], fallback: 70),
      action: json['action']?.toString() ?? 'idle',
      x: _asDouble(json['x'], fallback: 640),
      y: _asDouble(json['y'], fallback: 360),
      growthStage: json['growth_stage']?.toString() ??
          json['growthStage']?.toString() ??
          'juvenile',
      experience: _asDouble(json['experience']),
      age: _asInt(json['age']),
      activeEffects: _parseActiveEffects(json['active_effects'] ?? json['activeEffects']),
    );
  }

  LifeEntity mergeFromJson(Map<String, dynamic> json) {
    return LifeEntity(
      id: id,
      name: json.containsKey('name') ? json['name']?.toString() ?? name : name,
      emoji:
          json.containsKey('emoji') ? json['emoji']?.toString() ?? emoji : emoji,
      hunger: json.containsKey('hunger')
          ? _asDouble(json['hunger'], fallback: hunger)
          : hunger,
      energy: json.containsKey('energy')
          ? _asDouble(json['energy'], fallback: energy)
          : energy,
      mood:
          json.containsKey('mood') ? _asDouble(json['mood'], fallback: mood) : mood,
      action: json.containsKey('action')
          ? json['action']?.toString() ?? action
          : action,
      x: json.containsKey('x') ? _asDouble(json['x'], fallback: x) : x,
      y: json.containsKey('y') ? _asDouble(json['y'], fallback: y) : y,
      growthStage: json.containsKey('growth_stage')
          ? json['growth_stage']?.toString() ?? growthStage
          : json.containsKey('growthStage')
              ? json['growthStage']?.toString() ?? growthStage
              : growthStage,
      experience: json.containsKey('experience')
          ? _asDouble(json['experience'], fallback: experience)
          : experience,
      age: json.containsKey('age') ? _asInt(json['age'], fallback: age) : age,
      activeEffects: json.containsKey('active_effects')
          ? _parseActiveEffects(json['active_effects'])
          : json.containsKey('activeEffects')
              ? _parseActiveEffects(json['activeEffects'])
              : activeEffects,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'sleeping':
        return '休息中';
      case 'seeking_food':
        return '觅食中';
      case 'eating':
        return '进食中';
      case 'wandering':
        return '漫游中';
      case 'walking':
        return '移动中';
      case 'talking':
        return '互动中';
      case 'reproducing':
        return '繁衍中';
      case 'dying':
        return '衰亡中';
      case 'seeking_rest':
        return '寻找休息处';
      default:
        return '停留中';
    }
  }

  /// 成长阶段中文标签
  String get growthStageLabel {
    switch (growthStage) {
      case 'juvenile':
        return '幼年';
      case 'adolescent':
        return '少年';
      case 'adult':
        return '成年';
      case 'elderly':
        return '老年';
      default:
        return '未知';
    }
  }

  /// 成长阶段颜色
  Color get growthStageColor {
    switch (growthStage) {
      case 'juvenile':
        return const Color(0xFF4CAF50); // 绿色
      case 'adolescent':
        return const Color(0xFF2196F3); // 蓝色
      case 'adult':
        return const Color(0xFFFFC107); // 金色
      case 'elderly':
        return const Color(0xFF9E9E9E); // 灰色
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  /// 当前阶段所需经验阈值
  double get experienceThreshold {
    switch (growthStage) {
      case 'juvenile':
        return 100;
      case 'adolescent':
        return 300;
      case 'adult':
        return 800;
      default:
        return 0; // 老年无下一阶段
    }
  }

  /// 成长进度（0.0 ~ 1.0）
  double get growthProgress {
    final threshold = experienceThreshold;
    if (threshold <= 0) return 1.0;
    return (experience / threshold).clamp(0.0, 1.0);
  }

  /// 年龄（天）— 假设 5 秒/tick, 720 tick/小时, 24 小时/天
  int get ageInDays => (age / (720 * 24)).floor();
}

/// 道具定义
class LifeItem {
  final int id;
  final String name;
  final String icon;
  final String description;
  final String itemType;    // food/toy/medicine/decoration
  final String effectKey;   // hunger/energy/mood/experience/all
  final double effectValue;
  final int durationTicks;  // 0=即时

  const LifeItem({
    required this.id,
    required this.name,
    this.icon = '📦',
    this.description = '',
    this.itemType = 'food',
    this.effectKey = 'hunger',
    this.effectValue = 10,
    this.durationTicks = 0,
  });

  factory LifeItem.fromJson(Map<String, dynamic> json) {
    return LifeItem(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '📦',
      description: json['description']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? json['itemType']?.toString() ?? 'food',
      effectKey: json['effect_key']?.toString() ?? json['effectKey']?.toString() ?? 'hunger',
      effectValue: _asDouble(json['effect_value'] ?? json['effectValue'], fallback: 10),
      durationTicks: _asInt(json['duration_ticks'] ?? json['durationTicks']),
    );
  }

  /// 道具类型颜色
  Color get typeColor {
    switch (itemType) {
      case 'food':
        return const Color(0xFF4CAF50); // 绿色
      case 'toy':
        return const Color(0xFF9C27B0); // 紫色
      case 'medicine':
        return const Color(0xFF2196F3); // 蓝色
      case 'decoration':
        return const Color(0xFFFF9800); // 橙色
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  /// 道具类型中文标签
  String get typeLabel {
    switch (itemType) {
      case 'food': return '食物';
      case 'toy': return '玩具';
      case 'medicine': return '药品';
      case 'decoration': return '装饰';
      default: return '其他';
    }
  }

  /// 效果描述
  String get effectLabel {
    final key = effectKey == 'all' ? '全属性' : effectKey;
    final suffix = durationTicks > 0 ? '/tick ×$durationTicks' : '';
    return '$key +${effectValue.toInt()}$suffix';
  }
}

/// 背包道具（含数量和关联道具定义）
class LifeInventoryItem {
  final int itemId;
  final int quantity;
  final LifeItem? item;

  const LifeInventoryItem({
    required this.itemId,
    required this.quantity,
    this.item,
  });

  factory LifeInventoryItem.fromJson(Map<String, dynamic> json) {
    // 后端 inventory 接口已合并道具定义字段
    final hasName = json.containsKey('name');
    LifeItem? item;
    if (hasName) {
      item = LifeItem(
        id: _asInt(json['item_id'] ?? json['itemId']),
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? '📦',
        description: json['description']?.toString() ?? '',
        itemType: json['item_type']?.toString() ?? json['itemType']?.toString() ?? 'food',
        effectKey: json['effect_key']?.toString() ?? json['effectKey']?.toString() ?? 'hunger',
        effectValue: _asDouble(json['effect_value'] ?? json['effectValue'], fallback: 10),
        durationTicks: _asInt(json['duration_ticks'] ?? json['durationTicks']),
      );
    }
    return LifeInventoryItem(
      itemId: _asInt(json['item_id'] ?? json['itemId']),
      quantity: _asInt(json['quantity']),
      item: item,
    );
  }

  /// 显示名称（优先取关联道具定义）
  String get displayName => item?.name ?? '道具#$itemId';

  /// 显示图标
  String get displayIcon => item?.icon ?? '📦';
}

/// 活跃 buff 效果摘要（精灵图标展示用）
class ActiveEffectSummary {
  final int itemId;
  final String icon;
  final String name;
  final int remaining;

  const ActiveEffectSummary({
    required this.itemId,
    required this.icon,
    required this.name,
    required this.remaining,
  });

  factory ActiveEffectSummary.fromJson(Map<String, dynamic> json) {
    return ActiveEffectSummary(
      itemId: _asInt(json['item_id'] ?? json['itemId']),
      icon: json['icon']?.toString() ?? '✨',
      name: json['name']?.toString() ?? '',
      remaining: _asInt(json['remaining']),
    );
  }
}

/// 解析 active_effects 数组
List<ActiveEffectSummary> _parseActiveEffects(dynamic raw) {
  if (raw is! List) return const [];
  final result = <ActiveEffectSummary>[];
  for (final e in raw) {
    if (e is Map) {
      result.add(ActiveEffectSummary.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return result;
}

/// 实体间社交关系
class LifeRelationship {
  final int entityId;
  final int targetId;
  final String relationType; // friend/rival/mate
  final double affinity; // 0-100

  const LifeRelationship({
    required this.entityId,
    required this.targetId,
    required this.relationType,
    this.affinity = 0,
  });

  factory LifeRelationship.fromJson(Map<String, dynamic> json) {
    return LifeRelationship(
      entityId: _asInt(json['entity_id'] ?? json['entityId']),
      targetId: _asInt(json['target_id'] ?? json['targetId']),
      relationType: (json['relation_type'] ?? json['relationType'] ?? 'friend').toString(),
      affinity: _asDouble(json['affinity']),
    );
  }

  /// 关系中文标签
  String get relationLabel {
    switch (relationType) {
      case 'friend': return '朋友';
      case 'rival': return '对手';
      case 'mate': return '伴侣';
      default: return '未知';
    }
  }

  /// 关系颜色
  Color get relationColor {
    switch (relationType) {
      case 'friend': return const Color(0xFF4CAF50); // 绿色
      case 'rival': return const Color(0xFFF44336);  // 红色
      case 'mate': return const Color(0xFFFFC107);   // 金色
      default: return Colors.grey;
    }
  }

  /// 唯一键（用于匹配更新/删除）
  String get key => '${entityId}_$targetId';
}

/// 世界事件差异（广播用）
class WorldEventDiff {
  final String type;     // weather_rain/disaster_storm 等
  final bool active;
  final double intensity;
  final String message;  // 中文事件描述

  const WorldEventDiff({
    required this.type,
    this.active = false,
    this.intensity = 0,
    this.message = '',
  });

  factory WorldEventDiff.fromJson(Map<String, dynamic> json) {
    return WorldEventDiff(
      type: json['type']?.toString() ?? '',
      active: json['active'] == true,
      intensity: _asDouble(json['intensity']),
      message: json['message']?.toString() ?? '',
    );
  }
}

/// 世界生态摘要
class LifeWorldSummary {
  final int entityCount;
  final int aliveCount;
  final int birthCount;
  final int deathCount;
  final double avgHunger;
  final double avgEnergy;
  final double avgMood;
  final double totalFood;
  final int habitableCells;
  final int dangerCells;
  final String weather;           // clear/rain/drought/storm
  final List<String> activeEvents; // 当前活跃事件描述列表

  const LifeWorldSummary({
    this.entityCount = 0,
    this.aliveCount = 0,
    this.birthCount = 0,
    this.deathCount = 0,
    this.avgHunger = 0,
    this.avgEnergy = 0,
    this.avgMood = 0,
    this.totalFood = 0,
    this.habitableCells = 0,
    this.dangerCells = 0,
    this.weather = 'clear',
    this.activeEvents = const [],
  });

  factory LifeWorldSummary.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['active_events'] ?? json['activeEvents'];
    final events = <String>[];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        events.add(e.toString());
      }
    }
    return LifeWorldSummary(
      entityCount: _asInt(json['entity_count'] ?? json['entityCount']),
      aliveCount: _asInt(json['alive_count'] ?? json['aliveCount']),
      birthCount: _asInt(json['birth_count'] ?? json['birthCount']),
      deathCount: _asInt(json['death_count'] ?? json['deathCount']),
      avgHunger: _asDouble(json['avg_hunger'] ?? json['avgHunger']),
      avgEnergy: _asDouble(json['avg_energy'] ?? json['avgEnergy']),
      avgMood: _asDouble(json['avg_mood'] ?? json['avgMood']),
      totalFood: _asDouble(json['total_food'] ?? json['totalFood']),
      habitableCells:
          _asInt(json['habitable_cells'] ?? json['habitableCells']),
      dangerCells: _asInt(json['danger_cells'] ?? json['dangerCells']),
      weather: json['weather']?.toString() ?? json['Weather']?.toString() ?? 'clear',
      activeEvents: events,
    );
  }

  static const empty = LifeWorldSummary();
}

/// 世界事件
class LifeEvent {
  final int entityId;
  final String entityType;
  final String type;
  final String desc;
  final double x;
  final double y;
  final DateTime timestamp;
  final int importance;

  const LifeEvent({
    required this.entityId,
    required this.entityType,
    required this.type,
    required this.desc,
    this.x = 0,
    this.y = 0,
    required this.timestamp,
    this.importance = 0,
  });

  factory LifeEvent.fromJson(Map<String, dynamic> json) {
    return LifeEvent(
      entityId: _asInt(json['entity_id'] ?? json['entityId']),
      entityType: json['entity_type']?.toString() ??
          json['entityType']?.toString() ??
          '',
      type: json['type']?.toString() ?? '',
      desc: json['desc']?.toString() ?? json['description']?.toString() ?? '',
      x: _asDouble(json['x']),
      y: _asDouble(json['y']),
      timestamp: _parseTimestamp(json['timestamp'] ?? json['created_at'] ?? json['createdAt']),
      importance: _asInt(json['importance'] ?? json['Importance']),
    );
  }

  /// 是否为重要事件（importance >= 1）
  bool get isImportant => importance >= 1;
}

/// Tick 广播更新
class LifeStateUpdate {
  final String worldId;
  final int tick;
  final LifeWorldSummary summary;
  final List<Map<String, dynamic>> entityChanges;
  final List<LifeEvent> events;
  final List<int> removedEntityIds;
  final List<LifeRelationship> relationshipChanges;
  final List<Map<String, int>> removedRelationships; // [{entity_id, target_id}]
  final List<WorldEventDiff> worldEvents; // 新增/变化的世界事件

  const LifeStateUpdate({
    required this.worldId,
    required this.tick,
    required this.summary,
    required this.entityChanges,
    required this.events,
    this.removedEntityIds = const [],
    this.relationshipChanges = const [],
    this.removedRelationships = const [],
    this.worldEvents = const [],
  });

  factory LifeStateUpdate.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'];
    final Map<String, dynamic> source =
        (changes is Map) ? Map<String, dynamic>.from(changes) : json;

    final rawEntities = source['entities'] ?? source['entity_changes'];
    final entities = <Map<String, dynamic>>[];
    if (rawEntities is List) {
      for (final e in rawEntities) {
        if (e is Map) {
          entities.add(Map<String, dynamic>.from(e));
        }
      }
    }

    final rawEvents = source['events'];
    final events = <LifeEvent>[];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is Map) {
          events.add(LifeEvent.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    // 解析 removed_entity_ids（兼容 snake_case + camelCase）
    final rawRemoved = source['removed_entity_ids'] ?? source['removedEntityIds'];
    final removedIds = <int>[];
    if (rawRemoved is List) {
      for (final v in rawRemoved) {
        removedIds.add(_asInt(v));
      }
    }

    // 解析 relationships（双格式兼容）
    final rawRelationships = source['relationships'];
    final relChanges = <LifeRelationship>[];
    if (rawRelationships is List) {
      for (final r in rawRelationships) {
        if (r is Map) {
          relChanges.add(LifeRelationship.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    // 解析 removed_relationships（双格式兼容）
    final rawRemovedRels = source['removed_relationships'] ?? source['removedRelationships'];
    final removedRels = <Map<String, int>>[];
    if (rawRemovedRels is List) {
      for (final r in rawRemovedRels) {
        if (r is Map) {
          removedRels.add({
            'entity_id': _asInt(r['entity_id'] ?? r['entityId']),
            'target_id': _asInt(r['target_id'] ?? r['targetId']),
          });
        }
      }
    }

    // 解析 world_events（双格式兼容）
    final rawWorldEvents = source['world_events'] ?? source['worldEvents'];
    final worldEvents = <WorldEventDiff>[];
    if (rawWorldEvents is List) {
      for (final w in rawWorldEvents) {
        if (w is Map) {
          worldEvents.add(WorldEventDiff.fromJson(Map<String, dynamic>.from(w)));
        }
      }
    }

    return LifeStateUpdate(
      worldId: json['world_id']?.toString() ??
          json['worldId']?.toString() ??
          'default',
      tick: _asInt(json['tick']),
      summary: json['summary'] is Map<String, dynamic>
          ? LifeWorldSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : json['summary'] is Map
              ? LifeWorldSummary.fromJson(
                  Map<String, dynamic>.from(json['summary'] as Map),
                )
              : LifeWorldSummary.empty,
      entityChanges: entities,
      events: events,
      removedEntityIds: removedIds,
      relationshipChanges: relChanges,
      removedRelationships: removedRels,
      worldEvents: worldEvents,
    );
  }
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}

double _asDouble(dynamic raw, {double fallback = 0}) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? fallback;
  return fallback;
}

DateTime _parseTimestamp(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
  return DateTime.now();
}
