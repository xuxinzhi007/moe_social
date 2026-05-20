import '../../models/user_memory.dart';
import '../../services/memory_service.dart';
import '../core/memory_record.dart';
import '../core/memory_store.dart';

/// 基于现有 REST API 的 [MemoryStore] 实现。
class MemoryHttpClient implements MemoryStore {
  @override
  Future<List<MemoryRecord>> list(String userId, {int limit = 50, int offset = 0}) async {
    final paged = await MemoryService.getUserMemoriesPaged(userId, limit: limit, offset: offset);
    final items = paged['items'];
    if (items is! List<UserMemory>) return const [];
    return items
        .where((m) => !MemoryRecord.isTechnical(key: m.key, source: m.source))
        .map(
          (m) => MemoryRecord(
            id: m.id,
            userId: userId,
            key: m.key,
            value: m.value,
            memoryType: m.memoryType ?? 'fact',
            confidence: m.confidence ?? 0.6,
            source: m.source,
            updatedAt: m.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<MemoryRecord>> search(String userId, {required String query, int limit = 8}) async {
    final hits = await MemoryService.searchUserMemories(userId, query: query, limit: limit);
    return hits
        .map(
          (m) => MemoryRecord(
            id: m.id,
            userId: userId,
            key: m.key,
            value: m.value,
            memoryType: m.memoryType ?? 'fact',
            updatedAt: m.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsert(
    String userId, {
    required String key,
    required String value,
    String? memoryType,
    String? source,
    double? confidence,
  }) async {
    await MemoryService.upsertUserMemory(
      userId: userId,
      key: key,
      value: value,
      memoryType: memoryType,
      source: source,
      confidence: confidence,
    );
  }

  @override
  Future<void> deleteByKey(String userId, String key) async {
    await MemoryService.deleteUserMemoryByKey(userId, key);
  }
}
