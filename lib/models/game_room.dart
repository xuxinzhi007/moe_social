enum GamePhase { betting, revealing, result }

enum BetOption { big, small, red, black }

class GameBet {
  final String userId;
  final String username;
  final String? avatar;
  final BetOption option;
  final double amount;

  const GameBet({
    required this.userId,
    required this.username,
    this.avatar,
    required this.option,
    required this.amount,
  });
}

class GameRound {
  final int roundNumber;
  final int? result;        // 1-10，null 表示未开奖
  final List<GameBet> bets;
  final DateTime createdAt;

  const GameRound({
    required this.roundNumber,
    this.result,
    this.bets = const [],
    required this.createdAt,
  });

  bool get isBig => result != null && result! >= 6;
  bool get isRed => result != null && result! >= 6;

  String get resultLabel {
    if (result == null) return '...';
    return '${isBig ? '大' : '小'} · ${isRed ? '红' : '黑'} ($result)';
  }
}
