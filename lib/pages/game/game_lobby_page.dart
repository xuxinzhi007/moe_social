import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';
import '../../gacha_page.dart';
import 'game_room_list_page.dart';

class GameLobbyPage extends StatelessWidget {
  const GameLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('热门娱乐'),
                const SizedBox(height: 12),
                _buildGameCard(
                  context,
                  title: '猜大小 · 猜颜色',
                  subtitle: '多人实时对战 · 赔率 1.9x',
                  description: '猜庄家摇出的数字，每30秒一局，支持大小和颜色双下注',
                  icon: Icons.casino_rounded,
                  gradient: const [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                  onTap: () => _enterGameRoomList(context),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  context,
                  title: '扭蛋机',
                  subtitle: '5元/次 · 随机获得限定道具',
                  description: '碰碰运气，说不定出 SSR！',
                  icon: Icons.egg_alt_rounded,
                  gradient: const [Color(0xFFFF9A9E), Color(0xFFA18CD1)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GachaPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('游戏规则'),
                const SizedBox(height: 12),
                _buildRulesCard(),
              ]),
            ),
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
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              '娱乐大厅',
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

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
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
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(Icons.timer_rounded, '每局 30 秒，时间到自动开奖'),
          const SizedBox(height: 10),
          _rule(Icons.casino_rounded, '庄家摇 1-10：1-5 为小/黑，6-10 为大/红'),
          const SizedBox(height: 10),
          _rule(Icons.monetization_on_rounded, '胜出赔率 1.9x，平台抽水 10%'),
          const SizedBox(height: 10),
          _rule(Icons.layers_rounded, '可同时下注大小和颜色两组'),
          const SizedBox(height: 10),
          _rule(Icons.history_rounded, '支持查看自己的下注记录'),
          const SizedBox(height: 10),
          _rule(Icons.account_balance_wallet_rounded, '使用个人中心钱包余额'),
          const SizedBox(height: 10),
          _rule(Icons.warning_amber_rounded, '请理性游戏，量力而行'),
        ],
      ),
    );
  }

  Widget _rule(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7F7FD5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
      ],
    );
  }

  void _enterGameRoomList(BuildContext context) {
    if (AuthService.currentUser == null) {
      MoeToast.error(context, '请先登录后再进入游戏');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GameRoomListPage(),
      ),
    );
  }
}
