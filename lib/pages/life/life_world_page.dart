import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../services/game_service.dart';
import '../../services/companion_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_tile.dart';
import '../../widgets/moe_toast.dart';
import '../ai/game_play_page.dart';
import 'life_entity_detail.dart';
import 'life_inventory_page.dart';
import 'life_relationship_page.dart';

/// AI 伙伴陪伴主页。
///
/// 页面刻意不使用地图、世界坐标或 Canvas，优先保证移动端内容可见、
/// 可操作，并让用户聚焦于一个具体生命。
class LifeWorldPage extends StatefulWidget {
  const LifeWorldPage({super.key});

  @override
  State<LifeWorldPage> createState() => _LifeWorldPageState();
}

class _LifeWorldPageState extends State<LifeWorldPage> {
  late final LifeProvider _provider;
  int? _selectedEntityId;
  bool _isActing = false;
  bool _isOpeningStory = false;
  bool _isBindingCompanion = false;
  bool _bindingLoaded = false;
  CompanionProfileData? _companionProfile;
  String? _response;

  @override
  void initState() {
    super.initState();
    _provider = context.read<LifeProvider>();
    _provider.startListening();
    _loadCompanionBinding();
  }

  @override
  void dispose() {
    _provider.stopListening();
    super.dispose();
  }

  LifeEntity? _selectedEntity(List<LifeEntity> entities) {
    if (entities.isEmpty || !_bindingLoaded) return null;
    for (final entity in entities) {
      if (entity.id == _selectedEntityId) return entity;
    }
    return entities.first;
  }

  Future<void> _loadCompanionBinding() async {
    try {
      final profile = await CompanionService().getProfile();
      if (!mounted) return;
      setState(() {
        _companionProfile = profile;
        _selectedEntityId =
            profile.lifeEntityId == 0 ? null : profile.lifeEntityId;
        _bindingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _bindingLoaded = true);
    }
  }

  Future<void> _selectCompanion(LifeEntity entity) async {
    if (_isBindingCompanion || entity.id == _selectedEntityId) return;
    setState(() => _isBindingCompanion = true);
    try {
      final current =
          _companionProfile ?? await CompanionService().getProfile();
      final saved = await CompanionService().updateProfile(
        current.copyWith(
          name: entity.name,
          emoji: entity.emoji,
          lifeEntityId: entity.id,
        ),
      );
      if (!mounted) return;
      setState(() {
        _companionProfile = saved;
        _selectedEntityId = saved.lifeEntityId;
        _response = null;
      });
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
      setState(() {
        _response = action == 'feed'
            ? entity.hunger < 35
                ? '终于吃到了，谢谢你。'
                : '好满足，感觉又有精神了！'
            : entity.mood > 75
                ? '最喜欢你陪着我了。'
                : '感觉安心多了。';
      });
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

  void _openDetail(LifeEntity entity) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LifeEntityDetailPage(entity: entity)),
    );
  }

  Future<void> _openStory(LifeEntity entity) async {
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
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text('伙伴详情'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
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
          final bindingNeedsRepair =
              _selectedEntityId != null && selected.id != _selectedEntityId;

          return RefreshIndicator(
            onRefresh: () async {
              _provider.startListening();
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                if (data.isOffline) const _OfflineBanner(),
                if (bindingNeedsRepair) ...[
                  OutlinedButton.icon(
                    onPressed: _isBindingCompanion
                        ? null
                        : () => unawaited(_selectCompanion(selected)),
                    icon: const Icon(Icons.link_rounded),
                    label: Text('将 ${selected.name} 设为我的伙伴'),
                  ),
                  const SizedBox(height: 12),
                ],
                _CompanionHero(
                  entity: selected,
                  response: _response,
                  isActing: _isActing,
                  onFeed: () => _performAction('feed', selected),
                  onPet: () => _performAction('pet', selected),
                  onStory: () => _openStory(selected),
                  isOpeningStory: _isOpeningStory,
                  onDetail: () => _openDetail(selected),
                ),
                const SizedBox(height: 18),
                _CareInsightCard(entity: selected),
                const SizedBox(height: 18),
                _WorldPulseCard(
                  summary: data.summary,
                  tickCount: data.tickCount,
                  connected: data.connected,
                ),
                const SizedBox(height: 18),
                _SectionTitle(
                  title: '状态',
                  trailing:
                      '${selected.growthStageLabel} · ${selected.ageInDays} 天',
                ),
                const SizedBox(height: 10),
                _VitalCard(entity: selected),
                if (data.entities.length > 1) ...[
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: '其他居民',
                    trailing: '${data.entities.length} 位伙伴',
                  ),
                  const SizedBox(height: 10),
                  _ResidentList(
                    entities: data.entities,
                    selectedId: selected.id,
                    onSelected: (entity) => unawaited(_selectCompanion(entity)),
                  ),
                ],
                const SizedBox(height: 22),
                _SectionTitle(
                  title: '最近发生',
                  trailing: '共同记忆',
                ),
                const SizedBox(height: 10),
                _EventSection(events: data.events),
              ],
            ),
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
  return const _CareInsight(
    title: '状态稳定：适合观察',
    message: '它会按自己的节奏行动，可以看看最近事件或开启互动故事。',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF37A779),
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

class _CompanionHero extends StatelessWidget {
  final LifeEntity entity;
  final String? response;
  final bool isActing;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onStory;
  final bool isOpeningStory;
  final VoidCallback onDetail;

  const _CompanionHero({
    required this.entity,
    required this.response,
    required this.isActing,
    required this.onFeed,
    required this.onPet,
    required this.onStory,
    required this.isOpeningStory,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1D6), Color(0xFFFFFBF4)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD89C)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AFFA94D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: entity.growthStageColor.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: Text(entity.emoji, style: const TextStyle(fontSize: 54)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF312A25),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entity.actionLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A6B32),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          response ?? _defaultThought(entity),
                          key: ValueKey(response ?? entity.action),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF6E625A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroAction(
                  icon: Icons.restaurant_rounded,
                  label: '喂食',
                  color: const Color(0xFFF59E42),
                  busy: isActing,
                  onTap: onFeed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroAction(
                  icon: Icons.front_hand_rounded,
                  label: '陪伴',
                  color: const Color(0xFFE97891),
                  busy: isActing,
                  onTap: onPet,
                ),
              ),
              const SizedBox(width: 10),
              _DetailButton(onTap: onDetail),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isOpeningStory ? null : onStory,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF70594A),
              side: const BorderSide(color: Color(0xFFD8B98D)),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: isOpeningStory
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_stories_rounded),
            label: Text(
              '和 ${entity.name} 开始互动故事',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
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

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  const _HeroAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.55),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DetailButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: '查看详情',
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF70594A),
      ),
      icon: const Icon(Icons.arrow_forward_rounded),
    );
  }
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
  final ValueChanged<LifeEntity> onSelected;

  const _ResidentList({
    required this.entities,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entity = entities[index];
          final selected = entity.id == selectedId;
          return InkWell(
            onTap: () => onSelected(entity),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFEAC6) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFF59E42)
                      : const Color(0xFFE8E5E1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entity.emoji, style: const TextStyle(fontSize: 31)),
                  const SizedBox(height: 5),
                  Text(
                    entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
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
