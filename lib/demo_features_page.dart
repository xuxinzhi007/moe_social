import 'package:flutter/material.dart';
import 'models/topic_tag.dart';
import 'models/gift.dart';
import 'models/achievement_badge.dart';
import 'widgets/topic_tag_selector.dart';
import 'widgets/gift_selector.dart';
import 'widgets/achievement_badge_display.dart';
import 'widgets/gift_animation.dart';
import 'services/achievement_service.dart';

/// 新功能演示页面
class DemoFeaturesPage extends StatefulWidget {
  const DemoFeaturesPage({super.key});

  @override
  State<DemoFeaturesPage> createState() => _DemoFeaturesPageState();
}

class _DemoFeaturesPageState extends State<DemoFeaturesPage> {
  List<TopicTag> _selectedTopicTags = [];
  final List<AchievementBadge> _userBadges = [];

  @override
  void initState() {
    super.initState();
    _loadUserBadges();
  }

  void _loadUserBadges() {
    // 模拟加载用户徽章数据
    setState(() {
      _userBadges.addAll([
        AchievementBadge.defaultBadges[0].copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        AchievementBadge.defaultBadges[1].copyWith(progress: 0.7),
        AchievementBadge.defaultBadges[2].copyWith(progress: 0.3),
        AchievementBadge.defaultBadges[3].copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        AchievementBadge.defaultBadges[4].copyWith(progress: 0.9),
        AchievementBadge.defaultBadges[5].copyWith(progress: 0.1),
      ]);
    });
  }

  void _showGiftAnimation(Gift gift) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => GiftSendAnimation(
        gift: gift,
        onAnimationComplete: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showBadgeUnlockAnimation() {
    final badge = AchievementBadge.defaultBadges[4]; // 使用一个示例徽章
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => BadgeUnlockAnimation(
        badgeName: badge.name,
        badgeEmoji: badge.emoji,
        badgeColor: badge.color,
        onAnimationComplete: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('新功能演示'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 功能介绍卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 三大新功能上线！',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 话题标签系统 - 创建和分享话题\n• 互动礼物系统 - 传递温暖心意\n• 成就徽章系统 - 记录精彩时刻',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 话题标签功能区
            _buildSectionCard(
              title: '🏷️ 话题标签系统',
              subtitle: '选择或创建你的话题',
              child: Column(
                children: [
                  TopicTagSelector(
                    selectedTags: _selectedTopicTags,
                    onTagsChanged: (tags) {
                      setState(() {
                        _selectedTopicTags = tags;
                      });
                    },
                    userId: 'demo_user',
                    maxTags: 3,
                  ),
                  if (_selectedTopicTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '已选择的话题标签：',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedTopicTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tag.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: tag.color.withOpacity(0.5)),
                                ),
                                child: Text(
                                  tag.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tag.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 礼物系统功能区
            _buildSectionCard(
              title: '🎁 互动礼物系统',
              subtitle: '送出温暖的礼物',
              child: Column(
                children: [
                  const Text(
                    '选择一个礼物发送给好友：',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: Gift.getPopularGifts(limit: 6).map((gift) {
                      return GestureDetector(
                        onTap: () => _showGiftAnimation(gift),
                        child: Container(
                          width: 80,
                          height: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gift.color.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(gift.emoji, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 4),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '¥${gift.price.toStringAsFixed(gift.price == gift.price.roundToDouble() ? 0 : 1)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: gift.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '点击礼物查看发送动画效果',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 成就徽章功能区
            _buildSectionCard(
              title: '🏆 成就徽章系统',
              subtitle: '收集属于你的荣誉',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '我的徽章收藏',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showBadgeUnlockAnimation,
                        icon: const Icon(Icons.celebration, size: 16),
                        label: const Text('解锁动画'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BadgeGrid(
                    badges: _userBadges,
                    badgeSize: 70,
                    crossAxisCount: 4,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              '成就进度',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatColumn('已解锁', '2', Colors.green),
                            _buildStatColumn('进行中', '3', Colors.orange),
                            _buildStatColumn('总数量', '15', Colors.blue),
                            _buildStatColumn('完成度', '13%', Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 使用说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        '使用提示',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• 话题标签：发布动态时可以选择或创建话题标签，让内容更有条理\n'
                    '• 互动礼物：在帖子下方点击礼物按钮，向作者发送虚拟礼物\n'
                    '• 成就徽章：完成各种社交行为即可解锁对应的成就徽章',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}