import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_room.dart';
import '../auth_service.dart';
import '../services/api_service.dart';

class GameRoomState {
  final String id;
  final String name;
  final String description;
  final double minBet;
  final List<Color> gradient;
  final int totalTime;
  
  int countdown;
  GamePhase phase = GamePhase.betting;
  int roundNumber = 1;
  int? currentResult;
  double roundProfit = 0;
  
  final List<GameRound> history = [];
  
  GameRoomState({
    required this.id,
    required this.name,
    required this.description,
    required this.minBet,
    required this.gradient,
    required this.totalTime,
  }) : countdown = totalTime;
}

class MyBetRecord {
  final String roomId;
  final String roomName;
  final int roundNumber;
  final BetOption? bigSmall;
  final double bigSmallAmount;
  final BetOption? color;
  final double colorAmount;
  final int result;
  final double profit;
  final DateTime time;

  MyBetRecord({
    required this.roomId,
    required this.roomName,
    required this.roundNumber,
    required this.bigSmall,
    required this.bigSmallAmount,
    required this.color,
    required this.colorAmount,
    required this.result,
    required this.profit,
    required this.time,
  });
}

class GameProvider extends ChangeNotifier {
  final Map<String, GameRoomState> rooms = {
    'novice': GameRoomState(
      id: 'novice',
      name: '新手娱乐场',
      description: '适合刚上手的萌新，5元起步',
      minBet: 5,
      gradient: const [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
      totalTime: 30,
    ),
    'advanced': GameRoomState(
      id: 'advanced',
      name: '进阶高手区',
      description: '快节奏对局，大额下注',
      minBet: 50,
      gradient: const [Color(0xFFFF9A9E), Color(0xFECFEF)],
      totalTime: 15,
    ),
    'vip': GameRoomState(
      id: 'vip',
      name: '贵宾专区',
      description: '最高倍率，刺激对决',
      minBet: 200,
      gradient: const [Color(0xFFFFD700), Color(0xFFFDB931)],
      totalTime: 45,
    ),
  };

  Timer? _timer;
  final Random _random = Random();

  // 跨房间的个人下注历史
  final List<MyBetRecord> myBetHistory = [];

  // 当前房间的暂存下注
  final Map<String, MyBetRecord> pendingBets = {};

  GameProvider() {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (var room in rooms.values) {
        if (room.countdown > 0) {
          room.countdown--;
          if (room.countdown == 0) {
            _triggerReveal(room);
          }
        }
      }
      notifyListeners();
    });
  }

  void placeBet(String roomId, BetOption? bigSmall, double bigSmallAmt, BetOption? color, double colorAmt) {
    if (bigSmall == null && color == null) return;
    pendingBets[roomId] = MyBetRecord(
      roomId: roomId,
      roomName: rooms[roomId]!.name,
      roundNumber: rooms[roomId]!.roundNumber,
      bigSmall: bigSmall,
      bigSmallAmount: bigSmallAmt,
      color: color,
      colorAmount: colorAmt,
      result: 0,
      profit: 0,
      time: DateTime.now(),
    );
    notifyListeners();
  }

  bool hasBet(String roomId) {
    return pendingBets.containsKey(roomId) && pendingBets[roomId]!.roundNumber == rooms[roomId]!.roundNumber;
  }

  Future<void> _triggerReveal(GameRoomState room) async {
    room.phase = GamePhase.revealing;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final result = 1 + _random.nextInt(10);
    room.currentResult = result;
    room.phase = GamePhase.result;
    
    _settleRoom(room, result);
    notifyListeners();

    await Future.delayed(const Duration(seconds: 4));

    room.history.insert(0, GameRound(
      roundNumber: room.roundNumber,
      result: result,
      createdAt: DateTime.now(),
    ));
    if (room.history.length > 20) room.history.removeLast();
    
    room.roundNumber++;
    room.phase = GamePhase.betting;
    room.countdown = room.totalTime;
    room.currentResult = null;
    room.roundProfit = 0;
    notifyListeners();
  }

  void _settleRoom(GameRoomState room, int result) {
    final pending = pendingBets[room.id];
    if (pending == null || pending.roundNumber != room.roundNumber) return;

    final isBig = result >= 6;
    final isRed = result >= 6;
    double profit = 0;

    if (pending.bigSmall != null) {
      final win = (isBig && pending.bigSmall == BetOption.big) ||
          (!isBig && pending.bigSmall == BetOption.small);
      profit += win ? pending.bigSmallAmount * 0.9 : -pending.bigSmallAmount;
    }
    if (pending.color != null) {
      final win = (isRed && pending.color == BetOption.red) ||
          (!isRed && pending.color == BetOption.black);
      profit += win ? pending.colorAmount * 0.9 : -pending.colorAmount;
    }

    room.roundProfit = profit;

    final finalRecord = MyBetRecord(
      roomId: room.id,
      roomName: room.name,
      roundNumber: room.roundNumber,
      bigSmall: pending.bigSmall,
      bigSmallAmount: pending.bigSmallAmount,
      color: pending.color,
      colorAmount: pending.colorAmount,
      result: result,
      profit: profit,
      time: DateTime.now(),
    );

    myBetHistory.insert(0, finalRecord);
    // 保留给UI展示，下一局会自动覆盖
    // pendingBets.remove(room.id); 

    final userId = AuthService.currentUser;
    if (userId != null && profit != 0) {
      ApiService.recharge(userId, profit, profit > 0 ? '游戏获胜' : '游戏下注');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
