import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_feed.dart';
import '../../widgets/life/life_world_map.dart';
import 'life_entity_detail.dart';

/// 数字生命世界观察主页。
class LifeWorldPage extends StatefulWidget {
  const LifeWorldPage({super.key});

  @override
  State<LifeWorldPage> createState() => _LifeWorldPageState();
}

class _LifeWorldPageState extends State<LifeWorldPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final LifeProvider _lifeProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lifeProvider = context.read<LifeProvider>();
    _lifeProvider.startListening();
  }

  @override
  void dispose() {
    _lifeProvider.stopListening();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifeProvider = context.watch<LifeProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 420;

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('数字生命'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MoeTokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tick ${lifeProvider.tickCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: MoeTokens.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: lifeProvider.connected
                        ? MoeTokens.success
                        : MoeTokens.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  lifeProvider.connected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: lifeProvider.connected
                        ? MoeTokens.success
                        : MoeTokens.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _WorldSummaryCard(
              summary: lifeProvider.summary,
              tickCount: lifeProvider.tickCount,
              isConnected: lifeProvider.connected,
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LifeWorldMap(
                entities: lifeProvider.entities,
                onEntityTap: (entityId) {
                  final entity = lifeProvider.entities
                      .where((e) => e.id == entityId)
                      .firstOrNull;
                  if (entity != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LifeEntityDetailPage(entity: entity),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: MoeTokens.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: MoeTokens.primary,
                      unselectedLabelColor: MoeTokens.hintText,
                      indicatorColor: MoeTokens.primary,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pets, size: 16),
                              const SizedBox(width: 4),
                              Text('实体 (${lifeProvider.entities.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_note, size: 16),
                              const SizedBox(width: 4),
                              Text('事件 (${lifeProvider.recentEvents.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _EntityGrid(
                            entities: lifeProvider.entities,
                            isCompact: isCompact,
                            onTap: (entity) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LifeEntityDetailPage(entity: entity),
                                ),
                              );
                            },
                          ),
                          LifeEventFeed(events: lifeProvider.recentEvents),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WorldSummaryCard extends StatelessWidget {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool isConnected;

  const _WorldSummaryCard({
    required this.summary,
    required this.tickCount,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '世界态势',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '当前存活 ${summary.aliveCount} 个生命，正在持续演化中',
                      style: TextStyle(
                        fontSize: 12,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected
                      ? MoeTokens.success.withValues(alpha: 0.1)
                      : MoeTokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isConnected ? '实时同步中 · Tick $tickCount' : '连接中断',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isConnected ? MoeTokens.success : MoeTokens.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WorldKpiCard(
                  label: '存活',
                  value: '${summary.aliveCount}',
                  toneColor: MoeTokens.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorldKpiCard(
                  label: '新生',
                  value: '${summary.birthCount}',
                  toneColor: MoeTokens.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorldKpiCard(
                  label: '消亡',
                  value: '${summary.deathCount}',
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
                _SummaryChip('食物储量', summary.totalFood.toStringAsFixed(0)),
                const SizedBox(width: 8),
                _SummaryChip('宜居格', '${summary.habitableCells}'),
                const SizedBox(width: 8),
                _SummaryChip('危险格', '${summary.dangerCells}'),
                const SizedBox(width: 8),
                _SummaryChip('平均饱食', summary.avgHunger.toStringAsFixed(0)),
                const SizedBox(width: 8),
                _SummaryChip('平均精力', summary.avgEnergy.toStringAsFixed(0)),
                const SizedBox(width: 8),
                _SummaryChip('平均情绪', summary.avgMood.toStringAsFixed(0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color toneColor;

  const _WorldKpiCard({
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

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip(this.label, this.value);

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

class _EntityGrid extends StatelessWidget {
  final List<LifeEntity> entities;
  final bool isCompact;
  final void Function(LifeEntity entity) onTap;

  const _EntityGrid({
    required this.entities,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('暂无实体', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    if (isCompact) {
      return ListView.separated(
        padding: const EdgeInsets.all(10),
        scrollDirection: Axis.horizontal,
        itemCount: entities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entity = entities[index];
          return SizedBox(
            width: 132,
            child: _EntityCard(entity: entity, onTap: () => onTap(entity)),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: entities.length,
      itemBuilder: (context, index) {
        final entity = entities[index];
        return _EntityCard(entity: entity, onTap: () => onTap(entity));
      },
    );
  }
}

class _EntityCard extends StatelessWidget {
  final LifeEntity entity;
  final VoidCallback onTap;

  const _EntityCard({required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: MoeTokens.pageBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MoeTokens.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entity.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              entity.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: MoeTokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entity.actionLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: MoeTokens.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
