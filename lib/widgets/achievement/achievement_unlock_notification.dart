import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../models/achievement_badge.dart';
import 'achievement_badge_medallion.dart';

class AchievementUnlockNotification extends StatefulWidget {
  final AchievementBadge badge;
  final VoidCallback? onClose;

  const AchievementUnlockNotification({
    super.key,
    required this.badge,
    this.onClose,
  });

  @override
  State<AchievementUnlockNotification> createState() => _AchievementUnlockNotificationState();
}

class _AchievementUnlockNotificationState extends State<AchievementUnlockNotification> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );

    // 延迟启动动画
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });

    // 自动关闭
    Future.delayed(const Duration(seconds: 3), () {
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
            ..translate(_slideAnimation.value, 0.0)
            ..scale(_scaleAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
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
                    color: badge.rarity.tierGradient.last.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  static void showUnlockNotification(BuildContext context, AchievementBadge badge) {
    // 先移除之前的通知
    _currentEntry?.remove();

    // 创建新的通知
    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 80,
          right: 0,
          left: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: AchievementUnlockNotification(
              badge: badge,
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
    Overlay.of(context)?.insert(_currentEntry!);
  }
}
