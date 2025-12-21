class VipPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final String createdAt; // 后端返回的是字符串格式
  final String updatedAt; // 后端返回的是字符串格式

  VipPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.createdAt,
    required this.updatedAt,
  });

  // 从JSON创建VipPlan实例（后端返回格式）
  factory VipPlan.fromJson(Map<String, dynamic> json) {
    return VipPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  // 转换为JSON（用于发送到后端）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_days': durationDays,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // 获取创建时间的DateTime对象（用于显示）
  DateTime? get createdAtDateTime {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return null;
    }
  }

  // 获取更新时间的DateTime对象（用于显示）
  DateTime? get updatedAtDateTime {
    try {
      return DateTime.parse(updatedAt);
    } catch (e) {
      return null;
    }
  }
}