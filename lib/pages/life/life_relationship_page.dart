import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';

/// 蛛网式社交关系可视化页面。
class LifeRelationshipPage extends StatefulWidget {
  const LifeRelationshipPage({super.key});

  @override
  State<LifeRelationshipPage> createState() => _LifeRelationshipPageState();
}

class _LifeRelationshipPageState extends State<LifeRelationshipPage> {
  int? _selectedEntityId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('关系网络'),
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
        actions: [
          Consumer<LifeProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: '关系统计',
                onPressed: () => _showStatsDialog(context, provider),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 蛛网画布（主体）
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Consumer<LifeProvider>(
                builder: (context, provider, _) {
                  return CustomPaint(
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height - 160,
                    ),
                    painter: SpiderWebPainter(
                      entities: provider.entities,
                      relationships: provider.relationships,
                      selectedEntityId: _selectedEntityId,
                      onEntityTap: (id) => setState(() {
                        _selectedEntityId = _selectedEntityId == id ? null : id;
                      }),
                    ),
                  );
                },
              ),
            ),
          ),
          // 底部统计栏
          _buildStatsBar(),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Consumer<LifeProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MoeTokens.cardBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _StatChip(
                  label: '总关系',
                  value: '${provider.relationships.length}',
                  color: MoeTokens.primary,
                  icon: Icons.hub_outlined,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: '朋友',
                  value: '${provider.friendCount}',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.favorite_border,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: '伴侣',
                  value: '${provider.mateCount}',
                  color: const Color(0xFFFFC107),
                  icon: Icons.favorite,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: '对手',
                  value: '${provider.rivalCount}',
                  color: const Color(0xFFF44336),
                  icon: Icons.bolt,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStatsDialog(BuildContext context, LifeProvider provider) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关系统计'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总关系数: ${provider.relationships.length}'),
            Text('朋友: ${provider.friendCount}'),
            Text('伴侣: ${provider.mateCount}'),
            Text('对手: ${provider.rivalCount}'),
            const SizedBox(height: 8),
            Text('实体总数: ${provider.entities.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 底部统计小标签。
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 蛛网绘制器 — 力导向布局 + 蛛网背景 + 关系连线 + 实体节点。
class SpiderWebPainter extends CustomPainter {
  final List<LifeEntity> entities;
  final List<LifeRelationship> relationships;
  final int? selectedEntityId;
  final ValueChanged<int>? onEntityTap;

  SpiderWebPainter({
    required this.entities,
    required this.relationships,
    this.selectedEntityId,
    this.onEntityTap,
  });

  final Map<int, Offset> _positions = {};

  @override
  void paint(Canvas canvas, Size size) {
    _calculateLayout(size);
    _drawWebBackground(canvas, size);

    for (final rel in relationships) {
      _drawRelationshipLine(canvas, rel);
    }

    for (final entity in entities) {
      _drawEntityNode(canvas, entity);
    }
  }

  void _calculateLayout(Size size) {
    _positions.clear();
    if (entities.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final connectedIds = <int>{};
    for (final r in relationships) {
      connectedIds.add(r.entityId);
      connectedIds.add(r.targetId);
    }

    final connected = entities.where((e) => connectedIds.contains(e.id)).toList();
    final isolated = entities.where((e) => !connectedIds.contains(e.id)).toList();

    // 有关系的实体：圆周分布 + 弹簧力迭代
    final innerRadius = size.shortestSide * 0.3;
    for (int i = 0; i < connected.length; i++) {
      final angle = (2 * pi * i / connected.length) - pi / 2;
      _positions[connected[i].id] = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
    }

    // 弹簧力迭代（5 次）
    for (int iter = 0; iter < 5; iter++) {
      for (final rel in relationships) {
        final posA = _positions[rel.entityId];
        final posB = _positions[rel.targetId];
        if (posA == null || posB == null) continue;

        final targetDist = 80 + (100 - rel.affinity) * 1.5;
        final dx = posB.dx - posA.dx;
        final dy = posB.dy - posA.dy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist == 0) continue;

        final force = (dist - targetDist) * 0.1;
        final fx = force * dx / dist;
        final fy = force * dy / dist;
        _positions[rel.entityId] = posA.translate(fx, fy);
        _positions[rel.targetId] = posB.translate(-fx, -fy);
      }
    }

    // 孤立实体：外圈分布
    final outerRadius = size.shortestSide * 0.42;
    for (int i = 0; i < isolated.length; i++) {
      final angle = (2 * pi * i / isolated.length) - pi / 2;
      _positions[isolated[i].id] = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
    }
  }

  /// 蛛网背景：淡色同心圆 + 放射线。
  void _drawWebBackground(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 同心圆
    for (double r = 50; r < size.shortestSide / 2; r += 60) {
      canvas.drawCircle(center, r, paint);
    }
    // 放射线（8 条）
    for (int i = 0; i < 8; i++) {
      final angle = (2 * pi * i / 8);
      final end = Offset(
        center.dx + size.shortestSide / 2 * cos(angle),
        center.dy + size.shortestSide / 2 * sin(angle),
      );
      canvas.drawLine(center, end, paint);
    }
  }

  /// 关系连线。
  void _drawRelationshipLine(Canvas canvas, LifeRelationship rel) {
    final posA = _positions[rel.entityId];
    final posB = _positions[rel.targetId];
    if (posA == null || posB == null) return;

    final isSelected = selectedEntityId == rel.entityId || selectedEntityId == rel.targetId;
    final opacity = selectedEntityId == null ? 0.7 : (isSelected ? 1.0 : 0.15);

    final paint = Paint()
      ..color = rel.relationColor.withValues(alpha: opacity)
      ..strokeWidth = 1 + (rel.affinity / 100) * 3
      ..style = PaintingStyle.stroke;

    if (rel.relationType == 'rival') {
      _drawDashedLine(canvas, posA, posB, paint);
    } else {
      canvas.drawLine(posA, posB, paint);
      if (rel.relationType == 'mate') {
        _drawHeartAtMidpoint(canvas, posA, posB, opacity);
      }
    }

    // 选中时显示亲密度标签
    if (isSelected) {
      _drawAffinityLabel(canvas, posA, posB, rel);
    }
  }

  /// 虚线绘制。
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;

    final unitX = dx / dist;
    final unitY = dy / dist;
    double drawn = 0;
    bool drawing = true;

    while (drawn < dist) {
      final segLen = drawing ? dashLength : gapLength;
      final remain = dist - drawn;
      final actual = remain < segLen ? remain : segLen;
      if (drawing) {
        final a = Offset(start.dx + unitX * drawn, start.dy + unitY * drawn);
        final b = Offset(a.dx + unitX * actual, a.dy + unitY * actual);
        canvas.drawLine(a, b, paint);
      }
      drawn += actual;
      drawing = !drawing;
    }
  }

  /// 伴侣关系中点画爱心。
  void _drawHeartAtMidpoint(Canvas canvas, Offset a, Offset b, double opacity) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final heartPaint = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    const s = 6.0;
    path.moveTo(mid.dx, mid.dy + s * 0.4);
    path.cubicTo(
      mid.dx - s, mid.dy - s * 0.6,
      mid.dx - s * 0.5, mid.dy - s,
      mid.dx, mid.dy - s * 0.4,
    );
    path.cubicTo(
      mid.dx + s * 0.5, mid.dy - s,
      mid.dx + s, mid.dy - s * 0.6,
      mid.dx, mid.dy + s * 0.4,
    );
    canvas.drawPath(path, heartPaint);
  }

  /// 亲密度标签。
  void _drawAffinityLabel(Canvas canvas, Offset a, Offset b, LifeRelationship rel) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final label = '${rel.relationLabel} ${rel.affinity.toInt()}';

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          color: rel.relationColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: mid,
      width: textPainter.width + 10,
      height: textPainter.height + 6,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), bgPaint);
    textPainter.paint(canvas, mid - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  /// 实体节点。
  void _drawEntityNode(Canvas canvas, LifeEntity entity) {
    final pos = _positions[entity.id];
    if (pos == null) return;

    final isSelected = selectedEntityId == entity.id;
    final nodeRadius = isSelected ? 24.0 : 18.0;

    // 成长阶段色环
    final ringPaint = Paint()
      ..color = entity.growthStageColor.withValues(alpha: isSelected ? 1.0 : 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(pos, nodeRadius + 2, ringPaint);

    // 节点背景
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(pos, nodeRadius, bgPaint);

    // 选中时外发光
    if (isSelected) {
      final glowPaint = Paint()
        ..color = MoeTokens.primary.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(pos, nodeRadius + 5, glowPaint);
    }

    // Emoji
    final textPainter = TextPainter(
      text: TextSpan(text: entity.emoji, style: TextStyle(fontSize: nodeRadius)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));

    // 名称标签（节点下方）
    final namePainter = TextPainter(
      text: TextSpan(
        text: entity.name,
        style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    namePainter.paint(
      canvas,
      Offset(pos.dx - namePainter.width / 2, pos.dy + nodeRadius + 4),
    );
  }

  @override
  bool shouldRepaint(covariant SpiderWebPainter oldDelegate) {
    return entities != oldDelegate.entities ||
        relationships != oldDelegate.relationships ||
        selectedEntityId != oldDelegate.selectedEntityId;
  }

  @override
  bool? hitTest(Offset position) => true;
}
