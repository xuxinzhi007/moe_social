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
    with TickerProviderStateMixin {
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

  /// 微动动画，让静止实体也保留生命感。
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    // 与 Flame 路径对齐：拉长插值，减弱「跳一下」的顿挫感。
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
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
    _ambientController.dispose();
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
            animation: Listenable.merge([_animController, _ambientController]),
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
                  ambientProgress: _ambientController.value,
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
  final double ambientProgress;

  LifeWorldCanvasPainter({
    required this.renderDataList,
    required this.weather,
    required this.prevPositions,
    required this.animProgress,
    required this.xFactor,
    required this.yFactor,
    required this.particles,
    required this.ambientProgress,
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

  String _actionIcon(String? action) {
    switch (action) {
      case 'sleeping':
        return 'Zz';
      case 'seeking_food':
      case 'eating':
        return '🍃';
      case 'talking':
        return '♪';
      case 'reproducing':
        return '♡';
      case 'dying':
        return '!';
      case 'seeking_rest':
        return '…';
      default:
        return '';
    }
  }

  String _needHint(EntityRenderData rd) {
    if (rd.hunger < 30) return '饿了';
    if (rd.energy < 25) return '困了';
    if (rd.mood < 30) return '想陪伴';
    return '';
  }

  double _stageScale(String stage) {
    switch (stage) {
      case 'juvenile':
        return 0.82;
      case 'adolescent':
        return 0.94;
      case 'adult':
        return 1.12;
      case 'elderly':
        return 1.02;
      default:
        return 1.0;
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

      final phase = ambientProgress * pi * 2 + rd.id * 0.7;
      final isSleeping = rd.action == 'sleeping';
      final isMoving = rd.action == 'walking' ||
          rd.action == 'wandering' ||
          rd.action == 'seeking_food' ||
          rd.action == 'seeking_rest';
      final bob = isSleeping
          ? sin(phase) * 1.0
          : isMoving
              ? sin(phase * 1.8) * 2.2
              : sin(phase) * 0.8;
      final pulse = isSleeping ? 0.94 + sin(phase) * 0.04 : 1.0;
      final opacity =
          rd.action == 'dying' || rd.growthStage == 'elderly' ? 0.72 : 1.0;
      final stageScale = _stageScale(rd.growthStage);

      // --- 阴影 ---
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(screenX, screenY + baseFontSize * 0.68),
          width: baseFontSize * stageScale * 1.35,
          height: 7,
        ),
        shadowPaint,
      );

      final drawCenter = Offset(screenX, screenY + bob);

      // --- 健康色环 ---
      final ringPaint = Paint()
        ..color = rd.healthColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final ringRadius = baseFontSize * 0.8 * stageScale * pulse;
      canvas.drawCircle(drawCenter, ringRadius, ringPaint);

      // --- Emoji ---
      final emojiPainter = TextPainter(
        text: TextSpan(
          text: rd.emoji,
          style: TextStyle(
            fontSize: baseFontSize * stageScale * pulse,
            color: Colors.black.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      emojiPainter.layout();
      emojiPainter.paint(
        canvas,
        Offset(
          drawCenter.dx - emojiPainter.width / 2,
          drawCenter.dy - emojiPainter.height / 2,
        ),
      );

      // --- 成长阶段色点（右下角） ---
      final dotOffset = Offset(
        drawCenter.dx + ringRadius * 0.6,
        drawCenter.dy + ringRadius * 0.6,
      );
      final dotPaint = Paint()..color = rd.stageColor;
      canvas.drawCircle(dotOffset, 3.0, dotPaint);
      // 白色描边
      final dotBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(dotOffset, 3.0, dotBorderPaint);

      final actionIcon = _actionIcon(rd.action);
      if (actionIcon.isNotEmpty) {
        _paintBadge(
          canvas,
          actionIcon,
          Offset(drawCenter.dx + ringRadius * 0.55,
              drawCenter.dy - ringRadius * 0.9),
          color: rd.action == 'dying'
              ? Colors.red.shade600
              : const Color(0xFF6A4C93),
        );
      }

      if (rd.activeEffects.isNotEmpty) {
        final effects = rd.activeEffects.take(2).toList();
        for (var i = 0; i < effects.length; i++) {
          _paintSmallEmoji(
            canvas,
            effects[i].icon,
            Offset(
              drawCenter.dx - ringRadius * 0.8 + i * 15,
              drawCenter.dy - ringRadius * 0.95,
            ),
          );
        }
      }

      final needHint = _needHint(rd);
      if (needHint.isNotEmpty) {
        _paintNeedBubble(
          canvas,
          needHint,
          Offset(drawCenter.dx, drawCenter.dy - ringRadius - 24),
        );
      }

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
          drawCenter.dy + ringRadius + 2,
        ),
      );
    }
  }

  void _paintBadge(Canvas canvas, String text, Offset center,
      {required Color color}) {
    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(center, 10, bgPaint);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: text.length > 1 ? 9 : 13,
            color: color,
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 24);
    painter.paint(canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _paintSmallEmoji(Canvas canvas, String emoji, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawCircle(
        center, 8, Paint()..color = Colors.white.withValues(alpha: 0.9));
    painter.paint(canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _paintNeedBubble(Canvas canvas, String text, Offset anchor) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF4A3D4F),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 48);
    final rect = Rect.fromCenter(
      center: anchor,
      width: painter.width + 14,
      height: painter.height + 8,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
        rrect, Paint()..color = Colors.white.withValues(alpha: 0.94));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas,
        Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant LifeWorldCanvasPainter oldDelegate) {
    return !identical(oldDelegate.renderDataList, renderDataList) ||
        oldDelegate.weather != weather ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        !identical(oldDelegate.particles, particles);
  }
}
