import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/arena/arena_view_model.dart';
import '../../game/life/life_flame_game.dart';
import '../../models/life_state.dart';
import '../../services/life_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';

/// Arena 营地的只读预览页。
///
/// 本页只验证 Arena → Life 世界 → Flame 渲染的入口与快照链路。
/// 英雄和 Life 居民的持久映射将在后续 M1 版本接入。
class ArenaCampPreviewPage extends StatefulWidget {
  const ArenaCampPreviewPage({super.key, required this.hero});

  final ArenaHero hero;

  @override
  State<ArenaCampPreviewPage> createState() => _ArenaCampPreviewPageState();
}

class _ArenaCampPreviewPageState extends State<ArenaCampPreviewPage> {
  late final LifeFlameGame _game;
  LifeInitialState? _state;
  int? _selectedEntityId;
  Object? _loadError;
  bool _loading = true;
  int _syncAttempts = 0;

  @override
  void initState() {
    super.initState();
    _game = LifeFlameGame(onEntityTap: _selectEntity);
    unawaited(_loadWorld());
  }

  Future<void> _loadWorld() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final state = await LifeService.getInitialState();
      if (!mounted) return;
      final selectedId =
          state.entities.isNotEmpty ? state.entities.first.id : null;
      setState(() {
        _state = state;
        _selectedEntityId = selectedId;
        _loading = false;
      });
      _syncAttempts = 0;
      _syncGame();
    } catch (error) {
      debugPrint('Arena camp preview load failed: $error');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _selectEntity(int entityId) {
    if (_selectedEntityId == entityId) return;
    setState(() => _selectedEntityId = entityId);
    _game.focusEntity(entityId);
  }

  void _syncGame() {
    final state = _state;
    if (state == null) return;
    if (!_game.hasLayout) {
      _retryGameSync();
      return;
    }
    try {
      _game.setBoundEntityId(_selectedEntityId);
      _game.syncEntities(state.entities, selectedId: _selectedEntityId);
      _game.syncRecentEvents(state.events.take(8).toList(growable: false));
      final selectedId = _selectedEntityId;
      if (selectedId != null) {
        _game.focusEntity(selectedId);
      }
    } catch (error) {
      if (error.toString().contains('hasLayout')) {
        _retryGameSync();
        return;
      }
      rethrow;
    }
  }

  void _retryGameSync() {
    if (!mounted || _syncAttempts >= 20) return;
    _syncAttempts++;
    unawaited(Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _syncGame();
    }));
  }

  LifeEntity? get _selectedEntity {
    final selectedId = _selectedEntityId;
    final entities = _state?.entities ?? const <LifeEntity>[];
    if (selectedId == null) return null;
    for (final entity in entities) {
      if (entity.id == selectedId) return entity;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (_loading) {
      return const Scaffold(body: MoeLoading());
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('营地预览')),
        body: Center(
          child: MoeErrorState(
            presentation: _campErrorPresentation(_loadError),
            onRetry: () => unawaited(_loadWorld()),
          ),
        ),
      );
    }
    if (state == null || state.entities.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('营地预览')),
        body: const Center(child: Text('营地正在准备中，请稍后再试')),
      );
    }

    final selected = _selectedEntity;
    final selectedTitle = selected == null
        ? '正在观察营地'
        : '${selected.emoji} ${selected.name} · ${selected.actionLabel}';
    return Scaffold(
      backgroundColor: const Color(0xFFB8D9C4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(MoeTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: '返回小家',
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      Expanded(
                        child: _TopCard(
                          title: '${widget.hero.name} 的营地预览',
                          subtitle: '共享世界只读快照 · Tick ${state.tick}',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _TopCard(
                    title: selectedTitle,
                    subtitle: '当前为入口与渲染验证；英雄居民映射将在下一阶段接入。',
                  ),
                  const SizedBox(height: MoeTokens.spaceSm),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.entities.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: MoeTokens.spaceSm),
                      itemBuilder: (context, index) {
                        final entity = state.entities[index];
                        final selected = entity.id == _selectedEntityId;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) => _selectEntity(entity.id),
                          avatar: Text(entity.emoji),
                          label: Text(entity.name),
                        );
                      },
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

  MoeErrorPresentation _campErrorPresentation(Object? error) {
    if (error is ApiException && error.code == 404) {
      return const MoeErrorPresentation(
        kind: MoeErrorKind.server,
        title: '营地服务未就绪',
        subtitle: '当前后端未提供 Life 营地接口，请重启包含 Life 域的后端后重试。',
        icon: Icons.park_outlined,
      );
    }
    return MoeErrorCopy.resolve(error, scene: MoeErrorScene.pageLoad);
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MoeTokens.spaceMd,
          vertical: MoeTokens.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
