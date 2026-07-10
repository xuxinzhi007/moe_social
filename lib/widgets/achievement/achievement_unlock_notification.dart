import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../models/achievement_badge.dart';
import '../../../models/gift.dart';
import '../motion/category_particle_vfx.dart';
import '../motion/moe_reveal.dart';
import '../motion/moe_sheet.dart';
import '../motion/moe_vfx_profile.dart';
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
  static const _displayDuration = Duration(seconds: 4);

  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
      _autoCloseTimer = Timer(_displayDuration, _dismiss);
    });
  }

  Future<void> _dismiss() async {
    _autoCloseTimer?.cancel();
    if (!mounted) return;

    final reduceMotion = MoeVfxProfile.fromContext(context).reduceMotion;
    if (reduceMotion || _controller.status == AnimationStatus.dismissed) {
      widget.onClose?.call();
      return;
    }

    await _controller.reverse();
    if (mounted) {
      widget.onClose?.call();
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final profile = MoeVfxProfile.fromContext(context);
    final medallionSize = profile.isCompact ? 52.0 : 60.0;

    final notificationCard = Container(
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
            color: badge.rarity.tierGradient.last.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: medallionSize + 8,
            height: medallionSize + 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!profile.reduceMotion && profile.enableBurstParticles)
                  CustomPaint(
                    painter: CategoryParticleClusterPainter(
                      targets: CategoryParticleVfx.shapePoints(
                        GiftCategory.special,
                        profile.scaledCoreCount(12),
                      ),
                      primaryColor: badge.color,
                      secondaryColor: badge.color.withValues(alpha: 0.5),
                      converge: 1,
                      pulse: _fadeAnimation.value,
                      expand: 0,
                      seed: badge.id.hashCode,
                      dominantShape: 1,
                    ),
                    size: Size(
                      medallionSize + 8,
                      medallionSize + 8,
                    ),
                  ),
                AchievementBadgeMedallion(
                  badge: badge,
                  diameter: medallionSize,
                  unlocked: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '鎴愬氨瑙ｉ攣',
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
                  GestureDetector(
                    onTap: widget.onView,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: const Text(
                        '鏌ョ湅鎴愬氨涓績',
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
          IconButton(
            onPressed: _dismiss,
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: profile.reduceMotion
          ? notificationCard
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: notificationCard,
                ),
              ),
            ),
    );
  }
}

class AchievementNotificationManager {
  static OverlayEntry? _currentEntry;

  static void showUnlockNotification(
    BuildContext context,
    AchievementBadge badge, {
    VoidCallback? onView,
  }) {
    _currentEntry?.remove();

    final theme = Theme.of(context);
    _currentEntry = OverlayEntry(
      builder: (overlayContext) {
        final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
        return Positioned(
          bottom: bottomInset + 16,
          right: 0,
          left: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Theme(
              data: theme,
              child: AchievementUnlockNotification(
                badge: badge,
                onView: onView,
                onClose: () {
                  _currentEntry?.remove();
                  _currentEntry = null;
                },
              ),
            ),
          ),
        );
      },
    );

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    overlay.insert(_currentEntry!);
  }

  static Future<void> showBottomGuideSheet(
    BuildContext context, {
    required int unlockedCount,
    required VoidCallback onViewAchievements,
  }) async {
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    try {
      await MoeSheet.show<void>(
        context,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SafeArea(
              top: false,
              child: Container(
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
                    const MoeReveal(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF7F7FD5),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MoeReveal(
                        delay: const Duration(milliseconds: 30),
                        child: Text(
                          '澶浜嗭紝杩欐瑙ｉ攣浜?$unlockedCount 涓垚灏憋紝鍘绘垚灏变腑蹇冪湅鐪嬪畬鏁磋繘搴﹀惂',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MoeReveal(
                      delay: const Duration(milliseconds: 60),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onViewAchievements();
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {}
  }
}
