import 'package:flutter/foundation.dart';

import '../models/battle_room.dart';
import '../services/battle_service.dart';

/// Creates a V1 test room before the user enters the real-time room page.
class BattleLobbyProvider extends ChangeNotifier {
  BattleLobbyProvider({BattleService? service})
      : _service = service ?? BattleService();

  final BattleService _service;
  bool creating = false;
  Object? error;

  Future<BattleRoom> createRoom({
    required String leftUserId,
    required String rightUserId,
  }) async {
    final left = int.tryParse(leftUserId.trim());
    final right = int.tryParse(rightUserId.trim());
    if (left == null || left <= 0 || right == null || right <= 0) {
      throw const FormatException('请输入两个有效的用户 ID');
    }
    if (left == right) {
      throw const FormatException('两位参赛者必须是不同用户');
    }
    creating = true;
    error = null;
    notifyListeners();
    try {
      return await _service.createAndStartRoom(
        leftUserId: left.toString(),
        rightUserId: right.toString(),
      );
    } catch (value) {
      error = value;
      rethrow;
    } finally {
      creating = false;
      notifyListeners();
    }
  }
}
