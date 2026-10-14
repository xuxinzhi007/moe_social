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

/// Arena 营地的全屏世界页（O1）。
///
/// 进入共享世界，视角默认聚焦自己的英雄（hero_slug 匹配，
/// M1 为旗舰英雄小星）；其他英雄与居民可见为营地居民。
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
      final selectedId = _resolveFocusEntityId(state);
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

  /// 默认聚焦自己的英雄：优先 hero_slug 与当前小家英雄一致，
  /// 否则任一英雄居民，最后回退第一个居民。
  int? _resolveFocusEntityId(LifeInitialState state) {
    if (state.entities.isEmpty) return null;
    for (final entity in state.entities) {
      if (entity.heroSlug.isNotEmpty && entity.heroSlug == widget.hero.id) {
        return entity.id;
      }
    }
    for (final entity in state.entities) {
      if (entity.heroSlug.isNotEmpty) return entity.id;
    }
    return state.entities.first.id;
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
        appBar: AppBar(title: const Text('星辉营地')),
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
        appBar: AppBar(title: const Text('星辉营地')),
        body: const Center(child: Text('营地正在准备中，请稍后再试')),
      );
    }

    final selected = _selectedEntity;
    final selectedTitle = selected == null
        ? '正在观察营地'
        : '${selected.emoji} ${selected.name} · ${selected.actionLabel}';
    final selectedIsHero = selected != null && selected.heroSlug.isNotEmpty;
    final worldHasHero = state.entities.any((e) => e.heroSlug.isNotEmpty);
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
                          title: '${widget.hero.name} 的星辉营地',
                          subtitle: '共享世界实时快照 · Tick ${state.tick}',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _TopCard(
                    title: selectedTitle,
                    subtitle: selectedIsHero
                        ? '这是你的英雄在共享营地里的实时生活。'
                        : worldHasHero
                            ? '点下方居民可切换观察对象，⭐ 是入驻英雄。'
                            : '英雄暂未出现在营地舞台上，先看看居民们的生活。',
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
                          label: Text(entity.heroSlug.isNotEmpty
                              ? '⭐ ${entity.name}'
                              : entity.name),
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
