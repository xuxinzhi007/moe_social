import 'memory_record.dart';

/// L1 记忆文本库客户端抽象；实现可换 HTTP / gRPC / 内存 mock。
abstract class MemoryStore {
  Future<List<MemoryRecord>> list(String userId, {int limit = 50, int offset = 0});

  Future<List<MemoryRecord>> search(String userId, {required String query, int limit = 8});

  Future<void> upsert(
    String userId, {
    required String key,
    required String value,
    String? memoryType,
    String? source,
    double? confidence,
  });

  Future<void> deleteByKey(String userId, String key);
}
