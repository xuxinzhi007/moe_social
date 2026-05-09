// 扫雷游戏主页面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';
import 'minesweeper_game_page.dart';
import 'minesweeper_config.dart';
import '../../widgets/fade_in_up.dart';

class MinesweeperLobbyPage extends StatelessWidget {
  const MinesweeperLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景装饰
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildSectionTitle('扫雷游戏'),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildDifficultyCard(
                        context,
                        title: '初级',
                        subtitle: '9x9 网格 · 10 个地雷',
                        description: '适合初学者的难度，上手简单',
                        icon: Icons.star_outline_rounded,
                        gradient: const [Color(0xFF4CAF50), Color(0xFF81C784)],
                        difficulty: GameDifficulty.easy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildDifficultyCard(
                        context,
                        title: '中级',
                        subtitle: '16x16 网格 · 40 个地雷',
                        description: '适合有一定经验的玩家',
                        icon: Icons.star_half_rounded,
                        gradient: const [Color(0xFF2196F3), Color(0xFF64B5F6)],
                        difficulty: GameDifficulty.medium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildDifficultyCard(
                        context,
                        title: '高级',
                        subtitle: '30x16 网格 · 99 个地雷',
                        description: '挑战你的极限，适合高手',
                        icon: Icons.star_rounded,
                        gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
                        difficulty: GameDifficulty.hard,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: _buildSectionTitle('游戏规则'),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 600),
                      child: _buildRulesCard(),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 70,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              '扫雷游戏',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3748),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    {
      required String title,
      required String subtitle,
      required String description,
      required IconData icon,
      required List<Color> gradient,
      required GameDifficulty difficulty
    }
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _enterGame(context, difficulty);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(Icons.touch_app_rounded, '点击格子：揭示格子内容'),
          const SizedBox(height: 12),
          _rule(Icons.flip_rounded, '长按格子：标记为地雷'),
          const SizedBox(height: 12),
          _rule(Icons.numbers_rounded, '数字：表示周围8个格子中的地雷数'),
          const SizedBox(height: 12),
          _rule(Icons.check_circle_rounded, '目标：揭示所有非地雷格子'),
          const SizedBox(height: 12),
          _rule(Icons.timer_rounded, '计时：记录完成游戏的时间'),
          const SizedBox(height: 12),
          _rule(Icons.star_rounded, '排行榜：根据时间和难度记录最佳成绩'),
        ],
      ),
    );
  }

  Widget _rule(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  void _enterGame(BuildContext context, GameDifficulty difficulty) {
    if (AuthService.currentUser == null) {
      MoeToast.error(context, '请先登录后再进入游戏');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MinesweeperGamePage(difficulty: difficulty),
      ),
    );
  }
}
