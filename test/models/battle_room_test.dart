import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/battle_room.dart';

void main() {
  test('recognizes numeric protobuf room statuses', () {
    final running = BattleRoom.fromJson(const {
      'roomId': '1',
      'status': 2,
      'left': {},
      'right': {},
      'leftScore': {},
      'rightScore': {},
    });
    final finished = BattleRoom.fromJson(const {
      'roomId': '1',
      'status': 3,
      'left': {},
      'right': {},
      'leftScore': {},
      'rightScore': {},
    });

    expect(running.isRunning, isTrue);
    expect(running.isFinished, isFalse);
    expect(finished.isFinished, isTrue);
  });

  test('parses a WebSocket gift event using proto JSON names', () {
    final event = BattleGiftEvent.fromJson({
      'eventId': '9',
      'eventSeq': 4,
      'senderUserId': '2',
      'side': 'BATTLE_SIDE_RIGHT',
      'giftId': '5',
      'giftName': '星星',
      'giftIcon': 'star',
      'quantity': 3,
    });

    expect(event.id, '9');
    expect(event.sequence, 4);
    expect(event.side, BattleSide.right);
    expect(event.quantity, 3);
  });

  test('parses finished snapshots returned by the battle API', () {
    final room = BattleRoom.fromJson({
      'roomId': '12',
      'status': 'BATTLE_ROOM_STATUS_FINISHED',
      'left': {'userId': '1', 'userName': '左方'},
      'right': {'userId': '2', 'userName': '右方'},
      'leftScore': {'side': 'BATTLE_SIDE_LEFT', 'score': 10},
      'rightScore': {'side': 'BATTLE_SIDE_RIGHT', 'score': 20},
      'winnerSide': 'BATTLE_SIDE_RIGHT',
      'lastEventSeq': 3,
    });

    expect(room.isFinished, isTrue);
    expect(room.winnerSide, BattleSide.right);
    expect(room.rightScore.score, 20);
  });
}
