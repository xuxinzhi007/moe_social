import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import 'life_entity_sprite.dart';

/// 世界地图组件 — 2D 场景，entity 位置可视化（AnimatedPositioned 平滑移动）。
class LifeWorldMap extends StatelessWidget {
  final List<LifeEntity> entities;
  final void Function(int entityId)? onEntityTap;

  const LifeWorldMap({
    super.key,
    required this.entities,
    this.onEntityTap,
  });

  /// 世界坐标范围
  static const double _worldWidth = 1280;
  static const double _worldHeight = 720;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9), // green.shade50
            Color(0xFFE3F2FD), // blue.shade50
          ],
        ),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapWidth = constraints.maxWidth;
            final mapHeight = constraints.maxHeight;

            // 坐标映射因子
            final xFactor = mapWidth / _worldWidth;
            final yFactor = mapHeight / _worldHeight;

            return Stack(
              children: [
                // 网格装饰线
                _GridDecoration(width: mapWidth, height: mapHeight),
                // Entity 精灵
                for (final entity in entities)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    left: (entity.x * xFactor) - 20, // 居中偏移
                    top: (entity.y * yFactor) - 24,
                    child: LifeEntitySprite(
                      entity: entity,
                      onTap: () => onEntityTap?.call(entity.id),
                    ),
                  ),
                // 空状态提示
                if (entities.isEmpty)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco_outlined,
                              size: 48, color: Colors.green.shade200),
                          const SizedBox(height: 8),
                          Text(
                            '等待生命出现…',
                            style: TextStyle(
                              color: Colors.green.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 地图网格装饰
class _GridDecoration extends StatelessWidget {
  final double width;
  final double height;

  const _GridDecoration({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const step = 40.0;

    // 竖线
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 横线
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
