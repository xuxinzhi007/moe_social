import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/feature_flags.dart';
import '../../game/life/life_flame_game.dart';
import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../services/game_service.dart';
import '../../services/companion_chat_launcher.dart';
import '../../services/companion_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_tile.dart';
import '../../widgets/life/life_world_map.dart';
import '../../widgets/moe_toast.dart';
import '../ai/game_play_page.dart';
import 'life_entity_detail.dart';
import 'life_inventory_page.dart';
import 'life_relationship_page.dart';

/// TA 的世界（从关系首页延伸进入）。
///
/// 方案 2：底栏 AI伙伴仍是关系首页；本页全屏地图为舞台，
/// 照料/概况叠在底部可拖拽面板。
/// [FeatureFlags.useFlameLifeWorld]=true 时用地图 Flame 实验渲染。
///
/// [focusEntityId]：从关系首页带入的绑定实体，进页后应对焦该居民。
class LifeWorldPage extends StatefulWidget {
  const LifeWorldPage({super.key, this.focusEntityId});

  /// 优先对焦的 Life 实体 ID（通常 = companion.life_entity_id）。
  final int? focusEntityId;

  @override
  State<LifeWorldPage> createState() => _LifeWorldPageState();
}

class _LifeWorldPageState extends State<LifeWorldPage> {
  /// 默认只露出一条薄 HUD，避免挡住全屏世界。
  static const double _sheetPeekSize = 0.118;
  static const double _sheetFocusSize = 0.42;
  static const double _sheetMinSize = 0.10;
  static const double _sheetMaxSize = 0.78;

  late final LifeProvider _provider;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  LifeFlameGame? _flameGame;
  int? _selectedEntityId;
  bool _isActing = false;
  bool _isOpeningStory = false;
  bool _isBindingCompanion = false;
  bool _bindingLoaded = false;
  bool _didInitialFocus = false;
  CompanionProfileData? _companionProfile;
  String? _response;

  @override
  void initState() {
    super.initState();
    _provider = context.read<LifeProvider>();
    _provider.startListening();
    final hint = widget.focusEntityId ?? 0;
    if (hint > 0) {
      _selectedEntityId = hint;
    }
    _loadCompanionBinding();
    if (FeatureFlags.useFlameLifeWorld) {
      _flameGame = LifeFlameGame(
        onEntityTap: _focusEntity,
        onEntityLongPress: _openDetailById,
      );
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _provider.stopListening();
    super.dispose();
  }

  void _openDetailById(int id) {
    for (final entity in _provider.entities) {
      if (entity.id == id) {
        _openDetail(entity);
        return;
      }
    }
  }

  LifeEntity? _selectedEntity(List<LifeEntity> entities) {
    if (entities.isEmpty || !_bindingLoaded) return null;
    final resolvedId = _resolveFocusEntityId(entities);
    if (resolvedId != null) {
      for (final entity in entities) {
        if (entity.id == resolvedId) return entity;
      }
    }
    return entities.first;
  }

  /// 绑定 ID > 入参 hint > 当前选中 > 名称匹配 > null（再由调用方回退 first）。
  int? _resolveFocusEntityId(List<LifeEntity> entities) {
    if (entities.isEmpty) return null;
    final ids = entities.map((e) => e.id).toSet();

    final boundId = _companionProfile?.lifeEntityId ?? 0;
    if (boundId > 0 && ids.contains(boundId)) return boundId;

    final hint = widget.focusEntityId ?? 0;
    if (hint > 0 && ids.contains(hint)) return hint;

    final selected = _selectedEntityId;
    if (selected != null && selected > 0 && ids.contains(selected)) {
      return selected;
    }

    final name = _companionProfile?.name.trim() ?? '';
    if (name.isNotEmpty) {
      for (final entity in entities) {
        if (entity.name.trim() == name) return entity.id;
      }
    }
    return null;
  }

  Future<void> _loadCompanionBinding() async {
    try {
      final profile = await CompanionService().getProfile();
      if (!mounted) return;
      final boundId = profile.lifeEntityId;
      setState(() {
        _companionProfile = profile;
        // 已绑定：强制对焦绑定实体；未绑定：保留入参 hint / 现选中。
        if (boundId > 0) {
          _selectedEntityId = boundId;
        } else if ((_selectedEntityId ?? 0) <= 0) {
          final hint = widget.focusEntityId ?? 0;
          _selectedEntityId = hint > 0 ? hint : null;
        }
        _bindingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _bindingLoaded = true);
    }
  }

  void _focusEntity(int entityId) {
    final changed = _selectedEntityId != entityId;
    if (changed) {
      setState(() {
        _selectedEntityId = entityId;
        _response = null;
      });
    }
    _flameGame?.focusEntity(entityId);
    // 点选只更新 HUD，不自动抬高面板（避免挡世界）。
    _expandSheet(_sheetPeekSize);
  }

  /// 首帧实体就绪后，把选中纠正为绑定伙伴并镜头跟随。
  void _ensureInitialBoundFocus(
      List<LifeEntity> entities, LifeEntity selected) {
    if (_didInitialFocus || entities.isEmpty) return;
    final targetId = _resolveFocusEntityId(entities) ?? selected.id;
    _didInitialFocus = true;
    if (_selectedEntityId != targetId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedEntityId = targetId;
          _response = null;
        });
        _flameGame?.focusEntity(targetId);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flameGame?.focusEntity(targetId);
    });
  }

  void _expandSheet(double size) {
    if (!_sheetController.isAttached) return;
    unawaited(
      _sheetController.animateTo(
        size.clamp(_sheetMinSize, _sheetMaxSize),
        duration: MoeTokens.motionFadeDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// 同名居民加 #id，避免两个「啾啾」无法区分。
  static Map<int, String> _residentDisplayNames(List<LifeEntity> entities) {
    final counts = <String, int>{};
    for (final e in entities) {
      final key = e.name.trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final out = <int, String>{};
    for (final e in entities) {
      final key = e.name.trim();
      out[e.id] = (counts[key] ?? 0) > 1 ? '$key#${e.id}' : key;
    }
    return out;
  }

  Future<void> _selectCompanion(LifeEntity entity) async {
    final alreadyBound = (_companionProfile?.lifeEntityId ?? 0) == entity.id;
    if (_isBindingCompanion || alreadyBound) return;
    setState(() => _isBindingCompanion = true);
    try {
      final current =
          _companionProfile ?? await CompanionService().getProfile();
      // 双层身份：只改世界绑定，不覆盖关系层名字/头像/人设。
      final saved = await CompanionService().updateProfile(
        current.copyWith(lifeEntityId: entity.id),
      );
      if (!mounted) return;
      setState(() {
        _companionProfile = saved;
        _selectedEntityId = saved.lifeEntityId;
        _response = null;
      });
      _flameGame?.focusEntity(saved.lifeEntityId);
      if (mounted) {
        MoeToast.success(context, '已将 ${entity.name} 设为当前伙伴');
      }
    } catch (error) {
      if (mounted) {
        MoeToast.error(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isBindingCompanion = false);
    }
  }

  Future<void> _performAction(String action, LifeEntity entity) async {
    if (_isActing || _provider.isOfflineMode) return;
    setState(() {
      _isActing = true;
      _response = null;
    });

    final success = await _provider.performAction(action, entity.id);
    if (!mounted) return;

    if (success) {
      final reply = await _resolveCareReply(action, entity);
      if (!mounted) return;
      setState(() => _response = reply);
      final boundId = _companionProfile?.lifeEntityId ?? 0;
      if (boundId > 0 && boundId == entity.id) {
        unawaited(CompanionService().bumpIntimacy(reason: action));
      }
    } else if (_provider.lastActionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_provider.lastActionError!),
          backgroundColor: _provider.lastActionIsCooldown
              ? MoeTokens.warning
              : MoeTokens.danger,
        ),
      );
      _provider.clearActionError();
    }

    if (mounted) setState(() => _isActing = false);
  }

  /// 绑定伙伴优先用 companion state 语气；否则回退本地短句。
  Future<String> _resolveCareReply(String action, LifeEntity entity) async {
    final fallback = _fallbackCareReply(action, entity);
    final boundId = _companionProfile?.lifeEntityId ?? 0;
    if (boundId == 0 || boundId != entity.id) return fallback;
    try {
      final snapshot = await CompanionService().getSnapshot();
      final thought = snapshot.state.moodThought.trim();
      if (thought.isNotEmpty) return thought;
      final greeting = snapshot.state.greeting.trim();
      if (greeting.isNotEmpty) return greeting;
    } catch (_) {}
    return fallback;
  }

  static String _fallbackCareReply(String action, LifeEntity entity) {
    if (action == 'feed') {
      return entity.hunger < 35 ? '终于吃到了，谢谢你。' : '好满足，感觉又有精神了！';
    }
    return entity.mood > 75 ? '最喜欢你陪着我了。' : '感觉安心多了。';
  }

  Future<void> _openCompanionChat() async {
    try {
      await CompanionChatLauncher.openChat(context);
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _openDetail(LifeEntity entity) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LifeEntityDetailPage(entity: entity)),
    );
  }

  Future<void> _openStory(LifeEntity entity) async {
    if (!FeatureFlags.showGameFeatures) {
      MoeToast.info(context, '互动故事暂未开放');
      return;
    }
    if (_isOpeningStory) return;
    setState(() => _isOpeningStory = true);
    try {
      final state = await GameService().initSession();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            initialState: state,
            companionName: entity.name,
            companionEmoji: entity.emoji,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isOpeningStory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F2E4),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('TA 的世界'),
        centerTitle: true,
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: '我的背包',
            icon: const Icon(Icons.backpack_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LifeInventoryPage()),
            ),
          ),
          IconButton(
            tooltip: '关系网络',
            icon: const Icon(Icons.hub_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LifeRelationshipPage()),
            ),
          ),
          Selector<LifeProvider, bool>(
            selector: (_, provider) => provider.connected,
            builder: (_, connected, __) => Padding(
              padding: const EdgeInsets.only(left: 4, right: 16),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: connected ? MoeTokens.success : MoeTokens.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Selector<LifeProvider, _CompanionPageData>(
        selector: (_, provider) {
          final selected = _selectedEntity(provider.entities);
          return _CompanionPageData(
            entities: provider.entities,
            selected: selected,
            events: selected == null
                ? const []
                : provider.getEventsForEntity(selected.id).take(5).toList(),
            summary: provider.summary,
            tickCount: provider.tickCount,
            connected: provider.connected,
            isInitialized: provider.isInitialized,
            isOffline: provider.isOfflineMode,
          );
        },
        builder: (context, data, _) {
          if ((!data.isInitialized && data.entities.isEmpty) ||
              !_bindingLoaded) {
            return const _LoadingState();
          }
          if (data.entities.isEmpty) {
            return _EmptyState(isOffline: data.isOffline);
          }

          final selected = data.selected;
          if (selected == null) return const _LoadingState();
          _ensureInitialBoundFocus(data.entities, selected);
          final boundId = _companionProfile?.lifeEntityId ?? 0;
          final isBoundCompanion = boundId != 0 && selected.id == boundId;
          final hasAnyBinding = boundId > 0;
          // 已绑当前选中：不显示 CTA；已绑其他居民：显示「改绑」；未绑：显示「设为伙伴」。
          final showBindCta = !isBoundCompanion;
          final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
          final eventTickerLines = _provider.recentEvents
              .take(12)
              .map((e) => e.desc.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false);

          final flame = _flameGame;
          if (flame != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              flame.syncEntities(
                data.entities,
                selectedId: selected.id,
              );
              flame.syncRecentEvents(
                _provider.recentEvents.take(8).toList(growable: false),
              );
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: flame != null
                    ? GameWidget(game: flame)
                    : LifeWorldMap(
                        entities: data.entities,
                        edgeToEdge: true,
                        onEntityTap: _focusEntity,
                        onEntityLongPress: _openDetailById,
                      ),
              ),
              if (data.isOffline)
                Positioned(
                  top: topInset + 8,
                  left: 12,
                  right: 12,
                  child: const _OfflineBanner(),
                ),
              if (eventTickerLines.isNotEmpty)
                Positioned(
                  top: topInset + (data.isOffline ? 48 : 8),
                  left: 12,
                  right: 12,
                  child: _WorldEventTicker(lines: eventTickerLines),
                ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: _sheetPeekSize,
                minChildSize: _sheetMinSize,
                maxChildSize: _sheetMaxSize,
                snap: true,
                snapSizes: const [_sheetPeekSize, _sheetFocusSize, 0.72],
                builder: (context, scrollController) {
                  // 游戏 HUD：peek 只露薄条；上滑再展开详情，避免双份身份卡 + 底栏裁切。
                  return AnimatedBuilder(
                    animation: _sheetController,
                    builder: (context, _) {
                      final sheetSize = _sheetController.isAttached
                          ? _sheetController.size
                          : _sheetPeekSize;
                      final showDetails = sheetSize > _sheetPeekSize + 0.05;
                      return Material(
                        color: Colors.white.withValues(alpha: 0.94),
                        elevation: 8,
                        shadowColor: Colors.black26,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            showDetails ? 28 : 10,
                          ),
                          children: [
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CompactCareBar(
                              entity: selected,
                              isActing: _isActing,
                              bound: isBoundCompanion,
                              onFeed: () => _performAction('feed', selected),
                              onPet: () => _performAction('pet', selected),
                              onExpand: () => _expandSheet(_sheetFocusSize),
                            ),
                            if (showDetails) ...[
                              const SizedBox(height: 12),
                              if (showBindCta) ...[
                                FilledButton.tonalIcon(
                                  onPressed: _isBindingCompanion
                                      ? null
                                      : () =>
                                          unawaited(_selectCompanion(selected)),
                                  icon: Icon(
                                    hasAnyBinding
                                        ? Icons.swap_horiz_rounded
                                        : Icons.link_rounded,
                                  ),
                                  label: Text(
                                    hasAnyBinding
                                        ? '改绑为 ${selected.name}'
                                        : '将 ${selected.name} 设为我的伙伴',
                                  ),
                                ),
                                if (hasAnyBinding && !isBoundCompanion)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '当前伙伴是另一位居民（ID $boundId）。同名时请点对卡片再绑定。',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],
                              _StatusThoughtCard(
                                entity: selected,
                                response: _response,
                                onChat: isBoundCompanion
                                    ? () => unawaited(_openCompanionChat())
                                    : null,
                                onDetail: () => _openDetail(selected),
                                onStory: FeatureFlags.showGameFeatures
                                    ? () => _openStory(selected)
                                    : null,
                                isOpeningStory: _isOpeningStory,
                              ),
                              if (data.entities.length > 1) ...[
                                const SizedBox(height: 12),
                                const _SectionTitle(
                                  title: '居民',
                                  trailing: '点地图或卡片切换',
                                ),
                                const SizedBox(height: 8),
                                _ResidentList(
                                  entities: data.entities,
                                  selectedId: selected.id,
                                  boundId: boundId,
                                  displayNames: _residentDisplayNames(
                                    data.entities,
                                  ),
                                  onSelected: (entity) =>
                                      _focusEntity(entity.id),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _CareInsightCard(entity: selected),
                              const SizedBox(height: 12),
                              _VitalCard(entity: selected),
                              const SizedBox(height: 12),
                              _WorldPulseCard(
                                summary: data.summary,
                                tickCount: data.tickCount,
                                connected: data.connected,
                              ),
                              const SizedBox(height: 16),
                              const _SectionTitle(
                                title: '最近发生',
                                trailing: '共同记忆',
                              ),
                              const SizedBox(height: 10),
                              _EventSection(events: data.events),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompanionPageData {
  final List<LifeEntity> entities;
  final LifeEntity? selected;
  final List<LifeEvent> events;
  final LifeWorldSummary summary;
  final int tickCount;
  final bool connected;
  final bool isInitialized;
  final bool isOffline;

  const _CompanionPageData({
    required this.entities,
    required this.selected,
    required this.events,
    required this.summary,
    required this.tickCount,
    required this.connected,
    required this.isInitialized,
    required this.isOffline,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CompanionPageData &&
        isInitialized == other.isInitialized &&
        isOffline == other.isOffline &&
        tickCount == other.tickCount &&
        connected == other.connected &&
        _sameWorldSummary(summary, other.summary) &&
        _sameEntityState(selected, other.selected) &&
        _sameResidents(entities, other.entities) &&
        _sameLifeEvents(events, other.events);
  }

  @override
  int get hashCode => Object.hash(
        isInitialized,
        isOffline,
        selected?.id,
        selected?.action,
        selected == null ? 0 : _statusBucket(selected!.hunger),
        _statusBucket(summary.avgHunger),
        _statusBucket(summary.avgEnergy),
        _statusBucket(summary.avgMood),
        tickCount,
        connected,
        entities.length,
        events.length,
      );
}

bool _sameWorldSummary(LifeWorldSummary left, LifeWorldSummary right) {
  return left.aliveCount == right.aliveCount &&
      left.birthCount == right.birthCount &&
      left.deathCount == right.deathCount &&
      _statusBucket(left.avgHunger) == _statusBucket(right.avgHunger) &&
      _statusBucket(left.avgEnergy) == _statusBucket(right.avgEnergy) &&
      _statusBucket(left.avgMood) == _statusBucket(right.avgMood) &&
      left.totalFood == right.totalFood &&
      left.dangerCells == right.dangerCells;
}

bool _sameEntityState(LifeEntity? left, LifeEntity? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return left == right;
  return left.id == right.id &&
      left.name == right.name &&
      left.emoji == right.emoji &&
      left.action == right.action &&
      left.growthStage == right.growthStage &&
      _statusBucket(left.hunger) == _statusBucket(right.hunger) &&
      _statusBucket(left.energy) == _statusBucket(right.energy) &&
      _statusBucket(left.mood) == _statusBucket(right.mood);
}

bool _sameResidents(List<LifeEntity> left, List<LifeEntity> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i].id != right[i].id ||
        left[i].name != right[i].name ||
        left[i].emoji != right[i].emoji ||
        left[i].growthStage != right[i].growthStage) {
      return false;
    }
  }
  return true;
}

bool _sameLifeEvents(List<LifeEvent> left, List<LifeEvent> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i].type != right[i].type ||
        left[i].desc != right[i].desc ||
        left[i].timestamp != right[i].timestamp) {
      return false;
    }
  }
  return true;
}

int _statusBucket(double value) => (value.clamp(0, 100) / 5).floor();

class _CareInsightCard extends StatelessWidget {
  final LifeEntity entity;

  const _CareInsightCard({required this.entity});

  @override
  Widget build(BuildContext context) {
    final insight = _careInsightFor(entity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: insight.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(insight.icon, color: insight.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: insight.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF6D645E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _CareInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.textColor,
  });
}

_CareInsight _careInsightFor(LifeEntity entity) {
  if (entity.hunger < 30) {
    return const _CareInsight(
      title: '优先照料：需要进食',
      message: '先喂食会更快稳定状态，饱腹恢复后它会更愿意探索。',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF59E42),
      textColor: Color(0xFF8A4B09),
    );
  }
  if (entity.energy < 30) {
    return const _CareInsight(
      title: '优先照料：需要休息',
      message: '现在适合轻陪伴，避免连续操作，让它慢慢恢复精力。',
      icon: Icons.bedtime_rounded,
      color: Color(0xFF5B8DEF),
      textColor: Color(0xFF2459A6),
    );
  }
  if (entity.mood < 38) {
    return const _CareInsight(
      title: '优先照料：需要陪伴',
      message: '陪伴能改善心情，也更容易触发有温度的共同事件。',
      icon: Icons.favorite_rounded,
      color: Color(0xFFE97891),
      textColor: Color(0xFFA53B54),
    );
  }
  return _CareInsight(
    title: '状态稳定：适合观察',
    message: FeatureFlags.showGameFeatures
        ? '它会按自己的节奏行动，可以看看最近事件或开启互动故事。'
        : '它会按自己的节奏行动，可以看看最近事件，慢慢陪伴它成长。',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFF37A779),
    textColor: Color(0xFF247250),
  );
}

class _WorldPulseCard extends StatelessWidget {
  final LifeWorldSummary summary;
  final int tickCount;
  final bool connected;

  const _WorldPulseCard({
    required this.summary,
    required this.tickCount,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '小世界概况',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF312E2B),
                  ),
                ),
              ),
              _ConnectionPill(connected: connected),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PulseMetric(
                  label: '居民',
                  value: '${summary.aliveCount}',
                  subLabel: 'tick $tickCount',
                  color: const Color(0xFF37A779),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(
                  label: '平均状态',
                  value: '${_averageStatus(summary).round()}',
                  subLabel: _worldMoodLabel(summary),
                  color: const Color(0xFFF59E42),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(
                  label: '生态风险',
                  value: '${summary.dangerCells}',
                  subLabel: summary.dangerCells > 0 ? '需观察' : '平稳',
                  color: summary.dangerCells > 0
                      ? MoeTokens.warning
                      : const Color(0xFF5B8DEF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool connected;

  const _ConnectionPill({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? MoeTokens.success : MoeTokens.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? '实时' : '缓存',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final Color color;

  const _PulseMetric({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7B746E)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8F8780)),
          ),
        ],
      ),
    );
  }
}

double _averageStatus(LifeWorldSummary summary) {
  return (summary.avgHunger + summary.avgEnergy + summary.avgMood) / 3;
}

String _worldMoodLabel(LifeWorldSummary summary) {
  final avg = _averageStatus(summary);
  if (avg >= 72) return '活跃';
  if (avg >= 45) return '普通';
  return '低迷';
}

/// 默认 peek 露出的薄条：身份 + 喂食/陪伴（游戏 HUD），上滑才见详情。
class _CompactCareBar extends StatelessWidget {
  const _CompactCareBar({
    required this.entity,
    required this.isActing,
    required this.bound,
    required this.onFeed,
    required this.onPet,
    required this.onExpand,
  });

  final LifeEntity entity;
  final bool isActing;
  final bool bound;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8EE),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: entity.growthStageColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(entity.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF312A25),
                            ),
                          ),
                        ),
                        if (bound) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE97891).withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              '伙伴',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE97891),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      entity.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A6B3F),
                      ),
                    ),
                  ],
                ),
              ),
              _CompactActionChip(
                label: '喂食',
                color: const Color(0xFFF59E42),
                onPressed: isActing ? null : onFeed,
              ),
              const SizedBox(width: 6),
              _CompactActionChip(
                label: '陪伴',
                color: const Color(0xFFE97891),
                onPressed: isActing ? null : onPet,
              ),
              IconButton(
                tooltip: '展开',
                visualDensity: VisualDensity.compact,
                onPressed: onExpand,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展开层：心声 + 次级入口（不再重复大头像/喂食按钮）。
class _StatusThoughtCard extends StatelessWidget {
  const _StatusThoughtCard({
    required this.entity,
    required this.response,
    required this.onDetail,
    this.onChat,
    this.onStory,
    this.isOpeningStory = false,
  });

  final LifeEntity entity;
  final String? response;
  final VoidCallback onDetail;
  final VoidCallback? onChat;
  final VoidCallback? onStory;
  final bool isOpeningStory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD89C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response ?? _defaultThought(entity),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF6E625A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onChat != null)
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: Text('和 ${entity.name} 聊天'),
                  onPressed: onChat,
                ),
              ActionChip(
                avatar: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('详情'),
                onPressed: onDetail,
              ),
              if (onStory != null)
                ActionChip(
                  avatar: isOpeningStory
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_stories_rounded, size: 16),
                  label: const Text('互动故事'),
                  onPressed: isOpeningStory ? null : onStory,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactActionChip extends StatelessWidget {
  const _CompactActionChip({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _defaultThought(LifeEntity entity) {
  if (entity.hunger < 30) return '肚子有点饿了，想吃点东西。';
  if (entity.energy < 30) return '今天有点困，想安静地休息。';
  if (entity.mood < 35) return '希望你能多陪我一会儿。';
  return '今天也在认真生活，见到你很开心。';
}

class _VitalCard extends StatelessWidget {
  final LifeEntity entity;

  const _VitalCard({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        children: [
          _VitalRow(
            label: '饱腹',
            value: entity.hunger,
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFF59E42),
          ),
          const SizedBox(height: 14),
          _VitalRow(
            label: '精力',
            value: entity.energy,
            icon: Icons.bolt_rounded,
            color: const Color(0xFF5B8DEF),
          ),
          const SizedBox(height: 14),
          _VitalRow(
            label: '心情',
            value: entity.mood,
            icon: Icons.favorite_rounded,
            color: const Color(0xFFE97891),
          ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _VitalRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }
}

class _ResidentList extends StatelessWidget {
  final List<LifeEntity> entities;
  final int selectedId;
  final int boundId;
  final Map<int, String> displayNames;
  final ValueChanged<LifeEntity> onSelected;

  const _ResidentList({
    required this.entities,
    required this.selectedId,
    required this.boundId,
    required this.displayNames,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        itemCount: entities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entity = entities[index];
          final selected = entity.id == selectedId;
          final isBound = boundId > 0 && entity.id == boundId;
          return InkWell(
            onTap: () => onSelected(entity),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 76,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFEAC6) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFF59E42)
                      : const Color(0xFFE8E5E1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entity.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(
                    () {
                      final base =
                          displayNames[entity.id] ?? entity.name.trim();
                      return isBound ? '$base·伴' : base;
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isBound
                          ? const Color(0xFFE97891)
                          : const Color(0xFF312A25),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  final List<LifeEvent> events;

  const _EventSection({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          children: [
            Icon(Icons.auto_stories_outlined, color: Color(0xFFB4AEA8)),
            SizedBox(height: 8),
            Text('相处的故事会记录在这里', style: TextStyle(color: Color(0xFF8B837C))),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          LifeEventTile(
            event: events[i],
            compact: true,
            showTimeline: true,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF312E2B),
            ),
          ),
        ),
        Text(trailing,
            style: const TextStyle(fontSize: 12, color: Color(0xFF938C86))),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0D5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: MoeTokens.warning),
          SizedBox(width: 8),
          Expanded(child: Text('当前展示缓存状态，连接恢复后可以互动。')),
        ],
      ),
    );
  }
}

/// 顶部世界事件跑马灯（数据来自 recentEvents，照料事件已同步落库）。
///
/// 短文案只显示一份；超出可视宽度时才复制第二份做无缝滚动，避免「并排重复」。
class _WorldEventTicker extends StatefulWidget {
  const _WorldEventTicker({required this.lines});

  final List<String> lines;

  @override
  State<_WorldEventTicker> createState() => _WorldEventTickerState();
}

class _WorldEventTickerState extends State<_WorldEventTicker> {
  static const _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF4A3F38),
  );

  late final ScrollController _controller;
  Timer? _timer;
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_looping || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _controller.offset + 0.6;
      _controller.jumpTo(next >= max ? 0 : next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 连续相同事件描述去重，避免「啾啾… · 啾啾…」叠字。
  String _joinedText() {
    final out = <String>[];
    for (final raw in widget.lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (out.isNotEmpty && out.last == line) continue;
      out.add(line);
    }
    return out.join('   ·   ');
  }

  @override
  Widget build(BuildContext context) {
    final text = _joinedText();
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              size: 16,
              color: Color(0xFFE97891),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 18,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final painter = TextPainter(
                      text: TextSpan(text: text, style: _textStyle),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                    )..layout();
                    final needLoop = painter.width > constraints.maxWidth + 1;
                    if (_looping != needLoop) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _looping = needLoop);
                        if (!needLoop && _controller.hasClients) {
                          _controller.jumpTo(0);
                        }
                      });
                    }
                    if (!needLoop) {
                      return Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _textStyle,
                      );
                    }
                    // 两段之间拉开间距，无缝循环时不会贴成「双标题」。
                    return ListView(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        Text(text, style: _textStyle),
                        SizedBox(
                            width: math.max(80, constraints.maxWidth * 0.35)),
                        Text(text, style: _textStyle),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('正在唤醒 AI 伙伴...'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isOffline;

  const _EmptyState({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥚', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text(
              '生命正在孵化',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline ? '连接恢复后再来看看它吧。' : '世界已经启动，请稍等片刻。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF827B75)),
            ),
          ],
        ),
      ),
    );
  }
}
