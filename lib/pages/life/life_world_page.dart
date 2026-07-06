import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_feed.dart';
import '../../widgets/life/life_world_map.dart';
import 'life_entity_detail.dart';

/// 数字生命世界观察主页面。
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
    // 启动 WebSocket 监听
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

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('数字生命'),
            const SizedBox(width: 12),
            // Tick 计数
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
          // 连接状态指示
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
          // 世界地图
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
          // 底部面板
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
                    // TabBar
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
                              Text(
                                  '实体 (${lifeProvider.entities.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_note, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                  '事件 (${lifeProvider.recentEvents.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // TabBarView
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 实体 Grid
                          _EntityGrid(
                            entities: lifeProvider.entities,
                            onTap: (entity) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LifeEntityDetailPage(entity: entity),
                                ),
                              );
                            },
                          ),
                          // 事件流
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

class _EntityGrid extends StatelessWidget {
  final List<LifeEntity> entities;
  final void Function(LifeEntity entity) onTap;

  const _EntityGrid({required this.entities, required this.onTap});

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

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MoeTokens.pageBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MoeTokens.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
