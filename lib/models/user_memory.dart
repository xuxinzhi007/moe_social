class UserMemory {
  final String id;
  final String userId;
  final String key;
  final String value;
  final String? memoryType;
  final double? confidence;
  final String? source;
  final String createdAt;
  final String updatedAt;

  UserMemory({
    required this.id,
    required this.userId,
    required this.key,
    required this.value,
    this.memoryType,
    this.confidence,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserMemory.fromJson(Map<String, dynamic> json) {
    final rawConfidence = json['confidence'];
    double? confidence;
    if (rawConfidence is num) {
      confidence = rawConfidence.toDouble();
    }
    return UserMemory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
      memoryType: json['memory_type'] as String?,
      confidence: confidence,
      source: json['source'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'key': key,
      'value': value,
      if (memoryType != null) 'memory_type': memoryType,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
