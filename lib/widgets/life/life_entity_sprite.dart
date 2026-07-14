import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// 世界地图上单个实体精灵组件。
///
/// 显示 emoji、名称和综合健康色环。
/// 触摸目标 >= 44x44dp，符合移动端可访问性标准。
/// 行为变化时使用 AnimatedSwitcher 过渡，sleeping 状态有呼吸缩放动画。
class LifeEntitySprite extends StatefulWidget {
  final LifeEntity entity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LifeEntitySprite({
    super.key,
    required this.entity,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<LifeEntitySprite> createState() => _LifeEntitySpriteState();
}

class _LifeEntitySpriteState extends State<LifeEntitySprite>
    with SingleTickerProviderStateMixin {
  /// 呼吸动画控制器（sleeping 状态：scale 0.95 ↔ 1.0，2s 循环）
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _breathAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    // 如果初始状态是 sleeping，启动呼吸动画
    if (widget.entity.action == 'sleeping') {
      _breathController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LifeEntitySprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测 action 变化，控制呼吸动画
    if (widget.entity.action != oldWidget.entity.action) {
      if (widget.entity.action == 'sleeping') {
        _breathController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _breathController.reset();
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  /// 根据成长阶段返回 emoji 大小。
  double get _emojiSize {
    switch (widget.entity.growthStage) {
      case 'juvenile':
        return 20;
      case 'adolescent':
        return 26;
      case 'adult':
        return 32;
      case 'elderly':
        return 30;
      default:
        return 26;
    }
  }

  /// 综合健康度色环：(hunger + energy + mood) / 3
  Color get _healthColor {
    final avg = (widget.entity.hunger + widget.entity.energy + widget.entity.mood) / 3;
    if (avg >= 70) return Colors.green;
    if (avg >= 40) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji 头像 + 健康色环 + 成长阶段标记
            // 使用 AnimatedSwitcher 在 action 变化时过渡（fade + scale，300ms）
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: _buildSpriteStack(),
            ),
            const SizedBox(height: 2),
            // 名称标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.entity.name,
                style: const TextStyle(fontSize: 10, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建精灵 Stack（emoji + 色环 + buff 图标）
  Widget _buildSpriteStack() {
    // sleeping 状态使用呼吸动画，其他状态无额外动画
    final spriteContent = Stack(
      key: ValueKey(widget.entity.action), // AnimatedSwitcher 根据 action 切换
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 综合健康色环
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _healthColor,
              width: 2,
            ),
          ),
          child: Opacity(
            opacity: widget.entity.growthStage == 'elderly' ? 0.7 : 1.0,
            child: Text(
              widget.entity.emoji,
              style: TextStyle(fontSize: _emojiSize),
            ),
          ),
        ),
        // 成长阶段小色点标记（右下角）
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.entity.growthStageColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
        // Buff 效果图标（右上方）
        if (widget.entity.activeEffects.isNotEmpty)
          Positioned(
            right: -8,
            top: -6,
            child: _BuffIcons(effects: widget.entity.activeEffects),
          ),
      ],
    );

    if (widget.entity.action == 'sleeping') {
      // sleeping 状态：应用呼吸缩放动画
      return AnimatedBuilder(
        animation: _breathAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _breathAnimation.value,
            child: child,
          );
        },
        child: spriteContent,
      );
    }
    return spriteContent;
  }
}

/// 活跃 buff 效果图标组件。
///
/// 最多显示 2 个图标 + 如果更多显示 "+N"。
class _BuffIcons extends StatelessWidget {
  final List<ActiveEffectSummary> effects;

  const _BuffIcons({required this.effects});

  @override
  Widget build(BuildContext context) {
    const int maxShow = 2;
    final show = effects.take(maxShow).toList();
    final extra = effects.length - maxShow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final eff in show)
          Container(
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(1),
            child: Text(
              eff.icon,
              style: const TextStyle(fontSize: 12, height: 1),
            ),
          ),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '+$extra',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}
