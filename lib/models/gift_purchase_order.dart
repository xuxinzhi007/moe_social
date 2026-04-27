class GiftPurchaseOrder {
  final String id;
  final String userId;
  final String orderNo;
  final String giftId;
  final String giftName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String payMethod;
  final String status;
  final String createdAt;

  GiftPurchaseOrder({
    required this.id,
    required this.userId,
    required this.orderNo,
    required this.giftId,
    required this.giftName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.payMethod,
    required this.status,
    required this.createdAt,
  });

  factory GiftPurchaseOrder.fromJson(Map<String, dynamic> json) {
    return GiftPurchaseOrder(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      orderNo: json['order_no'] as String? ?? '',
      giftId: json['gift_id']?.toString() ?? '',
      giftName: json['gift_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      payMethod: json['pay_method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
