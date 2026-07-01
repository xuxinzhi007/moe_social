// 扫雷游戏配置和类型定义

// 游戏难度枚举
enum GameDifficulty {
  easy,
  medium,
  hard
}

// 游戏配置
class GameConfig {
  static GameSettings getSettings(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return GameSettings(
          rows: 9,
          cols: 9,
          mines: 10,
          name: '初级',
        );
      case GameDifficulty.medium:
        return GameSettings(
          rows: 16,
          cols: 16,
          mines: 40,
          name: '中级',
        );
      case GameDifficulty.hard:
        return GameSettings(
          rows: 16,
          cols: 30,
          mines: 99,
          name: '高级',
        );
    }
  }
}

// 游戏设置
class GameSettings {
  final int rows;
  final int cols;
  final int mines;
  final String name;

  GameSettings({
    required this.rows,
    required this.cols,
    required this.mines,
    required this.name,
  });
}
