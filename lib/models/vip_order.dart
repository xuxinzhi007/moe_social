class VipOrder {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final double amount;
  final String status;
  final String createdAt; // 后端返回的是字符串格式
  final String? paidAt; // 后端返回的是字符串格式，可能为空

  VipOrder({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  // 从JSON创建VipOrder实例（后端返回格式）
  factory VipOrder.fromJson(Map<String, dynamic> json) {
    return VipOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      planName: json['plan_name'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      paidAt: json['paid_at'] as String?,
    );
  }

  // 转换为JSON（用于发送到后端）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'amount': amount,
      'status': status,
      'created_at': createdAt,
      'paid_at': paidAt,
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

  // 获取支付时间的DateTime对象（用于显示）
  DateTime? get paidAtDateTime {
    if (paidAt == null || paidAt!.isEmpty) return null;
    try {
      return DateTime.parse(paidAt!);
    } catch (e) {
      return null;
    }
  }
}