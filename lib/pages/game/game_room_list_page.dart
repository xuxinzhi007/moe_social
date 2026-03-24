import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/fade_in_up.dart';
import 'game_room_page.dart';

class GameRoomListPage extends StatefulWidget {
  const GameRoomListPage({super.key});

  @override
  State<GameRoomListPage> createState() => _GameRoomListPageState();
}

class _GameRoomListPageState extends State<GameRoomListPage> {
  @override
  void initState() {
    super.initState();
    // 进入游戏列表页才启动全局倒计时，避免未使用游戏时空转
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GameProvider>().startTimer();
      }
    });
  }

  @override
  void dispose() {
    // 离开游戏列表页（回到主界面）时停止定时器
    context.read<GameProvider>().stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('猜大小 · 猜颜色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2D3748),
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, child) {
          final rooms = provider.rooms.values.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: _buildRoomCard(context, room, provider),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, GameRoomState room, GameProvider provider) {
    final isUrgent = room.countdown <= 5;
    final hasBet = provider.hasBet(room.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameRoomPage(roomId: room.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: room.gradient[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 背景装饰
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: room.gradient[0].withOpacity(0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: room.gradient),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.casino_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              room.description,
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '¥${room.minBet.toInt()} 起',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 倒计时和状态
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timer_rounded, color: isUrgent ? Colors.redAccent : Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  isUrgent ? '即将开奖！' : '距离开奖',
                                  style: TextStyle(
                                    color: isUrgent ? Colors.redAccent : Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${room.countdown} 秒',
                                  style: TextStyle(
                                    color: isUrgent ? Colors.redAccent : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: room.countdown / room.totalTime,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isUrgent ? Colors.redAccent : room.gradient[0],
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: hasBet ? [Colors.green, Colors.greenAccent] : room.gradient),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          hasBet ? '已下注' : '进入下注',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
