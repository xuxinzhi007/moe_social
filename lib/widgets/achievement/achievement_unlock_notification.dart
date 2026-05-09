import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../models/achievement_badge.dart';
import 'achievement_badge_medallion.dart';

class AchievementUnlockNotification extends StatefulWidget {
  final AchievementBadge badge;
  final VoidCallback? onClose;
  final VoidCallback? onView;

  const AchievementUnlockNotification({
    super.key,
    required this.badge,
    this.onClose,
    this.onView,
  });

  @override
  State<AchievementUnlockNotification> createState() =>
      _AchievementUnlockNotificationState();
}

class _AchievementUnlockNotificationState
    extends State<AchievementUnlockNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 300, end: 0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );

    // 延迟启动动画
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });

    // 自动关闭
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onClose?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(_slideAnimation.value, 0.0, 0.0, 1.0)
            ..scaleByDouble(
                _scaleAnimation.value, _scaleAnimation.value, 1.0, 1.0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badge.rarity.tierGradient.first,
                    badge.rarity.tierGradient.last,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        badge.rarity.tierGradient.last.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 徽章图标
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: AchievementBadgeMedallion(
                      badge: badge,
                      diameter: 60,
                      unlocked: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 通知内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '成就解锁！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badge.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.onView != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: widget.onView,
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: const Text(
                                '查看成就中心',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 关闭按钮
                  IconButton(
                    onPressed: () {
                      _controller.reverse().then((_) {
                        widget.onClose?.call();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// 全局通知管理
class AchievementNotificationManager {
  static OverlayEntry? _currentEntry;

  static void showUnlockNotification(
    BuildContext context,
    AchievementBadge badge, {
    VoidCallback? onView,
  }) {
    // 先移除之前的通知
    _currentEntry?.remove();

    // 创建新的通知
    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 24,
          right: 0,
          left: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AchievementUnlockNotification(
              badge: badge,
              onView: onView,
              onClose: () {
                _currentEntry?.remove();
                _currentEntry = null;
              },
            ),
          ),
        );
      },
    );

    // 添加到overlay
    Overlay.of(context).insert(_currentEntry!);
  }

  static Future<void> showBottomGuideSheet(
    BuildContext context, {
    required int unlockedCount,
    required VoidCallback onViewAchievements,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7F7FD5).withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF7F7FD5), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '太棒了！本次解锁 $unlockedCount 个成就，去成就中心看看完整进度吧',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onViewAchievements();
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    backgroundColor: const Color(0xFF7F7FD5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '去查看',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
