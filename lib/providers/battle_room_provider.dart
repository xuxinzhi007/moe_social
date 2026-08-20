import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/battle_room.dart';
import '../services/battle_service.dart';
import '../services/battle_ws_service.dart';

class BattleRoomProvider extends ChangeNotifier {
  BattleRoomProvider(this.roomId, {BattleService? service, BattleWsService? ws})
      : _service = service ?? BattleService(),
        _ws = ws ?? BattleWsService();
  final String roomId;
  final BattleService _service;
  final BattleWsService _ws;
  BattleRoom? room;
  bool loading = true;
  bool sending = false;
  bool connected = false;
  Object? error;
  BattleGiftEvent? latestGiftEvent;
  Timer? _ticker;
  Duration _serverClockOffset = Duration.zero;
  Duration get remaining {
    final end = room?.endsAt;
    if (end == null) return Duration.zero;
    final value =
        end.difference(DateTime.now().toUtc().add(_serverClockOffset));
    return value.isNegative ? Duration.zero : value;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _setRoom(await _service.getRoom(roomId));
      _ws.onMessage = _receive;
      _ws.onConnection = (value) {
        connected = value;
        notifyListeners();
      };
      _ws.connect(roomId);
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (remaining == Duration.zero && room?.isRunning == true) {
          unawaited(refresh());
        }
        notifyListeners();
      });
    } catch (value) {
      error = value;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _setRoom(await _service.getRoom(roomId));
      notifyListeners();
    } catch (_) {
      // The last known snapshot remains usable while a reconnect is pending.
    }
  }

  Future<void> send(BattleSide side, String giftId) async {
    if (sending || room?.isRunning != true) {
      return;
    }
    sending = true;
    notifyListeners();
    try {
      final result = await _service.sendGift(
          roomId: roomId,
          side: side,
          giftId: giftId,
          requestId:
              '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}');
      _setRoom(result.room);
      if (result.event != null) {
        latestGiftEvent = result.event;
      }
    } catch (value) {
      error = value;
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void _receive(Map<String, dynamic> message) {
    final seq = (message['seq'] as num?)?.toInt() ?? 0;
    if (seq > 0 && room != null && seq > room!.lastEventSeq + 1) {
      unawaited(refresh());
      return;
    }
    final payload = message['payload'];
    if (payload is Map) {
      final data = Map<String, dynamic>.from(payload);
      final rawEvent = data['event'];
      if (message['type'] == 'gift_sent' && rawEvent is Map) {
        latestGiftEvent = BattleGiftEvent.fromJson(
          Map<String, dynamic>.from(rawEvent),
        );
      }
      final rawRoom = data['room'] is Map ? data['room'] : data;
      if (rawRoom is Map) {
        _setRoom(BattleRoom.fromJson(Map<String, dynamic>.from(rawRoom)));
      }
    }
    notifyListeners();
  }

  void _setRoom(BattleRoom value) {
    room = value;
    final serverTime = value.serverTime;
    if (serverTime != null) {
      _serverClockOffset = serverTime.difference(DateTime.now().toUtc());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}
