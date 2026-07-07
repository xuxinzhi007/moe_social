import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_feed.dart';
import '../../widgets/life/life_world_map.dart';
import 'life_entity_detail.dart';
import 'life_relationship_page.dart';

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

  // 反馈动画队列
  final List<_FeedbackItem> _feedbacks = [];
  int _feedbackKeyCounter = 0;

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

  /// 长按实体弹出操作菜单。
  void _showEntityActionSheet(LifeEntity entity) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MoeTokens.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final provider = ctx.read<LifeProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 实体信息
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(entity.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entity.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: MoeTokens.titleText,
                            ),
                          ),
                          Text(
                            entity.actionLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MoeTokens.hintText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, indent: 20, endIndent: 20),
                // 操作选项
                ListTile(
                  leading: const Icon(Icons.restaurant_menu,
                      color: Colors.orange),
                  title: const Text('喂食'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _performActionWithFeedback(provider, 'feed', entity);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.front_hand, color: Colors.pink),
                  title: const Text('抚摸'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _performActionWithFeedback(provider, 'pet', entity);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: MoeTokens.primary),
                  title: const Text('查看详情'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LifeEntityDetailPage(entity: entity),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 执行操作并显示反馈动画。
  Future<void> _performActionWithFeedback(
    LifeProvider provider,
    String action,
    LifeEntity entity,
  ) async {
    final success = await provider.performAction(action, entity.id);
    if (!mounted) return;
    if (success) {
      _showFeedback(action, entity);
    } else if (provider.lastActionError != null) {
      final isCooldown = provider.lastActionIsCooldown;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (isCooldown) ...[Icon(Icons.timer_outlined, size: 18, color: Colors.white), const SizedBox(width: 6)],
              Expanded(child: Text(provider.lastActionError!)),
            ],
          ),
          backgroundColor: isCooldown ? MoeTokens.warning : MoeTokens.danger,
          duration: const Duration(seconds: 2),
        ),
      );
      provider.clearActionError();
    }
  }

  /// 在地图上显示反馈 emoji 动画。
  void _showFeedback(String action, LifeEntity entity) {
    final emoji = action == 'feed' ? '❤️' : '✨';
    final key = _feedbackKeyCounter++;
    setState(() {
      _feedbacks.add(_FeedbackItem(
        key: key,
        emoji: emoji,
        entityX: entity.x,
        entityY: entity.y,
      ));
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _feedbacks.removeWhere((f) => f.key == key);
        });
      }
    });
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
          IconButton(
            icon: const Icon(Icons.hub_outlined, size: 20),
            tooltip: '关系网络',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LifeRelationshipPage(),
              ),
            ),
          ),
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
          if (!lifeProvider.isInitialized && lifeProvider.connected)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    '正在连接世界...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
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
              child: Stack(
                children: [
                  // 地图（占据全部空间）
                  Positioned.fill(
                    child: LifeWorldMap(
                      entities: lifeProvider.entities,
                      onEntityTap: (entityId) {
                        final entity = lifeProvider.entities
                            .where((e) => e.id == entityId)
                            .firstOrNull;
                        if (entity != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LifeEntityDetailPage(entity: entity),
                            ),
                          );
                        }
                      },
                      onEntityLongPress: (entityId) {
                        final entity = lifeProvider.entities
                            .where((e) => e.id == entityId)
                            .firstOrNull;
                        if (entity != null) {
                          _showEntityActionSheet(entity);
                        }
                      },
                    ),
                  ),
                  // 反馈动画层
                  ..._buildFeedbackOverlays(),
                ],
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

  /// 构建反馈动画 overlay 列表。
  List<Widget> _buildFeedbackOverlays() {
    if (_feedbacks.isEmpty) return const [];

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 地图区域水平 margin = 12（与 LifeWorldMap 的 margin 一致）
              const double mapMarginH = 12;
              final mapWidth = constraints.maxWidth - mapMarginH * 2;
              final mapHeight = constraints.maxHeight;
              const double worldW = 1280;
              const double worldH = 720;
              final xFactor = mapWidth / worldW;
              final yFactor = mapHeight / worldH;

              return Stack(
                children: [
                  for (final fb in _feedbacks)
                    _ActionFeedbackOverlay(
                      key: ValueKey(fb.key),
                      emoji: fb.emoji,
                      pixelX: (fb.entityX * xFactor) + mapMarginH,
                      pixelY: fb.entityY * yFactor,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }
}

/// 反馈动画数据项。
class _FeedbackItem {
  final int key;
  final String emoji;
  final double entityX;
  final double entityY;

  _FeedbackItem({
    required this.key,
    required this.emoji,
    required this.entityX,
    required this.entityY,
  });
}

/// 操作反馈 emoji 上浮动画组件。
class _ActionFeedbackOverlay extends StatefulWidget {
  final String emoji;
  final double pixelX;
  final double pixelY;

  const _ActionFeedbackOverlay({
    super.key,
    required this.emoji,
    required this.pixelX,
    required this.pixelY,
  });

  @override
  State<_ActionFeedbackOverlay> createState() => _ActionFeedbackOverlayState();
}

class _ActionFeedbackOverlayState extends State<_ActionFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offsetAnim = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.pixelX - 12,
          top: widget.pixelY - 30 + _offsetAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    color:
                        isConnected ? MoeTokens.success : MoeTokens.danger,
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
    );
  }
}
