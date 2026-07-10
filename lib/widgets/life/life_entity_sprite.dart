import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// 世界地图上单个实体精灵组件。
///
/// 显示 emoji、名称和综合健康色环。
/// 触摸目标 >= 44x44dp，符合移动端可访问性标准。
class LifeEntitySprite extends StatelessWidget {
  final LifeEntity entity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LifeEntitySprite({
    super.key,
    required this.entity,
    this.onTap,
    this.onLongPress,
  });

  /// 根据成长阶段返回 emoji 大小。
  double get _emojiSize {
    switch (entity.growthStage) {
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
    final avg = (entity.hunger + entity.energy + entity.mood) / 3;
    if (avg >= 70) return Colors.green;
    if (avg >= 40) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji 头像 + 健康色环 + 成长阶段标记
            Stack(
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
                    opacity: entity.growthStage == 'elderly' ? 0.7 : 1.0,
                    child: Text(
                      entity.emoji,
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
                      color: entity.growthStageColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
                // Buff 效果图标（右上方）
                if (entity.activeEffects.isNotEmpty)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: _BuffIcons(effects: entity.activeEffects),
                  ),
              ],
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
                entity.name,
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
