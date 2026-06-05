import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement_badge.dart';
import '../achievements/achievements_page.dart';

class AchievementTestPage extends StatefulWidget {
  const AchievementTestPage({super.key});

  @override
  State<AchievementTestPage> createState() => _AchievementTestPageState();
}

class _AchievementTestPageState extends State<AchievementTestPage> {
  final AchievementService _achievementService = AchievementService();
  List<AchievementBadge> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  String? get _userId => AuthService.currentUser;

  Future<void> _loadAchievements() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    await _achievementService.initializeUserBadges(userId);
    _badges = _achievementService.getUserBadges(userId);
    setState(() => _isLoading = false);
  }

  Future<void> _resetAchievements() async {
    final userId = _userId;
    if (userId == null) return;
    await _achievementService.clearUserData(userId);
    await _loadAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成就测试'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AchievementsPage()),
              );
            },
            icon: const Icon(Icons.emoji_events_rounded),
          ),
        ],
      ),
      body: _userId == null
          ? const Center(child: Text('请先登录后查看成就'))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '测试成就解锁',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _badges.length,
                          itemBuilder: (context, index) {
                            final badge = _badges[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          badge.color.withValues(alpha: 0.1),
                                      child: Text(
                                        badge.emoji,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            badge.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            badge.description,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    badge.isUnlocked
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        : Text(
                                            '${(badge.progress * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _resetAchievements,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('重置所有成就'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
