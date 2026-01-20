class UserMemory {
  final String id;
  final String userId;
  final String key;
  final String value;
  final String createdAt;
  final String updatedAt;

  UserMemory({
    required this.id,
    required this.userId,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserMemory.fromJson(Map<String, dynamic> json) {
    return UserMemory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
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
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
