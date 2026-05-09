// 扫雷游戏排行榜页面
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../widgets/fade_in_up.dart';
import 'minesweeper_config.dart';

class MinesweeperScoreboardPage extends StatefulWidget {
  const MinesweeperScoreboardPage({super.key});

  @override
  State<MinesweeperScoreboardPage> createState() => _MinesweeperScoreboardPageState();
}

class _MinesweeperScoreboardPageState extends State<MinesweeperScoreboardPage> {
  late List<Score> _easyScores;
  late List<Score> _mediumScores;
  late List<Score> _hardScores;
  late GameDifficulty _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = GameDifficulty.easy;
    _loadScores();
  }

  void _loadScores() {
    // 模拟数据 - 实际项目中应使用本地存储
    _easyScores = [
      Score(name: '玩家1', time: 5, date: '2026-04-20'),
      Score(name: '玩家2', time: 8, date: '2026-04-19'),
      Score(name: '玩家3', time: 12, date: '2026-04-18'),
      Score(name: '玩家4', time: 15, date: '2026-04-17'),
      Score(name: '玩家5', time: 20, date: '2026-04-16'),
    ];

    _mediumScores = [
      Score(name: '玩家1', time: 25, date: '2026-04-20'),
      Score(name: '玩家2', time: 30, date: '2026-04-19'),
      Score(name: '玩家3', time: 35, date: '2026-04-18'),
      Score(name: '玩家4', time: 40, date: '2026-04-17'),
      Score(name: '玩家5', time: 45, date: '2026-04-16'),
    ];

    _hardScores = [
      Score(name: '玩家1', time: 60, date: '2026-04-20'),
      Score(name: '玩家2', time: 70, date: '2026-04-19'),
      Score(name: '玩家3', time: 80, date: '2026-04-18'),
      Score(name: '玩家4', time: 90, date: '2026-04-17'),
      Score(name: '玩家5', time: 100, date: '2026-04-16'),
    ];
  }

  List<Score> _getCurrentScores() {
    switch (_selectedDifficulty) {
      case GameDifficulty.easy:
        return _easyScores;
      case GameDifficulty.medium:
        return _mediumScores;
      case GameDifficulty.hard:
        return _hardScores;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('扫雷排行榜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      ),
      body: Column(
        children: [
          // 难度选择
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                _difficultyButton(GameDifficulty.easy, '初级', const [Color(0xFF4CAF50), Color(0xFF81C784)]),
                _difficultyButton(GameDifficulty.medium, '中级', const [Color(0xFF2196F3), Color(0xFF64B5F6)]),
                _difficultyButton(GameDifficulty.hard, '高级', const [Color(0xFFFF9800), Color(0xFFFFB74D)]),
              ],
            ),
          ),

          // 排行榜标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _columnHeader('排名')),
                Expanded(child: _columnHeader('玩家')),
                Expanded(child: _columnHeader('时间')),
                Expanded(child: _columnHeader('日期')),
              ],
            ),
          ),

          // 排行榜列表
          Expanded(
            child: ListView.builder(
              itemCount: _getCurrentScores().length,
              itemBuilder: (context, index) {
                final score = _getCurrentScores()[index];
                return FadeInUp(
                  delay: Duration(milliseconds: index * 100),
                  child: _buildScoreItem(index + 1, score),
                );
              },
            ),
          ),

          // 说明
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '排行榜说明',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 排行榜记录各难度下的最佳成绩',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 时间越短排名越高',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 仅记录完成游戏的成绩',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _difficultyButton(GameDifficulty difficulty, String label, List<Color> gradient) {
    final isSelected = _selectedDifficulty == difficulty;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficulty = difficulty;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: gradient) : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _columnHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Color(0xFF2D3748),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildScoreItem(int rank, Score score) {
    final isTopThree = rank <= 3;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: isTopThree
            ? Border.all(
                color: _getRankColor(rank),
                width: 2,
              )
            : Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
                color: isTopThree ? _getRankColor(rank) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              score.name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              _formatTime(score.time),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              score.date,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.yellow.shade600;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

// 分数类
class Score {
  final String name;
  final int time; // 秒
  final String date;

  Score({required this.name, required this.time, required this.date});
}
