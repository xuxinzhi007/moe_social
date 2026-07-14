import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_banner.dart';
import '../../widgets/life/life_feedback_overlay.dart';
import '../../widgets/life/life_panel_sheet.dart';
import '../../widgets/life/life_summary_card.dart';
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
  final List<FeedbackItem> _feedbacks = [];
  int _feedbackKeyCounter = 0;

  // 世界事件通知横幅
  final List<WorldEventBannerData> _eventBanners = [];
  int _bannerKeyCounter = 0;
  final Set<String> _seenWorldEventTypes = {};

  // 引导气泡（首次进入时展示）
  bool _showGuideBubble = false;

  @override
  void initState() {
    super.initState();
    _lifeProvider = context.read<LifeProvider>();
    _lifeProvider.startListening();
    // 异步检查是否首次进入，展示引导气泡
    SharedPreferences.getInstance().then((prefs) {
      if (!(prefs.getBool('life_guide_seen') ?? false)) {
        if (!mounted) return;
        setState(() => _showGuideBubble = true);
        // 8秒后自动消失
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) setState(() => _showGuideBubble = false);
        });
      }
    });
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
      _eventBanners.add(WorldEventBannerData(
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
        final isOffline = provider.isOfflineMode;
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
                // 操作选项——离线时禁用
                Tooltip(
                  message: isOffline ? '连接恢复后可操作' : '',
                  child: ListTile(
                    leading: const Icon(Icons.restaurant_menu,
                        color: Colors.orange),
                    title: const Text('喂食'),
                    enabled: !isOffline,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _performActionWithFeedback(provider, 'feed', entity);
                    },
                  ),
                ),
                Tooltip(
                  message: isOffline ? '连接恢复后可操作' : '',
                  child: ListTile(
                    leading:
                        const Icon(Icons.front_hand, color: Colors.pink),
                    title: const Text('抚摸'),
                    enabled: !isOffline,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _performActionWithFeedback(provider, 'pet', entity);
                    },
                  ),
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
                  return LifePanelSheet(
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
      _feedbacks.add(FeedbackItem(
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
          // 连接状态三态指示器 — 已连接/重连中/离线
          Selector<LifeProvider, ({bool connected, bool isOfflineMode})>(
            selector: (_, p) => (
              connected: p.connected,
              isOfflineMode: p.isOfflineMode,
            ),
            builder: (context, state, _) {
              final connected = state.connected;
              final isOffline = state.isOfflineMode;

              // 三态颜色和文字
              final Color dotColor;
              final String label;
              if (connected) {
                dotColor = MoeTokens.success;
                label = '已连接';
              } else if (isOffline) {
                dotColor = Colors.amber;
                label = '离线模式';
              } else {
                dotColor = Colors.orange;
                label = '重连中';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 重连中状态添加脉冲动画
                    if (!connected && !isOffline)
                      _PulsingDot(color: dotColor, size: 8)
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // 小屏隐藏文字
                    if (!isCompact) ...[
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: dotColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
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
          Selector<LifeProvider, SummaryCardData>(
            selector: (_, p) => SummaryCardData(
              summary: p.summary,
              tickCount: p.tickCount,
              isConnected: p.connected,
              entityCount: p.entities.length,
              weather: p.summary.weather,
            ),
            builder: (context, data, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: LifeSummaryCard(
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
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Stack(
                children: [
                  // 地图
                  Positioned.fill(
                    child: Selector<LifeProvider, ({List<LifeEntity> entities, String weather})>(
                      selector: (_, p) => (entities: p.entities, weather: p.summary.weather),
                      builder: (context, data, _) {
                        final entities = data.entities;
                        return LifeWorldMap(
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
                            // 长按快捷喂食，离线时禁用
                            final provider = context.read<LifeProvider>();
                            if (provider.isOfflineMode) return;
                            final entity = entities
                                .where((e) => e.id == entityId)
                                .firstOrNull;
                            if (entity != null) {
                              _performActionWithFeedback(
                                  provider, 'feed', entity);
                            }
                          },
                          onEmptyDismissed: () {
                            // 标记引导已看过，关闭气泡
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setBool('life_guide_seen', true);
                            });
                            setState(() => _showGuideBubble = false);
                          },
                        );
                      },
                    ),
                  ),
                  // 离线模式横幅
                  Selector<LifeProvider, bool>(
                    selector: (_, p) => p.isOfflineMode,
                    builder: (context, isOffline, _) {
                      if (!isOffline) return const SizedBox.shrink();
                      return Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          color: Colors.amber.shade100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 16, color: Colors.amber.shade800),
                              const SizedBox(width: 6),
                              Text(
                                '离线模式 — 显示最近缓存数据',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                  // 世界事件横幅（使用本地状态，不依赖 Selector）
                  ..._buildEventBanners(),
                  // 反馈动画层（使用本地状态，不依赖 Selector）
                  ..._buildFeedbackOverlays(),
                  // 引导气泡（首次进入时展示）
                  if (_showGuideBubble)
                    Positioned(
                      bottom: 16,
                      left: 24,
                      right: 24,
                      child: _buildGuideBubble(),
                    ),
                ],
              ),
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
              LifeEventBanner(
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
                    LifeFeedbackOverlay(
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

  /// 构建引导气泡——新用户首次进入时在地图底部展示。
  Widget _buildGuideBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        gradient: MoeTokens.primaryGradient,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        boxShadow: MoeTokens.shadowMd(),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
          const SizedBox(width: MoeTokens.spaceSm),
          const Expanded(
            child: Text(
              '这里是你的数字生命世界，实体出现后点击即可互动',
              style: TextStyle(
                fontSize: MoeTokens.textSm,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          GestureDetector(
            onTap: () {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('life_guide_seen', true);
              });
              setState(() => _showGuideBubble = false);
            },
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

/// 重连中脉冲圆点动画
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, required this.size});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
