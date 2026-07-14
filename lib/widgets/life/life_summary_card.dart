import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';

/// Selector 用复合数据 — 仅在字段值真正变化时触发重建。
class SummaryCardData {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool isConnected;
  final int entityCount;
  final String weather;

  const SummaryCardData({
    required this.summary,
    required this.tickCount,
    required this.isConnected,
    required this.entityCount,
    required this.weather,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryCardData &&
          summary.aliveCount == other.summary.aliveCount &&
          summary.birthCount == other.summary.birthCount &&
          summary.deathCount == other.summary.deathCount &&
          summary.avgHunger == other.summary.avgHunger &&
          summary.avgEnergy == other.summary.avgEnergy &&
          summary.avgMood == other.summary.avgMood &&
          summary.totalFood == other.summary.totalFood &&
          summary.habitableCells == other.summary.habitableCells &&
          summary.dangerCells == other.summary.dangerCells &&
          summary.entityCount == other.summary.entityCount &&
          tickCount == other.tickCount &&
          isConnected == other.isConnected &&
          entityCount == other.entityCount &&
          weather == other.weather;

  @override
  int get hashCode => Object.hash(
        summary.aliveCount,
        summary.birthCount,
        summary.deathCount,
        summary.avgHunger,
        summary.avgEnergy,
        summary.avgMood,
        summary.totalFood,
        summary.habitableCells,
        summary.dangerCells,
        summary.entityCount,
        tickCount,
        isConnected,
        entityCount,
        weather,
      );
}

/// 天气 emoji 映射
String _weatherEmojiFor(String weather) {
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

/// 可折叠摘要卡 — 默认收起仅显示一行核心信息，展开显示完整 KPI。
class LifeSummaryCard extends StatefulWidget {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool isConnected;
  final int entityCount;
  final String weather;

  const LifeSummaryCard({
    super.key,
    required this.summary,
    required this.tickCount,
    required this.isConnected,
    required this.entityCount,
    required this.weather,
  });

  @override
  State<LifeSummaryCard> createState() => _LifeSummaryCardState();
}

class _LifeSummaryCardState extends State<LifeSummaryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收起状态：一行核心信息
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.pets,
                    size: 18,
                    color: MoeTokens.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.entityCount} 实体',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MoeTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tick ${widget.tickCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MoeTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 天气图标（折叠态也显示）
                  Text(
                    _weatherEmojiFor(widget.weather),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  // 连接状态圆点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.isConnected
                          ? MoeTokens.success
                          : MoeTokens.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: WorldKpiCard(
                          label: '存活',
                          value: '${widget.summary.aliveCount}',
                          toneColor: MoeTokens.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: WorldKpiCard(
                          label: '新生',
                          value: '${widget.summary.birthCount}',
                          toneColor: MoeTokens.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: WorldKpiCard(
                          label: '消亡',
                          value: '${widget.summary.deathCount}',
                          toneColor: MoeTokens.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SummaryChip(
                            '天气',
                            '${_weatherEmojiFor(widget.weather)} ${widget.weather}'),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '食物储量',
                            widget.summary.totalFood.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '宜居格', '${widget.summary.habitableCells}'),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '危险格', '${widget.summary.dangerCells}'),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '平均饱食',
                            widget.summary.avgHunger.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '平均精力',
                            widget.summary.avgEnergy.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        SummaryChip(
                            '平均情绪',
                            widget.summary.avgMood.toStringAsFixed(0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 世界 KPI 卡片。
class WorldKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color toneColor;

  const WorldKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.toneColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: toneColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: toneColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w700,
              color: MoeTokens.titleText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 摘要信息小标签。
class SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const SummaryChip(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MoeTokens.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: MoeTokens.hintText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MoeTokens.titleText,
            ),
          ),
        ],
      ),
    );
  }
}
