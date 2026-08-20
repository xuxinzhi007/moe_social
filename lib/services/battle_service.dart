import '../models/battle_room.dart';
import 'api_service.dart';

class BattleService {
  Future<BattleRoom> createAndStartRoom({
    required String leftUserId,
    required String rightUserId,
  }) async {
    final created = await ApiService.post('/api/battles', body: {
      'leftUserId': leftUserId,
      'rightUserId': rightUserId,
    });
    final draft = _room(created);
    final started =
        await ApiService.post('/api/battles/${draft.id}/start', body: {
      'roomId': draft.id,
    });
    return _room(started);
  }

  Future<BattleRoom> getRoom(String roomId) async {
    final response = await ApiService.get('/api/battles/$roomId');
    return _room(response);
  }

  Future<BattleGiftSendResult> sendGift(
      {required String roomId,
      required BattleSide side,
      required String giftId,
      required String requestId}) async {
    final response = await ApiService.post('/api/battles/$roomId/gifts', body: {
      'roomId': roomId,
      'side': side.apiValue,
      'giftId': giftId,
      'quantity': 1,
      'requestId': requestId
    });
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;
    final rawEvent = data['event'];
    return BattleGiftSendResult(
      room: _room(response),
      event: rawEvent is Map
          ? BattleGiftEvent.fromJson(Map<String, dynamic>.from(rawEvent))
          : null,
    );
  }

  BattleRoom _room(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;
    final room = data['room'] is Map
        ? Map<String, dynamic>.from(data['room'] as Map)
        : data;
    return BattleRoom.fromJson(room);
  }
}
