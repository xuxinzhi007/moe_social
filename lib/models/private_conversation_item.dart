import 'private_message_item.dart';

class PrivateConversationItem {
  final String peerUserId;
  final String peerName;
  final String peerAvatar;
  final String peerMoeNo;
  final String peerDisplayUserId;
  final PrivateMessageItem lastMessage;
  final int unreadCount;

  const PrivateConversationItem({
    required this.peerUserId,
    this.peerName = '',
    this.peerAvatar = '',
    this.peerMoeNo = '',
    this.peerDisplayUserId = '',
    required this.lastMessage,
    this.unreadCount = 0,
  });

  factory PrivateConversationItem.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['last_message'];
    final last = lastRaw is Map<String, dynamic>
        ? PrivateMessageItem.fromJson(lastRaw)
        : const PrivateMessageItem(
            id: '',
            senderId: '',
            receiverId: '',
          );
    return PrivateConversationItem(
      peerUserId: json['peer_user_id']?.toString() ?? '',
      peerName: json['peer_name']?.toString() ?? '',
      peerAvatar: json['peer_avatar']?.toString() ?? '',
      peerMoeNo: json['peer_moe_no']?.toString() ?? '',
      peerDisplayUserId: json['peer_display_user_id']?.toString() ?? '',
      lastMessage: last,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
