// 数字生命模拟器 - 数据模型

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
  });

  factory LifeWorldSummary.fromJson(Map<String, dynamic> json) {
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

  const LifeEvent({
    required this.entityId,
    required this.entityType,
    required this.type,
    required this.desc,
    this.x = 0,
    this.y = 0,
    required this.timestamp,
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
    );
  }
}

/// Tick 广播更新
class LifeStateUpdate {
  final String worldId;
  final int tick;
  final LifeWorldSummary summary;
  final List<Map<String, dynamic>> entityChanges;
  final List<LifeEvent> events;
  final List<int> removedEntityIds;

  const LifeStateUpdate({
    required this.worldId,
    required this.tick,
    required this.summary,
    required this.entityChanges,
    required this.events,
    this.removedEntityIds = const [],
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
