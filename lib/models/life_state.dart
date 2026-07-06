// 数字生命模拟器 — 数据模型
//
// 与后端 JSON 协议对应，包含实体状态、世界事件和 Tick 广播。

/// 数字生命实体状态
class LifeEntity {
  final int id;
  final String name;
  final String emoji;
  final double hunger; // 0-100
  final double energy; // 0-100
  final double mood; // 0-100
  final String action; // idle/walking/eating/sleeping/...
  final double x; // 0-1280
  final double y; // 0-720

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
      emoji: json['emoji']?.toString() ?? '🐾',
      hunger: _asDouble(json['hunger'], fallback: 80),
      energy: _asDouble(json['energy'], fallback: 80),
      mood: _asDouble(json['mood'], fallback: 70),
      action: json['action']?.toString() ?? 'idle',
      x: _asDouble(json['x'], fallback: 640),
      y: _asDouble(json['y'], fallback: 360),
    );
  }

  /// 从增量 diff 合并（只更新变化的字段）
  LifeEntity mergeFromJson(Map<String, dynamic> json) {
    return LifeEntity(
      id: id,
      name: json.containsKey('name')
          ? json['name']?.toString() ?? name
          : name,
      emoji: json.containsKey('emoji')
          ? json['emoji']?.toString() ?? emoji
          : emoji,
      hunger: json.containsKey('hunger')
          ? _asDouble(json['hunger'], fallback: hunger)
          : hunger,
      energy: json.containsKey('energy')
          ? _asDouble(json['energy'], fallback: energy)
          : energy,
      mood: json.containsKey('mood')
          ? _asDouble(json['mood'], fallback: mood)
          : mood,
      action: json.containsKey('action')
          ? json['action']?.toString() ?? action
          : action,
      x: json.containsKey('x') ? _asDouble(json['x'], fallback: x) : x,
      y: json.containsKey('y') ? _asDouble(json['y'], fallback: y) : y,
    );
  }

  /// 行为描述文本
  String get actionLabel {
    switch (action) {
      case 'sleeping':
        return '休息中';
      case 'seeking_food':
        return '寻找食物';
      case 'eating':
        return '进食中';
      case 'wandering':
        return '闲逛';
      case 'walking':
        return '散步';
      case 'talking':
        return '交谈';
      default:
        return '休息';
    }
  }
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
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }
}

/// Tick 广播更新
class LifeStateUpdate {
  final String worldId;
  final int tick;
  final List<Map<String, dynamic>> entityChanges;
  final List<LifeEvent> events;

  const LifeStateUpdate({
    required this.worldId,
    required this.tick,
    required this.entityChanges,
    required this.events,
  });

  factory LifeStateUpdate.fromJson(Map<String, dynamic> json) {
    // 后端将 entities/events 嵌套在 changes 下（TickBroadcast.Changes）
    // 同时兼容无 changes 层的消息（如 state_snapshot）
    final changes = json['changes'];
    final Map<String, dynamic> source = (changes is Map)
        ? Map<String, dynamic>.from(changes)
        : json;

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

    return LifeStateUpdate(
      worldId: json['world_id']?.toString() ??
          json['worldId']?.toString() ??
          'default',
      tick: _asInt(json['tick']),
      entityChanges: entities,
      events: events,
    );
  }
}

// ── 内部工具函数 ──────────────────────────────────────────────────────────────

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
