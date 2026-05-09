class UserMemoryProfile {
  final String memoryType;
  final String summary;
  final int itemCount;
  final double confidence;

  const UserMemoryProfile({
    required this.memoryType,
    required this.summary,
    required this.itemCount,
    required this.confidence,
  });

  factory UserMemoryProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['confidence'];
    final confidence = raw is num ? raw.toDouble() : 0.0;
    return UserMemoryProfile(
      memoryType: (json['memory_type'] as String?) ?? 'general',
      summary: (json['summary'] as String?) ?? '',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }
}
