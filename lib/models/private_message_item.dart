/// 与后端 `PrivateMessageItem`（GET/POST `/api/private-messages`）对齐。
class PrivateMessageItem {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderMoeNo;
  final String receiverMoeNo;
  final String body;
  final List<String> imagePaths;
  final int retentionDays;
  final String createdAt;
  final String expiresAt;

  const PrivateMessageItem({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.senderMoeNo = '',
    this.receiverMoeNo = '',
    this.body = '',
    this.imagePaths = const [],
    this.retentionDays = 0,
    this.createdAt = '',
    this.expiresAt = '',
  });

  factory PrivateMessageItem.fromJson(Map<String, dynamic> json) {
    final paths = json['image_paths'];
    List<String> list = const [];
    if (paths is List) {
      list = paths.map((e) => e.toString()).toList();
    }
    return PrivateMessageItem(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      senderMoeNo: json['sender_moe_no']?.toString() ?? '',
      receiverMoeNo: json['receiver_moe_no']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imagePaths: list,
      retentionDays: (json['retention_days'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }
}
