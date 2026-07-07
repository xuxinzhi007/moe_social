import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// 世界地图上单个实体精灵组件。
///
/// 显示 emoji、名称和迷你三色状态条（hunger / energy / mood）。
/// 根据成长阶段调整 emoji 大小和显示效果。
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji 头像（带成长阶段效果）
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: entity.growthStage == 'elderly' ? 0.7 : 1.0,
                child: Text(
                  entity.emoji,
                  style: TextStyle(fontSize: _emojiSize),
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
          const SizedBox(height: 2),
          // 迷你三色状态条
          _MiniStatBar(value: entity.hunger / 100, color: Colors.orange),
          _MiniStatBar(value: entity.energy / 100, color: Colors.blue),
          _MiniStatBar(value: entity.mood / 100, color: Colors.pink),
        ],
      ),
    );
  }
}

class _MiniStatBar extends StatelessWidget {
  final double value;
  final Color color;

  const _MiniStatBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: SizedBox(
        width: 32,
        height: 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 2,
          ),
        ),
      ),
    );
  }
}
