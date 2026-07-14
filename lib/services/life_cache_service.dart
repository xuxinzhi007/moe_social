import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_state.dart';

/// 数字生命状态本地缓存服务
/// 使用 SharedPreferences 存储最近一次完整状态，用于离线降级。
class LifeCacheService {
  static const _keyState = 'life_cache_state';
  static const _keyTimestamp = 'life_cache_timestamp';
  static const _ttlHours = 24;

  /// 保存状态快照（debounce 由调用方控制）。
  static Future<void> saveState({
    required List<LifeEntity> entities,
    required Map<String, dynamic> summary,
    required int tick,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'entities': entities.map((e) => e.toJson()).toList(),
        'summary': summary,
        'tick': tick,
      });
      await prefs.setString(_keyState, payload);
      await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('LifeCacheService saveState error: $e');
    }
  }

  /// 加载缓存状态，超过 TTL 返回 null。
  static Future<LifeCachedState?> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyState);
      final ts = prefs.getInt(_keyTimestamp);
      if (raw == null || ts == null) return null;

      // TTL 检查
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(cachedAt).inHours >= _ttlHours) {
        await clear();
        return null;
      }

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entitiesRaw = map['entities'] as List?;
      final entities = entitiesRaw == null
          ? <LifeEntity>[]
          : entitiesRaw
              .whereType<Map>()
              .map((e) => LifeEntity.fromJson(Map<String, dynamic>.from(e)))
              .toList();

      final summaryRaw = map['summary'];
      final summary = summaryRaw is Map
          ? Map<String, dynamic>.from(summaryRaw)
          : <String, dynamic>{};

      final tick = map['tick'] is int
          ? map['tick'] as int
          : int.tryParse(map['tick']?.toString() ?? '') ?? 0;

      return LifeCachedState(
        entities: entities,
        summary: summary,
        tick: tick,
        cachedAt: cachedAt,
      );
    } catch (e) {
      debugPrint('LifeCacheService loadState error: $e');
      return null;
    }
  }

  /// 清除缓存。
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyState);
      await prefs.remove(_keyTimestamp);
    } catch (e) {
      debugPrint('LifeCacheService clear error: $e');
    }
  }
}

/// 缓存状态快照。
class LifeCachedState {
  final List<LifeEntity> entities;
  final Map<String, dynamic> summary;
  final int tick;
  final DateTime cachedAt;

  const LifeCachedState({
    required this.entities,
    required this.summary,
    required this.tick,
    required this.cachedAt,
  });
}
