import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_feed.dart';
import '../../widgets/life/life_world_map.dart';
import 'life_entity_detail.dart';
import 'life_inventory_page.dart';
import 'life_relationship_page.dart';

/// 数字生命世界观察主页。
class LifeWorldPage extends StatefulWidget {
  const LifeWorldPage({super.key});

  @override
  State<LifeWorldPage> createState() => _LifeWorldPageState();
}

class _LifeWorldPageState extends State<LifeWorldPage>
    with TickerProviderStateMixin {
  late final LifeProvider _lifeProvider;

  // 反馈动画队列
  final List<_FeedbackItem> _feedbacks = [];
  int _feedbackKeyCounter = 0;

  // 世界事件通知横幅
  final List<_WorldEventBanner> _eventBanners = [];
  int _bannerKeyCounter = 0;
  final Set<String> _seenWorldEventTypes = {};

  @override
  void initState() {
    super.initState();
    _lifeProvider = context.read<LifeProvider>();
    _lifeProvider.startListening();
  }

  @override
  void dispose() {
    _lifeProvider.stopListening();
    super.dispose();
  }

  /// 显示世界事件通知横幅
  void _showWorldEventBanner(WorldEventDiff event) {
    final key = _bannerKeyCounter++;
    final emoji = _weatherEmoji(event.type);
    setState(() {
      _eventBanners.add(_WorldEventBanner(
        key: key,
        emoji: emoji,
        message: event.message,
      ));
    });
    // 3 秒自动消失
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _eventBanners.removeWhere((b) => b.key == key);
        });
      }
    });
  }

  String _weatherEmoji(String type) {
    if (type.contains('rain')) return '🌧️';
    if (type.contains('drought')) return '🏜️';
    if (type.contains('storm')) return '⛈️';
    if (type.contains('depletion')) return '⚠️';
    return '🌍';
  }

  /// 单击实体弹出操作菜单。
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

  /// 弹出实体列表 / 事件流 BottomSheet。
  void _showPanelSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MoeTokens.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: context.read<LifeProvider>(),
          child: Consumer<LifeProvider>(
            builder: (ctx, lifeProvider, _) {
              return DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollController) {
                  return _PanelSheetContent(
                    entities: lifeProvider.entities,
                    events: lifeProvider.recentEvents,
                    scrollController: scrollController,
                    onEntityTap: (entity) {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LifeEntityDetailPage(entity: entity),
                        ),
                      );
                    },
                  );
                },
              );
            },
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 420;

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('数字生命'),
        actions: [
          IconButton(
            icon: const Icon(Icons.backpack_outlined, size: 20),
            tooltip: '我的背包',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LifeInventoryPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.hub_outlined, size: 20),
            tooltip: '关系网络',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LifeRelationshipPage(),
              ),
            ),
          ),
          // 连接状态指示器 — 仅监听 connected
          Selector<LifeProvider, bool>(
            selector: (_, p) => p.connected,
            builder: (context, connected, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected
                          ? MoeTokens.success
                          : MoeTokens.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 小屏隐藏文字，仅保留圆点
                  if (!isCompact) ...[
                    const SizedBox(width: 4),
                    Text(
                      connected ? '已连接' : '未连接',
                      style: TextStyle(
                        fontSize: 12,
                        color: connected
                            ? MoeTokens.success
                            : MoeTokens.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
      ),
      // 浮动按钮：弹出实体列表/事件面板
      floatingActionButton: FloatingActionButton(
        onPressed: _showPanelSheet,
        backgroundColor: MoeTokens.primary,
        child: const Icon(Icons.list, color: Colors.white),
      ),
      body: Column(
        children: [
          // 加载指示器 — 仅监听 isInitialized + connected
          Selector<LifeProvider, ({bool isInitialized, bool connected})>(
            selector: (_, p) => (
              isInitialized: p.isInitialized,
              connected: p.connected
            ),
            builder: (context, state, _) {
              if (!state.isInitialized && state.connected) {
                return const Padding(
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // 可折叠摘要卡 — 监听 summary + weather
          Selector<LifeProvider, _SummaryCardData>(
            selector: (_, p) => _SummaryCardData(
              summary: p.summary,
              tickCount: p.tickCount,
              isConnected: p.connected,
              entityCount: p.entities.length,
              weather: p.summary.weather,
            ),
            builder: (context, data, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _CollapsibleSummaryCard(
                  summary: data.summary,
                  tickCount: data.tickCount,
                  isConnected: data.isConnected,
                  entityCount: data.entityCount,
                  weather: data.weather,
                ),
              );
            },
          ),
          // 世界事件通知横幅监听
          Selector<LifeProvider, List<WorldEventDiff>>(
            selector: (_, p) => p.worldEvents,
            builder: (context, worldEvents, _) {
              // 检测新的世界事件
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final we in worldEvents) {
                  if (!_seenWorldEventTypes.contains(we.type) && we.message.isNotEmpty) {
                    _seenWorldEventTypes.add(we.type);
                    _showWorldEventBanner(we);
                  }
                }
              });
              return const SizedBox.shrink();
            },
          ),
          // 地图占据全部剩余空间 — 监听 entities + weather
          Expanded(
            child: Selector<LifeProvider, ({List<LifeEntity> entities, String weather})>(
              selector: (_, p) => (entities: p.entities, weather: p.summary.weather),
              builder: (context, data, _) {
                final entities = data.entities;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Stack(
                    children: [
                      // 地图
                      Positioned.fill(
                        child: LifeWorldMap(
                          entities: entities,
                          weather: data.weather,
                          onEntityTap: (entityId) {
                            final entity = entities
                                .where((e) => e.id == entityId)
                                .firstOrNull;
                            if (entity != null) {
                              _showEntityActionSheet(entity);
                            }
                          },
                          onEntityLongPress: (entityId) {
                            // 长按作为快速喂食快捷方式
                            final entity = entities
                                .where((e) => e.id == entityId)
                                .firstOrNull;
                            if (entity != null) {
                              final provider =
                                  context.read<LifeProvider>();
                              _performActionWithFeedback(
                                  provider, 'feed', entity);
                            }
                          },
                        ),
                      ),
                      // 提示标签
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '点击实体可互动',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 世界事件横幅
                      ..._buildEventBanners(),
                      // 反馈动画层
                      ..._buildFeedbackOverlays(),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 构建世界事件横幅列表
  List<Widget> _buildEventBanners() {
    if (_eventBanners.isEmpty) return const [];

    return [
      Positioned(
        top: 36,
        left: 20,
        right: 20,
        child: Column(
          children: [
            for (final banner in _eventBanners)
              _WorldEventBannerWidget(
                key: ValueKey(banner.key),
                banner: banner,
                onDismiss: () {
                  setState(() {
                    _eventBanners.removeWhere((b) => b.key == banner.key);
                  });
                },
              ),
          ],
        ),
      ),
    ];
  }

  /// 构建反馈动画 overlay 列表。
  List<Widget> _buildFeedbackOverlays() {
    if (_feedbacks.isEmpty) return const [];

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                      pixelY: (fb.entityY * yFactor).clamp(0.0, mapHeight),
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

/// Selector 用复合数据 — 仅在字段值真正变化时触发重建。
class _SummaryCardData {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool isConnected;
  final int entityCount;
  final String weather;

  const _SummaryCardData({
    required this.summary,
    required this.tickCount,
    required this.isConnected,
    required this.entityCount,
    required this.weather,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SummaryCardData &&
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

/// 世界事件横幅数据
class _WorldEventBanner {
  final int key;
  final String emoji;
  final String message;

  _WorldEventBanner({
    required this.key,
    required this.emoji,
    required this.message,
  });
}

/// 世界事件横幅组件
class _WorldEventBannerWidget extends StatefulWidget {
  final _WorldEventBanner banner;
  final VoidCallback onDismiss;

  const _WorldEventBannerWidget({
    super.key,
    required this.banner,
    required this.onDismiss,
  });

  @override
  State<_WorldEventBannerWidget> createState() => _WorldEventBannerWidgetState();
}

class _WorldEventBannerWidgetState extends State<_WorldEventBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
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
    return Dismissible(
      key: ValueKey('banner_${widget.banner.key}'),
      onDismissed: (_) => widget.onDismiss(),
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.banner.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.banner.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
class _CollapsibleSummaryCard extends StatefulWidget {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool isConnected;
  final int entityCount;
  final String weather;

  const _CollapsibleSummaryCard({
    required this.summary,
    required this.tickCount,
    required this.isConnected,
    required this.entityCount,
    required this.weather,
  });

  @override
  State<_CollapsibleSummaryCard> createState() =>
      _CollapsibleSummaryCardState();
}

class _CollapsibleSummaryCardState extends State<_CollapsibleSummaryCard>
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
                        child: _WorldKpiCard(
                          label: '存活',
                          value: '${widget.summary.aliveCount}',
                          toneColor: MoeTokens.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WorldKpiCard(
                          label: '新生',
                          value: '${widget.summary.birthCount}',
                          toneColor: MoeTokens.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WorldKpiCard(
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
                        _SummaryChip(
                            '天气',
                            '${_weatherEmojiFor(widget.weather)} ${widget.weather}'),
                        const SizedBox(width: 8),
                        _SummaryChip(
                            '食物储量',
                            widget.summary.totalFood.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        _SummaryChip(
                            '宜居格', '${widget.summary.habitableCells}'),
                        const SizedBox(width: 8),
                        _SummaryChip(
                            '危险格', '${widget.summary.dangerCells}'),
                        const SizedBox(width: 8),
                        _SummaryChip(
                            '平均饱食',
                            widget.summary.avgHunger.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        _SummaryChip(
                            '平均精力',
                            widget.summary.avgEnergy.toStringAsFixed(0)),
                        const SizedBox(width: 8),
                        _SummaryChip(
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

/// BottomSheet 面板内容 — 实体列表 + 事件流两个 Tab。
class _PanelSheetContent extends StatefulWidget {
  final List<LifeEntity> entities;
  final List<LifeEvent> events;
  final ScrollController scrollController;
  final void Function(LifeEntity entity) onEntityTap;

  const _PanelSheetContent({
    required this.entities,
    required this.events,
    required this.scrollController,
    required this.onEntityTap,
  });

  @override
  State<_PanelSheetContent> createState() => _PanelSheetContentState();
}

class _PanelSheetContentState extends State<_PanelSheetContent>
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
              _EntityGrid(
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
          ],
        ),
      ),
    );
  }
}
