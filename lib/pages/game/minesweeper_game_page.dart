// 扫雷游戏核心页面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import '../../widgets/moe_toast.dart';
import 'minesweeper_scoreboard_page.dart';
import 'minesweeper_config.dart';

class MinesweeperGamePage extends StatefulWidget {
  final GameDifficulty difficulty;

  const MinesweeperGamePage({super.key, required this.difficulty});

  @override
  State<MinesweeperGamePage> createState() => _MinesweeperGamePageState();
}

class _MinesweeperGamePageState extends State<MinesweeperGamePage> {
  late GameSettings _settings;
  late List<List<Cell>> _board;
  late bool _gameOver;
  late bool _gameWon;
  late int _flagsPlaced;
  late int _cellsRevealed;
  late int _totalCells;
  late Stopwatch _stopwatch;
  late Timer _timer;
  late int _elapsedSeconds;
  late bool _firstClick;

  @override
  void initState() {
    super.initState();
    _settings = GameConfig.getSettings(widget.difficulty);
    _initializeGame();
  }

  void _initializeGame() {
    _board = List.generate(
      _settings.rows,
      (i) => List.generate(
        _settings.cols,
        (j) => Cell(row: i, col: j),
      ),
    );
    _gameOver = false;
    _gameWon = false;
    _flagsPlaced = 0;
    _cellsRevealed = 0;
    _totalCells = _settings.rows * _settings.cols;
    _stopwatch = Stopwatch();
    _elapsedSeconds = 0;
    _firstClick = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch.isRunning && !_gameOver && !_gameWon) {
        setState(() {
          _elapsedSeconds = _stopwatch.elapsed.inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _placeMines(int safeRow, int safeCol) {
    final random = Random();
    int minesPlaced = 0;

    while (minesPlaced < _settings.mines) {
      final row = random.nextInt(_settings.rows);
      final col = random.nextInt(_settings.cols);

      // 确保不在第一次点击的位置及其周围放置地雷
      if (!_board[row][col].isMine! &&
          !(row >= safeRow - 1 &&
              row <= safeRow + 1 &&
              col >= safeCol - 1 &&
              col <= safeCol + 1)) {
        _board[row][col].isMine = true;
        minesPlaced++;
      }
    }

    // 计算每个格子周围的地雷数
    for (int i = 0; i < _settings.rows; i++) {
      for (int j = 0; j < _settings.cols; j++) {
        if (!_board[i][j].isMine!) {
          _board[i][j].neighborMines = _countNeighborMines(i, j);
        }
      }
    }
  }

  int _countNeighborMines(int row, int col) {
    int count = 0;
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        if (i == 0 && j == 0) continue;
        final newRow = row + i;
        final newCol = col + j;
        if (_isValidCell(newRow, newCol) && _board[newRow][newCol].isMine!) {
          count++;
        }
      }
    }
    return count;
  }

  bool _isValidCell(int row, int col) {
    return row >= 0 && row < _settings.rows && col >= 0 && col < _settings.cols;
  }

  void _revealCell(int row, int col) {
    if (!_isValidCell(row, col) ||
        _board[row][col].isRevealed! ||
        _board[row][col].isFlagged! ||
        _gameOver ||
        _gameWon) {
      return;
    }

    if (_firstClick) {
      _firstClick = false;
      _placeMines(row, col);
      _stopwatch.start();
    }

    setState(() {
      _board[row][col].isRevealed = true;
      _cellsRevealed++;

      if (_board[row][col].isMine!) {
        _gameOver = true;
        _stopwatch.stop();
        _revealAllMines();
        MoeToast.error(context, '游戏结束！踩到地雷了');
      } else if (_board[row][col].neighborMines! == 0) {
        // 自动展开空白格子
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            if (i == 0 && j == 0) continue;
            _revealCell(row + i, col + j);
          }
        }
      }

      _checkWinCondition();
    });
  }

  void _toggleFlag(int row, int col) {
    if (!_isValidCell(row, col) ||
        _board[row][col].isRevealed! ||
        _gameOver ||
        _gameWon) {
      return;
    }

    setState(() {
      if (_board[row][col].isFlagged!) {
        _board[row][col].isFlagged = false;
        _flagsPlaced--;
      } else if (_flagsPlaced < _settings.mines) {
        _board[row][col].isFlagged = true;
        _flagsPlaced++;
      } else {
        MoeToast.warning(context, '已达到最大标记数量');
      }

      _checkWinCondition();
    });
  }

  void _revealAllMines() {
    for (int i = 0; i < _settings.rows; i++) {
      for (int j = 0; j < _settings.cols; j++) {
        if (_board[i][j].isMine!) {
          _board[i][j].isRevealed = true;
        }
      }
    }
  }

  void _checkWinCondition() {
    if (_cellsRevealed == _totalCells - _settings.mines) {
      _gameWon = true;
      _stopwatch.stop();
      MoeToast.success(context, '恭喜你获胜！');
      _saveScore();
    }
  }

  void _saveScore() {
    // 保存分数到本地存储
    // 这里可以实现本地存储逻辑
    print('保存分数: ${_elapsedSeconds}秒');
  }

  void _restartGame() {
    _stopwatch.reset();
    _timer.cancel();
    _initializeGame();
    setState(() {});
  }

  void _showScoreboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MinesweeperScoreboardPage(),
      ),
    );
  }

  Color _getNumberColor(int num) {
    switch (num) {
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.red;
      case 4: return Colors.purple;
      case 5: return Colors.brown;
      case 6: return Colors.teal;
      case 7: return Colors.black;
      case 8: return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('扫雷 - ${_settings.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            ),
          ),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restartGame,
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: _showScoreboard,
          ),
        ],
      ),
      body: Column(
        children: [
          // 游戏状态栏
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusItem(
                  Icons.timer_rounded,
                  _formatTime(_elapsedSeconds),
                  const Color(0xFF2196F3),
                ),
                _statusItem(
                  Icons.flag_rounded,
                  '$_flagsPlaced/${_settings.mines}',
                  const Color(0xFFFF9800),
                ),
                _statusItem(
                  Icons.grid_3x3_rounded,
                  '${_cellsRevealed}/${_totalCells - _settings.mines}',
                  const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),

          // 游戏棋盘
          Expanded(
            child: Center(
              child: InteractiveViewer(
                maxScale: 2.0,
                minScale: 0.5,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _settings.cols,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _settings.rows * _settings.cols,
                    itemBuilder: (context, index) {
                      final row = index ~/ _settings.cols;
                      final col = index % _settings.cols;
                      final cell = _board[row][col];

                      return GestureDetector(
                        onTap: () => _revealCell(row, col),
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _toggleFlag(row, col);
                        },
                        child: _buildCell(cell),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 游戏控制
          if (_gameOver || _gameWon) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gameWon ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _gameWon ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _restartGame,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新开始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showScoreboard,
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: const Text('查看排行榜'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(Cell cell) {
    if (cell.isRevealed!) {
      if (cell.isMine!) {
        return _cellContainer(
          color: Colors.red.shade200,
          child: Icon(
            Icons.error,
            color: Colors.red.shade600,
            size: 20,
          ),
        );
      } else if (cell.neighborMines! > 0) {
        return _cellContainer(
          color: Colors.grey.shade100,
          child: Text(
            '${cell.neighborMines}',
            style: TextStyle(
              color: _getNumberColor(cell.neighborMines!),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      } else {
        return _cellContainer(
          color: Colors.grey.shade200,
          child: const SizedBox(),
        );
      }
    } else if (cell.isFlagged!) {
      return _cellContainer(
        color: Colors.yellow.shade100,
        child: Icon(
          Icons.flag_rounded,
          color: Colors.red,
          size: 20,
        ),
      );
    } else {
      return _cellContainer(
        color: Colors.grey.shade300,
        child: const SizedBox(),
      );
    }
  }

  Widget _cellContainer({required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Center(child: child),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

// 格子类
class Cell {
  final int row;
  final int col;
  bool? isMine;
  bool? isRevealed;
  bool? isFlagged;
  int? neighborMines;

  Cell({required this.row, required this.col}) {
    isMine = false;
    isRevealed = false;
    isFlagged = false;
    neighborMines = 0;
  }
}
