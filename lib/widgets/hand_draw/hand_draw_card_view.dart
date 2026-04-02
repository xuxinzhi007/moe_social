import 'package:flutter/material.dart';
import '../../models/hand_draw_card.dart';

/// 根据 [HandDrawCardData] 绘制卡片（可全量或按 [progress] 0~1 回放）
class HandDrawCardPainter extends CustomPainter {
  HandDrawCardPainter({
    required this.data,
    this.progress = 1.0,
  });

  final HandDrawCardData data;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Color(data.backgroundArgb);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final shortSide = size.shortestSide;
    var total = _totalSegments(data);
    if (total < 1) total = 1;
    final budget = (progress.clamp(0.0, 1.0) * total).floor();

    var used = 0;
    for (final stroke in data.strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = Color(stroke.colorArgb)
        ..strokeWidth = (stroke.widthNorm * shortSide).clamp(1.5, 24)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final pts = stroke.points;
      if (pts.length == 1) {
        if (used < budget) {
          final o = HandDrawCardCodec.toPixel(pts[0], size);
          canvas.drawCircle(
            o,
            strokePaint.strokeWidth / 2,
            strokePaint..style = PaintingStyle.fill,
          );
          used += 1;
        }
        continue;
      }

      for (var i = 0; i < pts.length - 1; i++) {
        if (used >= budget) return;
        final a = HandDrawCardCodec.toPixel(pts[i], size);
        final b = HandDrawCardCodec.toPixel(pts[i + 1], size);
        canvas.drawLine(a, b, strokePaint..style = PaintingStyle.stroke);
        used += 1;
      }
    }
  }

  int _totalSegments(HandDrawCardData d) {
    var n = 0;
    for (final s in d.strokes) {
      if (s.points.length >= 2) {
        n += s.points.length - 1;
      } else if (s.points.length == 1) {
        n += 1;
      }
    }
    return n;
  }

  @override
  bool shouldRepaint(covariant HandDrawCardPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.progress != progress;
  }
}

/// 时间轴回放手绘过程（进入视口时可自动播放一次）
class HandDrawCardReplay extends StatefulWidget {
  const HandDrawCardReplay({
    super.key,
    required this.data,
    this.aspectRatio = 3 / 4,
    this.borderRadius = 20,
    this.autoPlay = true,
    this.duration = const Duration(milliseconds: 2200),
  });

  final HandDrawCardData data;
  final double aspectRatio;
  final double borderRadius;
  final bool autoPlay;
  final Duration duration;

  @override
  State<HandDrawCardReplay> createState() => _HandDrawCardReplayState();
}

class _HandDrawCardReplayState extends State<HandDrawCardReplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.forward(from: 0);
      });
    } else {
      // 动态流里默认不自动播：先展示完整画稿，用户点「再看一遍」再播
      _c.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant HandDrawCardReplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _c.duration = widget.duration;
      if (widget.autoPlay) {
        _c.forward(from: 0);
      } else {
        _c.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _replay() {
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const bottomReserve = 52.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        double canvasW;
        double canvasH;

        if (maxH.isFinite) {
          final availH = (maxH - gap - bottomReserve).clamp(1.0, double.infinity);
          final hIfFullW = maxW / widget.aspectRatio;
          if (hIfFullW <= availH) {
            canvasW = maxW;
            canvasH = hIfFullW;
          } else {
            canvasH = availH;
            canvasW = canvasH * widget.aspectRatio;
            if (canvasW > maxW) {
              canvasW = maxW;
              canvasH = canvasW / widget.aspectRatio;
            }
          }
        } else {
          canvasW = maxW;
          canvasH = maxW / widget.aspectRatio;
        }

        final card = Material(
          color: Colors.transparent,
          elevation: 4,
          shadowColor: Theme.of(context).primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return CustomPaint(
                  painter: HandDrawCardPainter(
                    data: widget.data,
                    progress: _anim.value,
                  ),
                );
              },
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: canvasW,
                height: canvasH,
                child: card,
              ),
            ),
            const SizedBox(height: gap),
            TextButton.icon(
              onPressed: _replay,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('再看一遍'),
            ),
          ],
        );
      },
    );
  }
}

/// 静态展示（不回放动画，用于缩略）
class HandDrawCardStatic extends StatelessWidget {
  const HandDrawCardStatic({
    super.key,
    required this.data,
    this.aspectRatio = 3 / 4,
    this.borderRadius = 20,
  });

  final HandDrawCardData data;
  final double aspectRatio;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          painter: HandDrawCardPainter(data: data, progress: 1),
        ),
      ),
    );
  }
}
