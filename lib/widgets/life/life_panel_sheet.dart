import 'package:flutter/material.dart';

import '../../models/life_state.dart';
import '../../theme/moe_tokens.dart';
import 'life_event_feed.dart';

/// BottomSheet 面板内容 — 实体列表 + 事件流两个 Tab。
class LifePanelSheet extends StatefulWidget {
  final List<LifeEntity> entities;
  final List<LifeEvent> events;
  final ScrollController scrollController;
  final void Function(LifeEntity entity) onEntityTap;

  const LifePanelSheet({
    super.key,
    required this.entities,
    required this.events,
    required this.scrollController,
    required this.onEntityTap,
  });

  @override
  State<LifePanelSheet> createState() => _LifePanelSheetState();
}

class _LifePanelSheetState extends State<LifePanelSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 420;
    return Column(
      children: [
        // 拖动指示条
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
                  Text('实体 (${widget.entities.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_note, size: 16),
                  const SizedBox(width: 4),
                  Text('事件 (${widget.events.length})'),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              LifeEntityGrid(
                entities: widget.entities,
                isCompact: isCompact,
                onTap: widget.onEntityTap,
              ),
              LifeEventFeed(events: widget.events),
            ],
          ),
        ),
      ],
    );
  }
}

/// 实体网格列表。
class LifeEntityGrid extends StatelessWidget {
  final List<LifeEntity> entities;
  final bool isCompact;
  final void Function(LifeEntity entity) onTap;

  const LifeEntityGrid({
    super.key,
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
            child: LifeEntityCard(entity: entity, onTap: () => onTap(entity)),
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
        return LifeEntityCard(entity: entity, onTap: () => onTap(entity));
      },
    );
  }
}

/// 单个实体卡片。
class LifeEntityCard extends StatelessWidget {
  final LifeEntity entity;
  final VoidCallback onTap;

  const LifeEntityCard({super.key, required this.entity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
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
              const SizedBox(height: 2),
              // 成长阶段小标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: entity.growthStageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: entity.growthStageColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  entity.growthStageLabel,
                  style: TextStyle(
                    fontSize: 9,
                    color: entity.growthStageColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
