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
  late bool _isLongPressing;
  late Cell? _longPressCell;
  late bool _isTapping;
  late Cell? _tappedCell;
  late Cell? _explodingCell;
  late bool _showWinAnimation;

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
    _isLongPressing = false;
    _longPressCell = null;
    _isTapping = false;
    _tappedCell = null;
    _explodingCell = null;
    _showWinAnimation = false;

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
        // 地雷引爆动画
        _playMineExplosionAnimation(row, col);
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
      // 游戏胜利动画
      _playWinAnimation();
      MoeToast.success(context, '恭喜你获胜！');
      _saveScore();
    }
  }

  void _playMineExplosionAnimation(int row, int col) {
    setState(() {
      _explodingCell = cellAt(row, col);
    });
  }

  void _playWinAnimation() {
    setState(() {
      _showWinAnimation = true;
    });
  }

  Cell? cellAt(int row, int col) {
    if (_isValidCell(row, col)) {
      return _board[row][col];
    }
    return null;
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
      backgroundColor: _getBackgroundColor(),
      appBar: AppBar(
        title: Text('扫雷 - ${_settings.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getAppBarGradient(),
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
                  child: Stack(
                    children: [
                      GridView.builder(
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
                            onTap: () {
                              // 点击时的视觉反馈
                              setState(() {
                                _isTapping = true;
                                _tappedCell = cell;
                              });
                              // 短暂延迟后执行操作
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (mounted) {
                                  setState(() {
                                    _isTapping = false;
                                    _tappedCell = null;
                                  });
                                  _revealCell(row, col);
                                }
                              });
                            },
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              _toggleFlag(row, col);
                            },
                            onLongPressStart: (_) {
                              // 长按开始时的视觉反馈
                              setState(() {
                                _isLongPressing = true;
                                _longPressCell = cell;
                              });
                            },
                            onLongPressEnd: (_) {
                              // 长按结束时的视觉反馈
                              setState(() {
                                _isLongPressing = false;
                                _longPressCell = null;
                              });
                            },
                            child: _buildCell(cell),
                          );
                        },
                      ),
                      // 游戏结束覆盖层
                      if (_gameOver || _gameWon) ...[
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                              constraints: const BoxConstraints(
                                maxWidth: 400,
                                maxHeight: 500,
                              ),
                              decoration: BoxDecoration(
                                color: _gameWon ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _gameWon ? Colors.green : Colors.red,
                                  width: 3,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _gameWon ? Icons.check_circle_rounded : Icons.error_rounded,
                                      size: 64,
                                      color: _gameWon ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _gameWon ? '恭喜你获胜！' : '游戏结束！',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _gameWon ? Colors.green : Colors.red,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _gameWon 
                                        ? '用时: ${_formatTime(_elapsedSeconds)}' 
                                        : '踩到地雷了！',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF2D3748),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '难度: ${_settings.name}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF718096),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _restartGame,
                                            icon: const Icon(Icons.refresh_rounded),
                                            label: const Text('再玩一次'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: const Color(0xFF4CAF50),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _showScoreboard,
                                            icon: const Icon(Icons.leaderboard_rounded),
                                            label: const Text('排行榜'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.arrow_back_rounded),
                                      label: const Text('返回难度选择'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: const Color(0xFF2D3748),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String text, Color color) {
    // 为倒计时添加紧迫感动画
    bool isTimer = icon == Icons.timer_rounded;
    Color? dynamicColor = color;
    double scale = 1.0;
    
    if (isTimer && _elapsedSeconds > 60) {
      // 超过1分钟时开始添加紧迫感动画
      int remainingTime = 300 - _elapsedSeconds; // 5分钟倒计时
      if (remainingTime < 60) {
        // 最后1分钟，颜色变为红色
        dynamicColor = Colors.red;
        // 添加脉动效果
        scale = 1.0 + (0.1 * (1 - remainingTime / 60));
      } else if (remainingTime < 120) {
        // 最后2分钟，颜色变为橙色
        dynamicColor = Colors.orange;
      }
    }
    
    return Transform.scale(
      scale: isTimer ? scale : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: dynamicColor!.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: dynamicColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: dynamicColor),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: dynamicColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(Cell cell) {
    if (cell.isRevealed!) {
      return FadeTransition(
        opacity: AlwaysStoppedAnimation(1.0),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _getAnimationDuration()),
          decoration: BoxDecoration(
            color: cell.isMine! ? Colors.red.shade200 : (cell.neighborMines! > 0 ? Colors.grey.shade100 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1,
            ),
          ),
          child: Center(
            child: cell.isMine! ?
              Icon(
                Icons.error,
                color: Colors.red.shade600,
                size: _getIconSize(),
              ) :
              cell.neighborMines! > 0 ?
                Text(
                  '${cell.neighborMines}',
                  style: TextStyle(
                    color: _getNumberColor(cell.neighborMines!),
                    fontWeight: FontWeight.bold,
                    fontSize: _getNumberFontSize(),
                  ),
                ) :
                const SizedBox(),
          ),
        ),
      );
    } else if (cell.isFlagged!) {
      return _cellContainer(
        color: Colors.yellow.shade100,
        child: Icon(
          Icons.flag_rounded,
          color: Colors.red,
          size: _getIconSize(),
        ),
      );
    } else if (_isLongPressing && _longPressCell == cell) {
      // 长按状态的视觉反馈
      return _cellContainer(
        color: Colors.yellow.shade200,
        child: Icon(
          Icons.flag_rounded,
          color: Colors.red.withOpacity(0.5),
          size: _getIconSize(),
        ),
      );
    } else if (_isTapping && _tappedCell == cell) {
      // 点击状态的视觉反馈
      return _cellContainer(
        color: Colors.grey.shade400,
        child: const SizedBox(),
      );
    } else {
      return _cellContainer(
        color: Colors.grey.shade300,
        child: const SizedBox(),
      );
    }
  }

  double _getNumberFontSize() {
    // 根据难度模式和屏幕尺寸自适应调整字体大小
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 16.0;
      case GameDifficulty.medium:
        return 14.0;
      case GameDifficulty.hard:
        return 12.0;
    }
  }

  double _getIconSize() {
    // 根据难度模式和屏幕尺寸自适应调整图标大小
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 20.0;
      case GameDifficulty.medium:
        return 18.0;
      case GameDifficulty.hard:
        return 16.0;
    }
  }

  Color _getBackgroundColor() {
    // 根据难度模式返回不同的背景颜色
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return const Color(0xFFF5F7FA); // 轻松的浅蓝色
      case GameDifficulty.medium:
        return const Color(0xFFF0F2F5); // 适中的灰色
      case GameDifficulty.hard:
        return const Color(0xFFE8EAED); // 紧张的深灰色
    }
  }

  List<Color> _getAppBarGradient() {
    // 根据难度模式返回不同的AppBar渐变
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return const [Color(0xFF4CAF50), Color(0xFF81C784)]; // 绿色渐变
      case GameDifficulty.medium:
        return const [Color(0xFF2196F3), Color(0xFF64B5F6)]; // 蓝色渐变
      case GameDifficulty.hard:
        return const [Color(0xFFF44336), Color(0xFFE57373)]; // 红色渐变
    }
  }

  int _getAnimationDuration() {
    // 根据难度模式返回不同的动画持续时间
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 300; // 简单模式，动画较慢
      case GameDifficulty.medium:
        return 200; // 中等模式，动画适中
      case GameDifficulty.hard:
        return 100; // 困难模式，动画较快，增加紧张感
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
