class BattleSide {
  const BattleSide._(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static const left = BattleSide._('BATTLE_SIDE_LEFT', '左方');
  static const right = BattleSide._('BATTLE_SIDE_RIGHT', '右方');

  static BattleSide fromApi(Object? value) =>
      value.toString().contains('RIGHT') || value.toString() == 'right'
          ? right
          : left;
}

class BattleParticipant {
  const BattleParticipant(
      {required this.userId, required this.userName, this.avatarUrl = ''});
  final String userId;
  final String userName;
  final String avatarUrl;
  factory BattleParticipant.fromJson(Map<String, dynamic> json) =>
      BattleParticipant(
          userId:
              json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
          userName: json['userName']?.toString() ??
              json['user_name']?.toString() ??
              '参赛者',
          avatarUrl: json['avatarUrl']?.toString() ??
              json['avatar_url']?.toString() ??
              '');
}

class BattleScore {
  const BattleScore({required this.side, required this.score});
  final BattleSide side;
  final int score;
  factory BattleScore.fromJson(Map<String, dynamic> json) => BattleScore(
      side: BattleSide.fromApi(json['side']),
      score: (json['score'] as num?)?.toInt() ?? 0);
}

class BattleRoom {
  const BattleRoom(
      {required this.id,
      required this.status,
      required this.left,
      required this.right,
      required this.leftScore,
      required this.rightScore,
      required this.endsAt,
      required this.serverTime,
      required this.lastEventSeq,
      this.winnerSide});
  final String id;
  final String status;
  final BattleParticipant left;
  final BattleParticipant right;
  final BattleScore leftScore;
  final BattleScore rightScore;
  final DateTime? endsAt;
  final DateTime? serverTime;
  final int lastEventSeq;
  final BattleSide? winnerSide;
  // Kratos JSON normally uses the enum name, but some transports serialize
  // protobuf enums as their numeric values (2 = running, 3 = finished).
  bool get isRunning =>
      status.toLowerCase().contains('running') || status == '2';
  bool get isFinished =>
      status.toLowerCase().contains('finished') || status == '3';
  factory BattleRoom.fromJson(Map<String, dynamic> json) => BattleRoom(
      id: json['roomId']?.toString() ?? json['room_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      left: BattleParticipant.fromJson(
          Map<String, dynamic>.from(json['left'] as Map? ?? const {})),
      right: BattleParticipant.fromJson(
          Map<String, dynamic>.from(json['right'] as Map? ?? const {})),
      leftScore: BattleScore.fromJson(Map<String, dynamic>.from(
          json['leftScore'] as Map? ?? json['left_score'] as Map? ?? const {})),
      rightScore: BattleScore.fromJson(Map<String, dynamic>.from(
          json['rightScore'] as Map? ??
              json['right_score'] as Map? ??
              const {})),
      endsAt: DateTime.tryParse(
          json['endsAt']?.toString() ?? json['ends_at']?.toString() ?? ''),
      serverTime:
          DateTime.tryParse(json['serverTime']?.toString() ?? json['server_time']?.toString() ?? ''),
      lastEventSeq: (json['lastEventSeq'] as num?)?.toInt() ?? (json['last_event_seq'] as num?)?.toInt() ?? 0,
      winnerSide: json['winnerSide'] == null && json['winner_side'] == null ? null : BattleSide.fromApi(json['winnerSide'] ?? json['winner_side']));
}

/// 已提交的 PK 礼物事件。比分仍以 [BattleRoom] 快照为准，事件仅驱动即时动效。
class BattleGiftEvent {
  const BattleGiftEvent({
    required this.id,
    required this.sequence,
    required this.senderUserId,
    required this.side,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.quantity,
  });

  final String id;
  final int sequence;
  final String senderUserId;
  final BattleSide side;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final int quantity;

  factory BattleGiftEvent.fromJson(Map<String, dynamic> json) {
    return BattleGiftEvent(
      id: json['eventId']?.toString() ?? json['event_id']?.toString() ?? '',
      sequence: (json['eventSeq'] as num?)?.toInt() ??
          (json['event_seq'] as num?)?.toInt() ??
          0,
      senderUserId: json['senderUserId']?.toString() ??
          json['sender_user_id']?.toString() ??
          '',
      side: BattleSide.fromApi(json['side']),
      giftId: json['giftId']?.toString() ?? json['gift_id']?.toString() ?? '',
      giftName:
          json['giftName']?.toString() ?? json['gift_name']?.toString() ?? '礼物',
      giftIcon:
          json['giftIcon']?.toString() ?? json['gift_icon']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

/// 送礼成功后的原子结果。房间快照用于比分，事件用于即时礼物动效。
class BattleGiftSendResult {
  const BattleGiftSendResult({required this.room, this.event});

  final BattleRoom room;
  final BattleGiftEvent? event;
}
