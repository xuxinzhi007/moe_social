import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';
import 'life_empty_state.dart';
import 'life_entity_sprite.dart';
import 'life_world_canvas.dart';

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

  /// 是否使用 Canvas 渲染路径（默认 true）
  final bool useCanvas;

  /// 空状态引导关闭回调（可选）
  final VoidCallback? onEmptyDismissed;

  const LifeWorldMap({
    super.key,
    required this.entities,
    this.weather = 'clear',
    this.onEntityTap,
    this.onEntityLongPress,
    this.useCanvas = true,
    this.onEmptyDismissed,
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
        child: AnimatedSwitcher(
          duration: MoeTokens.motionFadeDuration,
          child: entities.isEmpty
              ? LifeEmptyState(
                  key: const ValueKey('empty_state'),
                  onDismissed: () => onEmptyDismissed?.call(),
                )
              : Semantics(
                  key: const ValueKey('map_content'),
                  label: '世界地图，${entities.length} 个实体',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final mapWidth = constraints.maxWidth;
                      final mapHeight = constraints.maxHeight;

                      // 坐标映射因子
                      final xFactor = mapWidth / _worldWidth;
                      final yFactor = mapHeight / _worldHeight;

                      return Stack(
                        children: [
                          // Canvas 渲染路径 或 传统 Stack+AnimatedPositioned 路径
                          if (useCanvas)
                            LifeWorldCanvas(
                              entities: entities,
                              weather: weather,
                              onEntityTap: onEntityTap,
                              onEntityLongPress: onEntityLongPress,
                            )
                          else
                            ..._buildLegacyEntities(xFactor, yFactor),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  /// 传统渲染路径：网格 + 天气 + AnimatedPositioned 实体
  List<Widget> _buildLegacyEntities(double xFactor, double yFactor) {
    return [
      // 网格装饰线
      _GridDecoration(
        width: xFactor * _worldWidth,
        height: yFactor * _worldHeight,
      ),
      // 天气图层
      RepaintBoundary(
        child: _WeatherLayer(
          weather: weather,
          width: xFactor * _worldWidth,
          height: yFactor * _worldHeight,
        ),
      ),
      // Entity 精灵
      for (final entity in entities)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          left: (entity.x * xFactor) - 20,
          top: (entity.y * yFactor) - 24,
          child: LifeEntitySprite(
            entity: entity,
            onTap: () => onEntityTap?.call(entity.id),
            onLongPress: () => onEntityLongPress?.call(entity.id),
          ),
        ),
    ];
  }
}

/// 天气图层组件 — 仅在 weather 变化时重绘。
class _WeatherLayer extends StatelessWidget {
  final String weather;
  final double width;
  final double height;

  const _WeatherLayer({
    required this.weather,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _WeatherPainter(weather: weather),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final String weather;
  final Random _rng = Random(42); // 固定种子保证稳定渲染

  _WeatherPainter({required this.weather});

  @override
  void paint(Canvas canvas, Size size) {
    switch (weather) {
      case 'rain':
        // 半透明蓝色遮罩
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.blue.withValues(alpha: 0.1),
        );
        // 雨滴粒子（上限 30 个）
        final rainPaint = Paint()..color = Colors.blue.withValues(alpha: 0.4);
        for (int i = 0; i < 30; i++) {
          final x = _rng.nextDouble() * size.width;
          final y = _rng.nextDouble() * size.height;
          canvas.drawCircle(Offset(x, y), 1.5, rainPaint);
        }
        break;
      case 'drought':
        // 黄褐色覆盖
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.brown.withValues(alpha: 0.15),
        );
        break;
      case 'storm':
        // 红色脉冲边框
        final borderPaint = Paint()
          ..color = Colors.red.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          borderPaint,
        );
        break;
      default:
        // clear — 不绘制
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.weather != weather;
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
