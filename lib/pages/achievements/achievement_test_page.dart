import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement_badge.dart';
import '../achievements/achievements_page.dart';
import '../../widgets/achievement/achievement_unlock_notification.dart';

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

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    await _achievementService.initializeUserBadges('user_123');
    _badges = _achievementService.getUserBadges('user_123');
    setState(() => _isLoading = false);
  }

  Future<void> _unlockBadge(String badgeId) async {
    final newlyUnlocked = await _achievementService.updateBadgeProgress('user_123', badgeId, 9999);
    if (newlyUnlocked.isNotEmpty) {
      for (final badge in newlyUnlocked) {
        AchievementNotificationManager.showUnlockNotification(context, badge);
      }
      await _loadAchievements();
    }
  }

  Future<void> _resetAchievements() async {
    await _achievementService.clearUserData('user_123');
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
                MaterialPageRoute(builder: (context) => const AchievementsPage()),
              );
            },
            icon: const Icon(Icons.emoji_events_rounded),
          ),
        ],
      ),
      body: _isLoading
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
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: badge.color.withOpacity(0.1),
                              child: Icon(badge.badgeSymbol, color: badge.color),
                            ),
                            title: Text(badge.name),
                            subtitle: Text(badge.description),
                            trailing: badge.isUnlocked
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : ElevatedButton(
                                    onPressed: () => _unlockBadge(badge.id),
                                    child: const Text('解锁'),
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
