import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/life_state.dart';

/// 反馈粒子 — 在指定世界坐标处显示上浮 emoji 动画。
class _FeedbackParticle {
  final String emoji;
  final double worldX;
  final double worldY;
  final DateTime startTime;
  final Duration duration = const Duration(milliseconds: 1200);

  _FeedbackParticle({
    required this.emoji,
    required this.worldX,
    required this.worldY,
    required this.startTime,
  });

  /// 粒子是否已过期
  bool get isExpired => DateTime.now().difference(startTime) >= duration;

  /// 生命进度 0.0 → 1.0
  double get progress {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    return (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Canvas 世界画布视图 — 使用 CustomPaint 替代 N 个 AnimatedPositioned，
/// 在单一 Canvas 上绘制网格、天气、实体精灵，性能更优。
class LifeWorldCanvas extends StatefulWidget {
  final List<LifeEntity> entities;
  final String weather;
  final void Function(int entityId)? onEntityTap;
  final void Function(int entityId)? onEntityLongPress;

  /// 世界坐标范围
  static const double worldWidth = 1280;
  static const double worldHeight = 720;

  const LifeWorldCanvas({
    super.key,
    required this.entities,
    this.weather = 'clear',
    this.onEntityTap,
    this.onEntityLongPress,
  });

  @override
  State<LifeWorldCanvas> createState() => _LifeWorldCanvasState();
}

class _LifeWorldCanvasState extends State<LifeWorldCanvas>
    with SingleTickerProviderStateMixin {
  /// 位置插值动画控制器（500ms 平滑过渡）
  late final AnimationController _animController;

  /// 上一帧实体世界坐标缓存（id → Offset）
  Map<int, Offset> _prevPositions = {};

  /// 预计算渲染数据列表
  List<EntityRenderData> _renderDataList = [];

  /// 当前画布尺寸
  Size _canvasSize = Size.zero;

  /// 活跃反馈粒子列表
  final List<_FeedbackParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _updateRenderData();
    // 初始位置直接设为目标位置（不做动画）
    for (final rd in _renderDataList) {
      _prevPositions[rd.id] = Offset(rd.worldX, rd.worldY);
    }
    _animController.value = 1.0;
    // 粒子重绘监听：每帧检查并移除过期粒子
    _animController.addListener(_tickParticles);
  }

  /// 每帧清理过期粒子并触发重绘
  void _tickParticles() {
    _particles.removeWhere((p) => p.isExpired);
    // setState 由 AnimatedBuilder 自动处理
  }

  /// 公开方法：在世界坐标处添加反馈粒子。
  void addFeedback(double worldX, double worldY, String emoji) {
    setState(() {
      _particles.add(_FeedbackParticle(
        emoji: emoji,
        worldX: worldX,
        worldY: worldY,
        startTime: DateTime.now(),
      ));
    });
  }

  @override
  void didUpdateWidget(covariant LifeWorldCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entities, widget.entities)) {
      // 保存旧位置作为插值起点
      final oldPositions = <int, Offset>{};
      for (final rd in _renderDataList) {
        oldPositions[rd.id] = Offset(rd.worldX, rd.worldY);
      }
      _updateRenderData();
      // 对新实体使用默认位置（屏幕中心）
      for (final rd in _renderDataList) {
        if (!oldPositions.containsKey(rd.id)) {
          oldPositions[rd.id] = Offset(rd.worldX, rd.worldY);
        }
      }
      _prevPositions = oldPositions;
      _animController.forward(from: 0);
    }
  }

  void _updateRenderData() {
    _renderDataList = widget.entities.map((e) => e.toRenderData()).toList();
  }

  @override
  void dispose() {
    _animController.removeListener(_tickParticles);
    _animController.dispose();
    super.dispose();
  }

  /// 命中测试：触摸像素坐标 → 世界坐标 → 最近实体
  int? _hitTest(Offset localPosition, Size canvasSize) {
    final xFactor = canvasSize.width / LifeWorldCanvas.worldWidth;
    final yFactor = canvasSize.height / LifeWorldCanvas.worldHeight;

    // 触摸像素 → 世界坐标
    final worldX = localPosition.dx / xFactor;
    final worldY = localPosition.dy / yFactor;

    // 命中阈值：44dp 映射回世界坐标
    final hitRadiusWorld = 44.0 / xFactor;

    int? closestId;
    double closestDist = double.infinity;

    final progress = _animController.value;
    for (final rd in _renderDataList) {
      final prevPos = _prevPositions[rd.id] ?? Offset(rd.worldX, rd.worldY);
      final targetPos = Offset(rd.worldX, rd.worldY);
      final currentPos = Offset.lerp(prevPos, targetPos, progress)!;

      final dx = currentPos.dx - worldX;
      final dy = currentPos.dy - worldY;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < hitRadiusWorld && dist < closestDist) {
        closestDist = dist;
        closestId = rd.id;
      }
    }
    return closestId;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final xFactor = _canvasSize.width / LifeWorldCanvas.worldWidth;
        final yFactor = _canvasSize.height / LifeWorldCanvas.worldHeight;

        return GestureDetector(
          onTapUp: (details) {
            final id = _hitTest(details.localPosition, _canvasSize);
            if (id != null) widget.onEntityTap?.call(id);
          },
          onLongPressStart: (details) {
            final id = _hitTest(details.localPosition, _canvasSize);
            if (id != null) widget.onEntityLongPress?.call(id);
          },
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                size: _canvasSize,
                painter: LifeWorldCanvasPainter(
                  renderDataList: _renderDataList,
                  weather: widget.weather,
                  prevPositions: _prevPositions,
                  animProgress: _animController.value,
                  xFactor: xFactor,
                  yFactor: yFactor,
                  particles: List.of(_particles),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Canvas 绘制器 — 依次绘制网格、天气、实体精灵
class LifeWorldCanvasPainter extends CustomPainter {
  final List<EntityRenderData> renderDataList;
  final String weather;
  final Map<int, Offset> prevPositions;
  final double animProgress;
  final double xFactor;
  final double yFactor;
  final List<Object> particles;

  LifeWorldCanvasPainter({
    required this.renderDataList,
    required this.weather,
    required this.prevPositions,
    required this.animProgress,
    required this.xFactor,
    required this.yFactor,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintWeather(canvas, size);
    _paintEntities(canvas, size);
    _paintParticles(canvas);
  }

  /// 4. 反馈粒子 — emoji 上浮 + 透明度衰减
  void _paintParticles(Canvas canvas) {
    final fontSize = 18.0;
    for (final obj in particles) {
      final p = obj as _FeedbackParticle;
      if (p.isExpired) continue;
      final progress = p.progress;
      final opacity = 1.0 - progress;
      // 上浮偏移（世界坐标下 y 递减）
      final floatY = p.worldY - progress * 40;
      final screenX = p.worldX * xFactor;
      final screenY = floatY * yFactor;

      final painter = TextPainter(
        text: TextSpan(
          text: p.emoji,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.black.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(screenX - painter.width / 2, screenY - painter.height / 2),
      );
    }
  }

  /// 1. 网格背景 — 细线浅色
  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// 2. 天气图层
  void _paintWeather(Canvas canvas, Size size) {
    switch (weather) {
      case 'rain':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.blue.withValues(alpha: 0.1),
        );
        final rainPaint = Paint()..color = Colors.blue.withValues(alpha: 0.4);
        final rng = Random(42);
        for (int i = 0; i < 30; i++) {
          final x = rng.nextDouble() * size.width;
          final y = rng.nextDouble() * size.height;
          canvas.drawCircle(Offset(x, y), 1.5, rainPaint);
        }
        break;
      case 'drought':
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.brown.withValues(alpha: 0.15),
        );
        break;
      case 'storm':
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
        break;
    }
  }

  /// 3. 实体精灵 — emoji + 健康色环 + 成长阶段色点 + 名称标签
  void _paintEntities(Canvas canvas, Size size) {
    // 根据屏幕宽度自适应 emoji 字号
    final baseFontSize = (size.width / 20).clamp(16.0, 32.0);

    for (final rd in renderDataList) {
      // 位置插值
      final prevPos = prevPositions[rd.id] ?? Offset(rd.worldX, rd.worldY);
      final targetPos = Offset(rd.worldX, rd.worldY);
      final currentPos = Offset.lerp(prevPos, targetPos, animProgress)!;

      // 世界坐标 → 屏幕像素
      final screenX = currentPos.dx * xFactor;
      final screenY = currentPos.dy * yFactor;
      final center = Offset(screenX, screenY);

      // --- 健康色环 ---
      final ringPaint = Paint()
        ..color = rd.healthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final ringRadius = baseFontSize * 0.8;
      canvas.drawCircle(center, ringRadius, ringPaint);

      // --- Emoji ---
      final emojiPainter = TextPainter(
        text: TextSpan(
          text: rd.emoji,
          style: TextStyle(fontSize: baseFontSize),
        ),
        textDirection: TextDirection.ltr,
      );
      emojiPainter.layout();
      emojiPainter.paint(
        canvas,
        Offset(
          screenX - emojiPainter.width / 2,
          screenY - emojiPainter.height / 2,
        ),
      );

      // --- 成长阶段色点（右下角） ---
      final dotOffset = Offset(
        screenX + ringRadius * 0.6,
        screenY + ringRadius * 0.6,
      );
      final dotPaint = Paint()..color = rd.stageColor;
      canvas.drawCircle(dotOffset, 3.0, dotPaint);
      // 白色描边
      final dotBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(dotOffset, 3.0, dotBorderPaint);

      // --- 名称标签（emoji 下方） ---
      final namePainter = TextPainter(
        text: TextSpan(
          text: rd.name,
          style: TextStyle(
            fontSize: 10,
            color: Colors.black87,
            background: Paint()..color = Colors.white.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );
      namePainter.layout(maxWidth: 80);
      namePainter.paint(
        canvas,
        Offset(
          screenX - namePainter.width / 2,
          screenY + ringRadius + 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LifeWorldCanvasPainter oldDelegate) {
    return !identical(oldDelegate.renderDataList, renderDataList) ||
        oldDelegate.weather != weather ||
        oldDelegate.animProgress != animProgress ||
        !identical(oldDelegate.particles, particles);
  }
}
