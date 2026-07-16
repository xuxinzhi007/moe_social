import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';
import 'life_empty_state.dart';

/// 世界地图组件 — 2D 场景，entity 位置可视化。
///
/// 支持两种渲染模式：
/// - Canvas 模式（默认）：使用 CustomPaint 批量绘制，性能更优
/// - 传统模式：Stack + AnimatedPositioned，逐实体 Widget
class LifeWorldMap extends StatelessWidget {
  final List<LifeEntity> entities;
  final String weather; // clear/rain/drought/storm
  final void Function(int entityId)? onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  /// 空状态引导关闭回调（可选）
  final VoidCallback? onEmptyDismissed;

  const LifeWorldMap({
    super.key,
    required this.entities,
    this.weather = 'clear',
    this.onEntityTap,
    this.onEntityLongPress,
    this.onEmptyDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(
            center: Alignment(-0.45, -0.72),
            radius: 1.28,
            colors: [Color(0xFFFFF6D8), Color(0xFFE2F8EA), Color(0xFFDDEBFF)],
            stops: [0, 0.52, 1],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: MoeTokens.motionFadeDuration,
          child: entities.isEmpty
              ? LifeEmptyState(
                  key: const ValueKey('empty_state'),
                  onDismissed: () => onEmptyDismissed?.call(),
                )
              : _LifeStageView(
                  key: const ValueKey('stage_content'),
                  entities: entities,
                  weather: weather,
                  onEntityTap: onEntityTap,
                  onEntityLongPress: onEntityLongPress,
                ),
        ),
      ),
    );
  }
}

class _LifeStageView extends StatelessWidget {
  final List<LifeEntity> entities;
  final String weather;
  final void Function(int entityId)? onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  const _LifeStageView({
    super.key,
    required this.entities,
    required this.weather,
    this.onEntityTap,
    this.onEntityLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _WorldBackdrop()),
        Positioned(
          left: 18,
          right: 18,
          top: 16,
          child: _StageHeader(entityCount: entities.length, weather: weather),
        ),
        Positioned.fill(
          top: 72,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: entities.length,
            itemBuilder: (context, index) {
              final entity = entities[index];
              return _StageEntityCard(
                entity: entity,
                onTap: () => onEntityTap?.call(entity.id),
                onLongPress: () => onEntityLongPress?.call(entity.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  final int entityCount;
  final String weather;

  const _StageHeader({required this.entityCount, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '生命舞台',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Text(
            '$entityCount 位居民',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7C75DD),
            ),
          ),
          const SizedBox(width: 8),
          Text(_weatherEmoji(weather), style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

String _weatherEmoji(String weather) {
  switch (weather) {
    case 'rain':
      return '🌧️';
    case 'drought':
      return '🏜️';
    case 'storm':
      return '⛈️';
    default:
      return '☀️';
  }
}

class _StageEntityCard extends StatelessWidget {
  final LifeEntity entity;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StageEntityCard({
    required this.entity,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final avg =
        ((entity.hunger + entity.energy + entity.mood) / 3).clamp(0, 100);
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: entity.growthStageColor.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: entity.growthStageColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(entity.emoji, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 8),
              Text(
                entity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                entity.actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7C75DD),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: avg / 100,
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(entity.growthStageColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldBackdrop extends StatelessWidget {
  const _WorldBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -40,
          right: -40,
          bottom: -28,
          height: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF7BCB86).withValues(alpha: 0.22),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(140)),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 28,
          child: _SceneryBubble(icon: '🌿', color: const Color(0xFF5DBB72)),
        ),
        Positioned(
          right: 26,
          top: 42,
          child: _SceneryBubble(icon: '🌸', color: const Color(0xFFFF8FB3)),
        ),
        Positioned(
          left: 36,
          bottom: 80,
          child: _SceneryBubble(icon: '🍄', color: const Color(0xFFFFA15E)),
        ),
        Positioned(
          right: 48,
          bottom: 104,
          child: _SceneryBubble(icon: '✨', color: const Color(0xFF7C75DD)),
        ),
      ],
    );
  }
}

class _SceneryBubble extends StatelessWidget {
  final String icon;
  final Color color;

  const _SceneryBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(icon, style: const TextStyle(fontSize: 20)),
    );
  }
}
