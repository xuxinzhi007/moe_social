import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';

/// Entity 详情页 — 展示单个实体的属性和最近事件。
class LifeEntityDetailPage extends StatelessWidget {
  final LifeEntity entity;

  const LifeEntityDetailPage({super.key, required this.entity});

  @override
  Widget build(BuildContext context) {
    final lifeProvider = context.watch<LifeProvider>();
    // 从 provider 获取最新状态
    final currentEntity = lifeProvider.entities
            .where((e) => e.id == entity.id)
            .firstOrNull ??
        entity;
    final entityEvents = lifeProvider.recentEvents
        .where((e) => e.entityId == entity.id)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Text('${currentEntity.emoji} ${currentEntity.name}'),
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 大号 emoji 头像
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: MoeTokens.cardBackground,
                shape: BoxShape.circle,
                boxShadow: MoeTokens.shadowMd(),
              ),
              alignment: Alignment.center,
              child: Text(
                currentEntity.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            // 名称
            Text(
              currentEntity.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: 8),
            // 行为状态标签
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MoeTokens.primary.withValues(alpha: 0.15),
                    MoeTokens.secondary.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentEntity.actionLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MoeTokens.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 三个属性进度条
            _StatBar(
              label: '饥饿度',
              value: currentEntity.hunger,
              color: Colors.orange,
              icon: Icons.restaurant,
            ),
            const SizedBox(height: 12),
            _StatBar(
              label: '精力值',
              value: currentEntity.energy,
              color: Colors.blue,
              icon: Icons.bolt,
            ),
            const SizedBox(height: 12),
            _StatBar(
              label: '心情值',
              value: currentEntity.mood,
              color: Colors.pink,
              icon: Icons.favorite,
            ),
            const SizedBox(height: 24),
            // 位置坐标
            Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: MoeTokens.cardBackground,
                borderRadius: BorderRadius.circular(12),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 20, color: MoeTokens.primary),
                  const SizedBox(width: 8),
                  Text(
                    '坐标: (${currentEntity.x.toInt()}, ${currentEntity.y.toInt()})',
                    style: const TextStyle(
                      fontSize: 14,
                      color: MoeTokens.bodyText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 该 entity 的最近事件
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '最近事件',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MoeTokens.titleText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (entityEvents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MoeTokens.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '暂无事件记录',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ),
              )
            else
              ...entityEvents.map((event) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MoeTokens.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle,
                            size: 6,
                            color: MoeTokens.primary.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.desc,
                                style: const TextStyle(
                                    fontSize: 13, color: MoeTokens.bodyText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimestamp(event.timestamp),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MoeTokens.bodyText,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${value.toInt()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
