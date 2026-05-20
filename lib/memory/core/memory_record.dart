/// 与后端 [backend/pkg/memory.Record] 对齐的客户端记忆条目。
class MemoryRecord {
  final String id;
  final String userId;
  final String key;
  final String value;
  final String memoryType;
  final double confidence;
  final String? source;
  final String updatedAt;

  const MemoryRecord({
    required this.id,
    required this.userId,
    required this.key,
    required this.value,
    this.memoryType = 'fact',
    this.confidence = 0.6,
    this.source,
    this.updatedAt = '',
  });

  factory MemoryRecord.fromJson(Map<String, dynamic> json, {required String userId}) {
    return MemoryRecord(
      id: (json['id'] as String?) ?? '',
      userId: userId,
      key: (json['key'] as String?) ?? '',
      value: (json['value'] as String?) ?? '',
      memoryType: (json['memory_type'] as String?) ?? 'fact',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.6,
      source: json['source'] as String?,
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }

  static bool isTechnical({required String key, String? source}) {
    final k = key.toLowerCase();
    final s = (source ?? '').toLowerCase();
    return k.startsWith('device_info:') || s == 'device_sync';
  }
}
