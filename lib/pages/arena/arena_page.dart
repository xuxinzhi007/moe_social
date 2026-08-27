import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/arena/arena_battle_game.dart';
import '../../game/arena/arena_view_model.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/motion/moe_pressable.dart';

class ArenaPage extends StatefulWidget {
  const ArenaPage({
    super.key,
    this.initialView = ArenaView.lobby,
    this.modelForTesting,
  });

  const ArenaPage.home({super.key})
      : initialView = ArenaView.home,
        modelForTesting = null;

  final ArenaView initialView;
  final ArenaViewModel? modelForTesting;

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage>
    with SingleTickerProviderStateMixin {
  static const double _designWidth = 800;
  static const double _designHeight = 450;
  static const double _navHeight = 56;
  static const double _navGap = 12;

  late final ArenaViewModel _model;
  late final ArenaBattleGame _game;
  late final AnimationController _uiPulse;
  late final bool _ownsModel;
  bool _formationSaved = false;
  bool _showSummonPool = false;

  @override
  void initState() {
    super.initState();
    _ownsModel = widget.modelForTesting == null;
    _model = widget.modelForTesting ??
        ArenaViewModel(initialView: widget.initialView);
    _game = ArenaBattleGame(model: _model);
    _uiPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    if (_ownsModel) {
      unawaited(_model.hydrate());
    }
  }

  Future<void> _onHomeGift() async {
    await _model.giftAtHome();
  }

  Future<void> _onHomeTrain() async {
    await _model.trainAtHome();
  }

  @override
  void dispose() {
    _uiPulse.dispose();
    if (_ownsModel) {
      _model.dispose();
    }
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ArenaColors.ink,
      body: SafeArea(
        minimum: const EdgeInsets.all(4),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(
                  constraints.maxWidth / _designWidth,
                  constraints.maxHeight / _designHeight,
                );
                return ClipRect(
                  child: Center(
                    child: OverflowBox(
                      minWidth: _designWidth,
                      maxWidth: _designWidth,
                      minHeight: _designHeight,
                      maxHeight: _designHeight,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: _designWidth,
                          height: _designHeight,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(1),
                            ),
                            child: AnimatedBuilder(
                              animation: _model,
                              builder: (context, _) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildView(),
                                  if (_model.view != ArenaView.battle &&
                                      _model.summonResults.isEmpty)
                                    _buildNavigation(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView() {
    switch (_model.view) {
      case ArenaView.lobby:
        return _buildLobby();
      case ArenaView.home:
        return _buildHome();
      case ArenaView.formation:
        return _buildFormation();
      case ArenaView.tower:
        return _buildTower();
      case ArenaView.summon:
        return _buildSummon();
      case ArenaView.collection:
        return _buildCollection();
      case ArenaView.character:
        return _buildCharacter();
      case ArenaView.battle:
        return _buildBattle();
    }
  }

  void _saveFormation() {
    setState(() => _formationSaved = true);
    unawaited(_model.syncFormation());
  }

  void _openSummonPool() {
    setState(() => _showSummonPool = true);
  }

  void _closeSummonPool() {
    setState(() => _showSummonPool = false);
  }

  Widget _buildLobby() {
    final hero = _model.heroes.first;
    return Stack(
      children: [
        const Positioned.fill(child: _LobbyBackground()),
        _topBar('AURORA · 星辉远征'),
        Positioned(
          left: 34,
          top: 70,
          width: 340,
          child: _TitleBlock(
            title: '星辉大厅',
            subtitle: '编队、召唤、爬塔和卡牌战斗都从这里进入。',
          ),
        ),
        Positioned(
          left: 300,
          bottom: _navHeight + 8,
          width: 225,
          height: 272,
          child: _HeroPortrait(
            hero: hero,
            showFrame: true,
            imageAsset: _model.portraitAssetOf(hero),
            tint: _model.portraitTintOf(hero),
          ),
        ),
        Positioned(
          left: 34,
          top: 150,
          width: 235,
          child: _LobbyGoalCard(
            title: '本周目标',
            body: '收集 6 名英雄，通关星砂回廊第 3 层。',
            progressLabel: '进度 ${_model.ownedCount}/${_model.heroes.length}',
            progress: _model.ownedCount / _model.heroes.length,
          ),
        ),
        Positioned(
          left: 32,
          bottom: _navHeight + 16,
          width: 248,
          child: _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '今日委托 · 星砂试炼',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  '完成一场战斗，获得召唤资源和英雄碎片。',
                  style: TextStyle(fontSize: 11, color: _ArenaColors.muted),
                ),
                const SizedBox(height: 10),
                _darkButton('前往战斗', _model.startBattle),
              ],
            ),
          ),
        ),
        Positioned(
          right: 26,
          top: 96,
          width: 182,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _LobbyPrimaryAction(
                title: '澜星 UP',
                subtitle: '十连召唤 · 至少 SR',
                onTap: () => _model.navigate(ArenaView.summon),
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _LobbyMiniAction(
                      icon: Icons.home_rounded,
                      label: '小家',
                      onTap: () => _model.navigate(ArenaView.home),
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceXs),
                  Expanded(
                    child: _LobbyMiniAction(
                      icon: Icons.auto_awesome_rounded,
                      label: '${_model.ownedCount}/${_model.heroes.length}',
                      onTap: () => _model.navigate(ArenaView.collection),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              _LobbyResourceLine(
                crystals: _model.starCrystals,
                floor: _model.towerFloor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHome() {
    final hero = _model.activeHero;
    final bond = _model.bondOf(hero);
    final restLabel = _model.restBuffReady
        ? '已就绪 · 下场生命 +${ArenaViewModel.homeRestHpBonus}'
        : '训练后解锁 · 下场生命 +${ArenaViewModel.homeRestHpBonus}';
    final bondLabel = _model.bondBuffReady
        ? '已就绪 · 下场能量 +${ArenaViewModel.homeBondEnergyBonus}'
        : '送礼后解锁 · 下场能量 +${ArenaViewModel.homeBondEnergyBonus}';
    final skin = _model.skinOf(hero);
    return _panelScaffold(
      title: '星辉小家',
      subtitle: '送礼与训练服务战斗；皮肤在角色页整卡切换。',
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: _HeroPortrait(
              hero: hero,
              showFrame: true,
              imageAsset: _model.portraitAssetOf(hero),
              tint: _model.portraitTintOf(hero),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '今日陪伴',
                                style: TextStyle(
                                  color: _ArenaColors.violet,
                                  fontSize: MoeTokens.textSm,
                                  fontWeight: MoeTokens.fontWeightTitle,
                                ),
                              ),
                              const SizedBox(height: MoeTokens.spaceXs),
                              Expanded(
                                child: Text(
                                  _model.homeMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ArenaColors.muted,
                                    fontSize: MoeTokens.textSm,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              _homeMetric('好感度', bond, hero.color),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: MoeTokens.spaceMd),
                      Expanded(
                        child: _SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '远征加成',
                                style: TextStyle(
                                  color: _ArenaColors.violet,
                                  fontSize: MoeTokens.textSm,
                                  fontWeight: MoeTokens.fontWeightTitle,
                                ),
                              ),
                              const SizedBox(height: MoeTokens.spaceXs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _homeBuff(
                                      '休息充分',
                                      restLabel,
                                    ),
                                    _homeBuff(
                                      '羁绊整理',
                                      bondLabel,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _SurfaceCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '当前皮肤',
                              style: TextStyle(
                                color: _ArenaColors.violet,
                                fontSize: MoeTokens.textSm,
                                fontWeight: MoeTokens.fontWeightTitle,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${hero.name} · ${skin.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: MoeTokens.textSm,
                              ),
                            ),
                            const Text(
                              '整卡替换立绘，不是部位换装',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ArenaColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MoePressable(
                        onTap: () => _model.navigate(ArenaView.character),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusMd),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _ArenaColors.violet,
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radiusMd),
                          ),
                          child: const Text(
                            '更换皮肤',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: _HomeActionCard(
                          icon: Icons.volunteer_activism_rounded,
                          title: '送礼 · ${ArenaViewModel.homeGiftCost}',
                          body:
                              '消耗星晶提升好感，下场战斗初始能量 +${ArenaViewModel.homeBondEnergyBonus}。',
                          onTap: () => unawaited(_onHomeGift()),
                        ),
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      Expanded(
                        child: _HomeActionCard(
                          icon: Icons.auto_fix_high_rounded,
                          title: '训练',
                          body:
                              '完成出征前整理，下场战斗初始生命 +${ArenaViewModel.homeRestHpBonus}。',
                          onTap: () => unawaited(_onHomeTrain()),
                        ),
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      Expanded(
                        child: _HomeActionCard(
                          icon: Icons.explore_rounded,
                          title: '出发',
                          body: '从小家进入爬塔副本，形成养成到战斗的闭环。',
                          onTap: () => _model.navigate(ArenaView.tower),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormation() {
    return _panelScaffold(
      title: '编队',
      subtitle: '点选阵位后，从下方已拥有英雄中替换。站位决定承伤顺序。',
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_ArenaColors.violet, _ArenaColors.violetLight],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _ArenaColors.gold),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4430263C),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _FormationLanePainter()),
                        ),
                        Center(
                          child: Wrap(
                            spacing: 28,
                            children: List.generate(3, (index) {
                              final slotHero = _model.formationHeroAt(index);
                              return MoePressable(
                                onTap: () => _model.selectFormationSlot(index),
                                borderRadius: BorderRadius.circular(16),
                                child: _FormationSlot(
                                  hero: slotHero,
                                  selected:
                                      index == _model.selectedFormationSlot,
                                  positionLabel: ['前排', '中排', '后排'][index],
                                  imageAsset: slotHero == null
                                      ? null
                                      : _model.portraitAssetOf(slotHero),
                                  tint: slotHero == null
                                      ? null
                                      : _model.portraitTintOf(slotHero),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: MoeTokens.spaceMd),
                SizedBox(
                  width: 160,
                  child: _SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '阵容思路',
                          style: TextStyle(
                            color: _ArenaColors.violet,
                            fontSize: MoeTokens.textSm,
                            fontWeight: MoeTokens.fontWeightTitle,
                          ),
                        ),
                        const SizedBox(height: MoeTokens.spaceSm),
                        Text(
                          '正在编辑：${[
                            '前排',
                            '中排',
                            '后排'
                          ][_model.selectedFormationSlot]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: MoeTokens.textXs,
                            fontWeight: MoeTokens.fontWeightSubtitle,
                          ),
                        ),
                        const SizedBox(height: MoeTokens.spaceXs),
                        Text(
                          '前排承伤 / 中排连携 / 后排输出。下方点选已拥有英雄即可替换；已在队伍中的英雄会交换阵位。',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ArenaColors.muted,
                            fontSize: MoeTokens.textXs,
                            height: 1.25,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '队伍战力 ${_model.teamPower}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ArenaColors.violet,
                                  fontSize: MoeTokens.textSm,
                                  fontWeight: MoeTokens.fontWeightTitle,
                                ),
                              ),
                            ),
                            if (_formationSaved)
                              const Text(
                                '已保存',
                                style: TextStyle(
                                  color: _ArenaColors.gold,
                                  fontSize: MoeTokens.textXs,
                                  fontWeight: MoeTokens.fontWeightTitle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '候选英雄',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _goldButton('保存', _saveFormation),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _model.heroes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final hero = _model.heroes[index];
                return _HeroCard(
                  hero: hero,
                  owned: _model.isOwned(hero),
                  selected: index == _model.selectedHero,
                  inFormation: _model.formationHeroes
                      .any((formationHero) => formationHero.id == hero.id),
                  stars: _model.starsOf(hero),
                  imageAsset: _model.portraitAssetOf(hero),
                  tint: _model.portraitTintOf(hero),
                  onTap: () {
                    setState(() => _formationSaved = false);
                    _model.selectHero(index);
                    _model.assignHeroToFormation(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTower() {
    return _panelScaffold(
      title: '爬塔 · 星砂回廊',
      subtitle: '选择路线，带着当前构筑登上更高层。',
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_ArenaColors.violetLight, _ArenaColors.violet],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _ArenaColors.gold),
              ),
              child: CustomPaint(painter: _TowerPathPainter()),
            ),
          ),
          Positioned(
            left: 18,
            top: 14,
            right: 18,
            child: Row(
              children: [
                _TowerStatusChip(
                  icon: Icons.layers_rounded,
                  label: '当前层',
                  value: '${_model.towerFloor}',
                ),
                const SizedBox(width: MoeTokens.spaceSm),
                _TowerStatusChip(
                  icon: Icons.account_tree_rounded,
                  label: '路线分支',
                  value: '战斗 / 事件 / 补给',
                ),
                const Spacer(),
                _TowerStatusChip(
                  icon: Icons.bolt_rounded,
                  label: '队伍战力',
                  value: '${_model.teamPower}',
                ),
              ],
            ),
          ),
          _towerNode(
            index: 0,
            left: .16,
            top: .66,
            icon: Icons.local_fire_department_rounded,
          ),
          _towerNode(
            index: 1,
            left: .35,
            top: .40,
            icon: Icons.local_cafe_rounded,
          ),
          _towerNode(
            index: 2,
            left: .52,
            top: .64,
            icon: Icons.auto_awesome_rounded,
          ),
          _towerNode(
            index: 3,
            left: .64,
            top: .34,
            icon: Icons.storefront_rounded,
          ),
          _towerNode(
            index: 4,
            left: .82,
            top: .50,
            icon: Icons.workspace_premium_rounded,
          ),
          Positioned(
            left: 18,
            bottom: 14,
            child: _SurfaceCard(
              width: 246,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_model.selectedTowerNode.label} · ${_model.selectedTowerNode.kind}',
                    style: const TextStyle(
                      color: _ArenaColors.violet,
                      fontSize: MoeTokens.textSm,
                      fontWeight: MoeTokens.fontWeightTitle,
                    ),
                  ),
                  const SizedBox(height: MoeTokens.spaceXs),
                  Text(
                    _model.selectedTowerNode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            right: 18,
            width: 112,
            child: _goldButton('开始冒险', _model.startBattle),
          ),
        ],
      ),
    );
  }

  Widget _buildSummon() {
    final upHero = _model.heroes.first;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _uiPulse,
            builder: (context, _) =>
                _SummonBackground(progress: _uiPulse.value),
          ),
        ),
        Positioned(
          left: 28,
          top: 22,
          child: _resource('✧', '${_model.starCrystals}'),
        ),
        _closeButton(),
        Positioned(
          left: 34,
          top: 88,
          width: 280,
          child: _TitleBlock(
            title: '星辉召唤',
            subtitle: '本期 UP：${upHero.name} · ${upHero.title}',
          ),
        ),
        Positioned(
          left: 34,
          top: 172,
          width: 254,
          height: 124,
          child: AnimatedBuilder(
            animation: _uiPulse,
            builder: (context, _) => _SummonHeroReel(
              heroes: _model.heroes,
              progress: _uiPulse.value,
              onPreviewTap: _openSummonPool,
            ),
          ),
        ),
        Positioned(
          left: 318,
          top: 44,
          width: 205,
          height: 245,
          child: _HeroPortrait(
            hero: upHero,
            showFrame: true,
            imageAsset: _model.portraitAssetOf(upHero),
            tint: _model.portraitTintOf(upHero),
          ),
        ),
        Positioned(
          right: 28,
          top: 98,
          width: 226,
          height: 134,
          child: _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('召唤规则',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  _model.summonMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: _ArenaColors.muted,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _rateChip('SSR 8%'),
                    _rateChip('SR 30%'),
                    _rateChip('R 62%'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 248,
          right: 28,
          bottom: _navHeight + 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _ghostButton(
                  '单抽 · ${ArenaViewModel.singleSummonCost}',
                  () => _model.summon(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _goldButton(
                  '十连 · ${ArenaViewModel.tenSummonCost}',
                  () => _model.summon(10),
                ),
              ),
            ],
          ),
        ),
        if (_model.summonResults.isNotEmpty) _buildSummonResults(),
        if (_showSummonPool) _buildSummonPoolOverlay(),
      ],
    );
  }

  Widget _buildSummonPoolOverlay() {
    return Positioned.fill(
      child: Container(
        color: _ArenaColors.ink.withValues(alpha: .62),
        child: Center(
          child: SizedBox(
            width: 590,
            height: 330,
            child: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '当前召唤池',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _ArenaColors.violet,
                        ),
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      _rateChip('UP ${_model.heroes.first.name}'),
                      const Spacer(),
                      _iconButton('×', _closeSummonPool),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '点击角色可切换查看详情，未拥有角色会以剪影方式展示。',
                    style: TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: MoeTokens.textXs,
                    ),
                  ),
                  const SizedBox(height: MoeTokens.spaceSm),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _model.heroes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.55,
                      ),
                      itemBuilder: (context, index) {
                        final hero = _model.heroes[index];
                        return _SummonPoolHeroCard(
                          hero: hero,
                          owned: _model.isOwned(hero),
                          selected: index == _model.selectedHero,
                          up: index == 0,
                          onTap: () => _model.selectHero(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummonResults() {
    return Positioned.fill(
      child: Container(
        color: _ArenaColors.ink.withValues(alpha: .58),
        child: Center(
          child: SizedBox(
            width: 562,
            height: 340,
            child: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '召唤结果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      _iconButton('×', _model.closeSummonResults),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _model.summonResults.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 7,
                        crossAxisSpacing: 7,
                        childAspectRatio: .95,
                      ),
                      itemBuilder: (context, index) => _SummonResultCard(
                        result: _model.summonResults[index],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _goldButton('确认', _model.closeSummonResults),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollection() {
    return _panelScaffold(
      title: '英雄图鉴',
      subtitle: '总览所有英雄，点选卡片进入养成详情。后续可扩展筛选、阵营和职业分类。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '已收集 ${_model.ownedCount} / ${_model.heroes.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 12),
              _chip('星晶 ${_model.starCrystals}'),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _model.ownedCount / _model.heroes.length,
                    minHeight: 7,
                    color: _ArenaColors.gold,
                    backgroundColor: const Color(0xFFE9DCC3),
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: _compactGhostButton(
                  '去召唤',
                  () => _model.navigate(ArenaView.summon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _SurfaceCard(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: _model.heroes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.34,
                ),
                itemBuilder: (context, index) {
                  final hero = _model.heroes[index];
                  return _HeroCollectionCard(
                    hero: hero,
                    owned: _model.isOwned(hero),
                    selected: index == _model.selectedHero,
                    shards: _model.shardsOf(hero),
                    stars: _model.starsOf(hero),
                    power: _model.powerOf(hero),
                    inFormation: _model.formationHeroes
                        .any((formationHero) => formationHero.id == hero.id),
                    imageAsset: _model.portraitAssetOf(hero),
                    tint: _model.portraitTintOf(hero),
                    onTap: () {
                      _model.selectHero(index);
                      _model.navigate(ArenaView.character);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacter() {
    final hero = _model.activeHero;
    final owned = _model.isOwned(hero);
    return Stack(
      children: [
        const Positioned.fill(child: _CharacterBackground()),
        _closeButton(),
        Positioned(
          left: 54,
          top: 62,
          bottom: _navHeight + 14,
          width: 265,
          child: _HeroPortrait(
            hero: hero,
            locked: !owned,
            showFrame: true,
            imageAsset: _model.portraitAssetOf(hero),
            tint: _model.portraitTintOf(hero),
          ),
        ),
        Positioned(
          right: 34,
          top: 62,
          bottom: _navHeight + 14,
          width: 388,
          child: _SurfaceCard(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${hero.name} · ${hero.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _rarityPill(hero.rarity.label),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${hero.faction}阵营 · ${hero.role} · ${owned ? '已拥有' : '未拥有'}',
                    style: const TextStyle(
                      color: _ArenaColors.violet,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBox('等级', owned ? '${_model.levelOf(hero)}' : '--'),
                      _StatBox('好感度', owned ? '${_model.bondOf(hero)}' : '--'),
                      _StatBox('战力', owned ? '${_model.powerOf(hero)}' : '--'),
                    ],
                  ),
                  const Divider(height: 22),
                  const Text(
                    '皮肤',
                    style: TextStyle(
                      color: _ArenaColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '整卡替换角色立绘（类似皮肤），不是帽衣裤鞋部位。',
                    style: TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: hero.resolvedSkins.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final skin = hero.resolvedSkins[index];
                        final selected = _model.skinOf(hero).id == skin.id;
                        return MoePressable(
                          onTap: !owned
                              ? null
                              : () => unawaited(
                                    _model.selectHeroSkin(hero, skin.id),
                                  ),
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusMd),
                          child: Container(
                            width: 108,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _ArenaColors.violet.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.7),
                              borderRadius:
                                  BorderRadius.circular(MoeTokens.radiusMd),
                              border: Border.all(
                                color: selected
                                    ? _ArenaColors.violet
                                    : _ArenaColors.gold.withValues(alpha: 0.5),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: skin.imageAsset == null
                                        ? ColoredBox(color: Color(hero.color))
                                        : (skin.tint == null
                                            ? Image.asset(
                                                skin.imageAsset!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                            : ColorFiltered(
                                                colorFilter: ColorFilter.mode(
                                                  Color(skin.tint!),
                                                  BlendMode.modulate,
                                                ),
                                                child: Image.asset(
                                                  skin.imageAsset!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
                                              )),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skin.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? _ArenaColors.violet
                                        : _ArenaColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 22),
                  Text(
                    '✦  ${hero.skillName}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hero.skillDescription,
                    style: const TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CharacterProgressCard(
                    hero: hero,
                    owned: owned,
                    shards: _model.shardsOf(hero),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '养成路线',
                    style: TextStyle(
                      color: _ArenaColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _CultivationRow(
                    icon: Icons.auto_awesome_rounded,
                    title: '技能升级',
                    body: owned ? '消耗碎片提高卡牌倍率' : '解锁后开放',
                    ready: owned,
                  ),
                  const SizedBox(height: 6),
                  _CultivationRow(
                    icon: Icons.workspace_premium_rounded,
                    title: '装备槽位',
                    body: owned ? '武器 / 饰品 / 圣印提供战力' : '召唤获得后开放',
                    ready: owned,
                  ),
                  const SizedBox(height: 6),
                  _CultivationRow(
                    icon: Icons.sync_alt_rounded,
                    title: '资源转化',
                    body: '星晶抽卡，重复角色转碎片，碎片用于升星。',
                    ready: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      _EquipmentSlot('武器'),
                      _EquipmentSlot('饰品'),
                      _EquipmentSlot('圣印'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _goldButton(
                    owned ? '培养角色' : '前往召唤',
                    owned ? () {} : () => _model.navigate(ArenaView.summon),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBattle() {
    return Stack(
      children: [
        GameWidget(game: _game),
        ..._buildBattleUnits(),
        if (_model.combo > 0 && _model.lastPlayedCardIndex >= 0)
          Positioned(
            left: 260,
            right: 260,
            top: 214,
            child: _BattleComboBurst(
              combo: _model.combo,
              card: _model.cards[_model.lastPlayedCardIndex],
            ),
          ),
        Positioned(
          top: 12,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _battleBadge('我方战力', '${_model.teamPower}'),
              const SizedBox(width: 10),
              _battleBadge('能量', '${_model.energy} / 10'),
              const SizedBox(width: 10),
              _battleBadge('敌方战力', '16,240'),
            ],
          ),
        ),
        Positioned(
          left: 18,
          top: 56,
          width: 184,
          child: _HealthPanel(
            label: '我方生命',
            value: _model.playerHp,
            color: const Color(0xFF79B9B0),
          ),
        ),
        Positioned(
          right: 18,
          top: 56,
          width: 184,
          child: _HealthPanel(
            label: '敌方生命',
            value: _model.enemyHp,
            color: const Color(0xFFD47E9B),
          ),
        ),
        Positioned(
          top: 104,
          left: 220,
          right: 220,
          child: _BattleLogRibbon(
            hero: _model.activeHero,
            turn: _model.turn,
            combo: _model.combo,
            objective: _model.battleObjective,
            enemyIntent: _model.enemyIntent,
            message: _model.battleMessage,
            finished: _model.finished,
            won: _model.won,
          ),
        ),
        if (_model.hasPendingReward)
          Positioned(
            left: 190,
            right: 190,
            bottom: 14,
            child: _BattleRewardPanel(
              choices: _model.rewardChoices,
              onChoose: _model.chooseRewardCard,
            ),
          )
        else
          Positioned(
            left: 92,
            right: 182,
            bottom: 8,
            child: AnimatedBuilder(
              animation: _uiPulse,
              builder: (context, _) => _BattleHandStack(
                cards: _model.cards,
                energy: _model.energy,
                finished: _model.finished,
                lastPlayedCardIndex: _model.lastPlayedCardIndex,
                pulse: _uiPulse.value,
                onPlay: _model.playCard,
              ),
            ),
          ),
        Positioned(
          right: 28,
          bottom: 26,
          width: 136,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_model.hasPendingReward)
                _ghostButton('跳过奖励', _model.skipReward)
              else if (_model.finished) ...[
                _goldButton(
                  _model.won ? '下一层' : '重新挑战',
                  _model.startBattle,
                ),
              ] else
                _darkButton('结束回合', _model.endTurn),
              if (_model.finished &&
                  !_model.hasPendingReward &&
                  !_model.won) ...[
                const SizedBox(height: 8),
                _goldButton(
                  '调整编队',
                  () => _model.navigate(ArenaView.formation),
                ),
              ],
              if (_model.finished &&
                  !_model.hasPendingReward &&
                  _model.won) ...[
                const SizedBox(height: 8),
                _ghostButton(
                  '回到爬塔',
                  () => _model.navigate(ArenaView.tower),
                ),
              ],
            ],
          ),
        ),
        _closeButton(),
      ],
    );
  }

  List<Widget> _buildBattleUnits() {
    final team = _model.formationHeroes;
    const friendlyPositions = [
      Alignment(-.68, .05),
      Alignment(-.50, -.10),
      Alignment(-.34, .05),
    ];
    const enemyPositions = [
      Alignment(.34, .05),
      Alignment(.50, -.10),
      Alignment(.68, .05),
    ];

    return [
      for (var index = 0; index < friendlyPositions.length; index++)
        Align(
          alignment: friendlyPositions[index],
          child: SizedBox(
            width: 82,
            height: 128,
            child: _BattleUnit(
              hero: index < team.length ? team[index] : null,
              label: index < team.length ? team[index].name : '空位',
              active: index == 0 && !_model.finished,
              hp: _model.playerHp,
              imageAsset: index < team.length
                  ? _model.portraitAssetOf(team[index])
                  : null,
              tint: index < team.length
                  ? _model.portraitTintOf(team[index])
                  : null,
            ),
          ),
        ),
      for (var index = 0; index < enemyPositions.length; index++)
        Align(
          alignment: enemyPositions[index],
          child: SizedBox(
            width: 82,
            height: 128,
            child: _BattleUnit(
              label: '敌影 ${index + 1}',
              intentLabel:
                  index == _model.selectedEnemyIndex && !_model.finished
                      ? '意图 -10'
                      : null,
              enemy: true,
              active: index == _model.selectedEnemyIndex && !_model.finished,
              selected: index == _model.selectedEnemyIndex && !_model.finished,
              hp: _model.enemyHpAt(index),
              onTap: () => _model.selectEnemy(index),
            ),
          ),
        ),
    ];
  }

  Widget _panelScaffold({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.space2xl,
        MoeTokens.space2xl,
        MoeTokens.space2xl,
        _navHeight + _navGap + 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ArenaColors.cream, Color(0xFFD4C6E8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ArenaColors.violet,
                  ),
                ),
              ),
              SizedBox(
                width: 74,
                height: 30,
                child: _compactGhostButton(
                  '返回大厅',
                  () => _model.navigate(ArenaView.lobby),
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: _ArenaColors.muted),
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _topBar(String brand) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: _ArenaColors.ink.withValues(alpha: .70),
          child: Row(
            children: [
              Text(
                brand,
                style: const TextStyle(
                  fontFamily: 'Cinzel',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _resource('◇', '1,280'),
              const SizedBox(width: 8),
              _resource('✧', '${_model.starCrystals}'),
              const SizedBox(width: 8),
              _resource('☼', '12 / 20'),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                height: 30,
                child: _compactGhostButton('退出游戏', _exitGame),
              ),
            ],
          ),
        ),
      );

  void _exitGame() {
    Navigator.of(context).maybePop();
  }

  Widget _buildNavigation() => Positioned(
        bottom: 8,
        left: 92,
        right: 92,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          child: Container(
            height: _navHeight,
            decoration: BoxDecoration(
              color: _ArenaColors.ink.withValues(alpha: .92),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x5530263C),
                  blurRadius: 16,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navButton(Icons.grid_view_rounded, '编队', ArenaView.formation),
                _navButton(Icons.home_rounded, '小家', ArenaView.home),
                _navButton(
                    Icons.auto_awesome_rounded, '图鉴', ArenaView.collection),
                _navButton(
                    Icons.generating_tokens_rounded, '召唤', ArenaView.summon),
                _navButton(Icons.account_tree_rounded, '爬塔', ArenaView.tower),
                _navButton(
                    Icons.sports_martial_arts_rounded, '战斗', ArenaView.battle),
              ],
            ),
          ),
        ),
      );

  Widget _navButton(IconData icon, String label, ArenaView view) {
    final selected = _model.view == view;
    return SizedBox(
      width: 76,
      child: MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (view == ArenaView.battle) {
            _model.startBattle();
          } else {
            _model.navigate(view);
          }
        },
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: selected ? 23 : 21,
                color: selected ? _ArenaColors.goldLight : Colors.white70,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _ArenaColors.goldLight : Colors.white70,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resource(String icon, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _ArenaColors.gold.withValues(alpha: .55)),
        ),
        child: Text(
          '$icon  $value',
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      );

  Widget _battleBadge(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .90),
          border: Border.all(color: _ArenaColors.gold),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label  $value',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: _ArenaColors.violet,
          ),
        ),
      );

  Widget _iconButton(String label, VoidCallback onPressed) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ArenaColors.cream.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _ArenaColors.violet,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

  Widget _closeButton() => Positioned(
        top: 14,
        right: 18,
        width: 74,
        height: 30,
        child: _compactGhostButton(
          '返回大厅',
          () => _model.navigate(ArenaView.lobby),
        ),
      );

  Widget _goldButton(String label, VoidCallback onPressed) => _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.ink,
        decoration: BoxDecoration(
          color: _ArenaColors.gold,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3330263C),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
      );

  Widget _darkButton(String label, VoidCallback onPressed) => _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: Colors.white,
        decoration: BoxDecoration(
          color: _ArenaColors.violet,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3330263C),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
      );

  Widget _ghostButton(String label, VoidCallback onPressed) => _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.violet,
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .9),
          border: Border.all(color: _ArenaColors.gold),
          borderRadius: BorderRadius.circular(10),
        ),
      );

  Widget _compactGhostButton(String label, VoidCallback onPressed) =>
      _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.violet,
        fontSize: 10,
        minHeight: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .9),
          border: Border.all(color: _ArenaColors.gold),
          borderRadius: BorderRadius.circular(9),
        ),
      );

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _ArenaColors.violet.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _rarityPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _ArenaColors.goldLight,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _ArenaColors.gold),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _rateChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _ArenaColors.goldLight.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _ArenaColors.gold.withValues(alpha: .68)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _homeMetric(String label, int value, int color) {
    final progress = (value / 100).clamp(0.0, 1.0);
    final accent = Color(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _ArenaColors.violet,
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightSubtitle,
              ),
            ),
            const Spacer(),
            Text(
              '$value / 100',
              style: TextStyle(
                color: accent,
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: MoeTokens.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: _ArenaColors.violet.withValues(alpha: .12),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }

  Widget _homeBuff(String title, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ArenaColors.goldLight.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              border: Border.all(color: _ArenaColors.gold),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 12,
              color: _ArenaColors.violet,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.ink,
                    fontSize: MoeTokens.textXs,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.muted,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _towerNode({
    required int index,
    required double left,
    required double top,
    required IconData icon,
  }) {
    final active = index == _model.selectedTowerNodeIndex;
    final cleared = index < _model.selectedTowerNodeIndex;
    return Align(
      alignment: Alignment(left * 2 - 1, top * 2 - 1),
      child: MoePressable(
        onTap: () => _model.selectTowerNode(index),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: SizedBox(
          width: 74,
          height: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 58 : 50,
                height: active ? 58 : 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? const Color(0xFFFFF0B8)
                      : cleared
                          ? _ArenaColors.ink.withValues(alpha: .46)
                          : _ArenaColors.cream,
                  border: Border.all(
                    color: active
                        ? _ArenaColors.goldLight
                        : cleared
                            ? Colors.white38
                            : _ArenaColors.gold,
                    width: active ? 4 : 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55302B42),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  cleared ? Icons.check_rounded : icon,
                  color: cleared ? _ArenaColors.goldLight : _ArenaColors.ink,
                  size: active ? 26 : 22,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceXs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MoeTokens.spaceSm,
                  vertical: MoeTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? _ArenaColors.goldLight
                      : cleared
                          ? _ArenaColors.ink.withValues(alpha: .56)
                          : _ArenaColors.cream.withValues(alpha: .86),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Text(
                  _model.towerNodeAt(index).label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cleared ? Colors.white : _ArenaColors.violet,
                    fontSize: MoeTokens.textXs,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TowerStatusChip extends StatelessWidget {
  const _TowerStatusChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _ArenaColors.ink.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border:
              Border.all(color: _ArenaColors.goldLight.withValues(alpha: .34)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _ArenaColors.goldLight),
            const SizedBox(width: 5),
            Text(
              '$label  $value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightTitle,
              ),
            ),
          ],
        ),
      );
}

class _ArenaTextButton extends StatelessWidget {
  const _ArenaTextButton({
    required this.label,
    required this.onPressed,
    required this.textColor,
    required this.decoration,
    this.fontSize = 11,
    this.minHeight = 34,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  final String label;
  final VoidCallback onPressed;
  final Color textColor;
  final Decoration decoration;
  final double fontSize;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          padding: padding,
          decoration: decoration,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _ArenaColors {
  static const ink = Color(0xFF30263C);
  static const violet = Color(0xFF614682);
  static const violetLight = Color(0xFF9B7FC0);
  static const cream = Color(0xFFFFF8E9);
  static const gold = Color(0xFFD9A94F);
  static const goldLight = Color(0xFFFFE39B);
  static const muted = Color(0xFF806B83);
}

Color _rarityAccent(ArenaRarity rarity) {
  switch (rarity) {
    case ArenaRarity.ssr:
      return _ArenaColors.gold;
    case ArenaRarity.sr:
      return const Color(0xFF9B7FC0);
    case ArenaRarity.r:
      return const Color(0xFF7EB4D8);
  }
}

Color _raritySurface(ArenaRarity rarity) => Color.alphaBlend(
    _rarityAccent(rarity).withValues(alpha: .16), Colors.white);

IconData _roleIcon(String role) {
  switch (role) {
    case '剑士':
      return Icons.auto_fix_high_rounded;
    case '法师':
      return Icons.flare_rounded;
    case '射手':
      return Icons.gps_fixed_rounded;
    case '辅助':
      return Icons.volunteer_activism_rounded;
    case '守卫':
      return Icons.shield_rounded;
    default:
      return Icons.stars_rounded;
  }
}

class _LobbyBackground extends StatelessWidget {
  const _LobbyBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF73528A),
              Color(0xFFE4B7AD),
              Color(0xFF526D9B),
            ],
          ),
        ),
        child: SizedBox.expand(child: CustomPaint(painter: _WindowPainter())),
      );
}

class _SummonBackground extends StatelessWidget {
  const _SummonBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.2),
            radius: .95,
            colors: [
              Color(0xFFFFF6CE),
              Color(0xFF72BCD4),
              Color(0xFF73528A),
              Color(0xFF3D2E55),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _SummonBackgroundPainter(progress),
          child: const SizedBox.expand(),
        ),
      );
}

class _SummonBackgroundPainter extends CustomPainter {
  const _SummonBackgroundPainter(this.progress);

  final double progress;

  static const _stars = <Offset>[
    Offset(.08, .16),
    Offset(.16, .36),
    Offset(.24, .12),
    Offset(.34, .28),
    Offset(.44, .10),
    Offset(.58, .18),
    Offset(.68, .08),
    Offset(.78, .32),
    Offset(.90, .14),
    Offset(.12, .68),
    Offset(.30, .76),
    Offset(.46, .64),
    Offset(.62, .78),
    Offset(.84, .70),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .53, size.height * .46);
    final phase = progress * math.pi * 2;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _ArenaColors.goldLight.withValues(alpha: .42),
          _ArenaColors.violetLight.withValues(alpha: .18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 170));
    canvas.drawCircle(center, 170, glowPaint);

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _stars.length; i++) {
      final anchor = _stars[i];
      final drift = math.sin(phase + i) * 6;
      final opacity = .38 + math.sin(phase * 1.5 + i * .7) * .22;
      starPaint.color = Colors.white.withValues(alpha: opacity.clamp(.18, .70));
      canvas.drawCircle(
        Offset(anchor.dx * size.width + drift, anchor.dy * size.height),
        i.isEven ? 1.8 : 1.2,
        starPaint,
      );
    }

    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: .0),
          _ArenaColors.goldLight.withValues(alpha: .72),
          Colors.white.withValues(alpha: .0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.18 + i * .20) + math.sin(phase + i) * 10;
      final x = (progress * size.width * 1.35 + i * 210) % (size.width + 220);
      canvas.drawLine(
        Offset(x - 190, y + 34),
        Offset(x, y),
        trailPaint,
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * .18);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ArenaColors.goldLight.withValues(alpha: .82);
    for (var i = 0; i < 3; i++) {
      final radius = 62 + i * 25 + math.sin(phase + i) * 3;
      canvas.drawCircle(Offset.zero, radius, ringPaint);
    }
    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: .62);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      canvas.drawLine(const Offset(0, -44), const Offset(0, -115), runePaint);
      canvas.drawCircle(const Offset(0, -126), 4, runePaint);
    }
    canvas.restore();

    final floorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .14);
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .52, size.height * (.78 + i * .035)),
          width: size.width * (.48 + i * .10),
          height: 24 + i * 8,
        ),
        floorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SummonBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SummonHeroReel extends StatelessWidget {
  const _SummonHeroReel({
    required this.heroes,
    required this.progress,
    required this.onPreviewTap,
  });

  final List<ArenaHero> heroes;
  final double progress;
  final VoidCallback onPreviewTap;

  static const double _cardWidth = 54;
  static const double _cardGap = 8;

  @override
  Widget build(BuildContext context) {
    if (heroes.isEmpty) return const SizedBox.shrink();
    final loopWidth = heroes.length * (_cardWidth + _cardGap);
    final offset = -progress * loopWidth;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ArenaColors.ink.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border:
            Border.all(color: _ArenaColors.goldLight.withValues(alpha: .42)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3330263C),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_motion_rounded,
                color: _ArenaColors.goldLight,
                size: 14,
              ),
              const SizedBox(width: 5),
              const Text(
                '星轨巡礼',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              MoePressable(
                onTap: onPreviewTap,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ArenaColors.goldLight.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    border: Border.all(
                      color: _ArenaColors.goldLight.withValues(alpha: .42),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '卡池预览',
                        style: TextStyle(
                          color: Color(0xFFFFF0C2),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFFFFF0C2),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SummonReelLightPainter(progress),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(offset, 0),
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: loopWidth * 2,
                      maxWidth: loopWidth * 2,
                      child: Row(
                        children: [
                          for (final hero in [...heroes, ...heroes])
                            Padding(
                              padding: const EdgeInsets.only(right: _cardGap),
                              child: _SummonReelCard(
                                hero: hero,
                                width: _cardWidth,
                              ),
                            ),
                        ],
                      ),
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

class _SummonReelCard extends StatelessWidget {
  const _SummonReelCard({
    required this.hero,
    required this.width,
  });

  final ArenaHero hero;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(hero.rarity);
    final imageAsset = hero.imageAsset;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent,
              accent.withValues(alpha: .42),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageAsset == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(hero.color).withValues(alpha: .90),
                        _ArenaColors.ink,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _roleIcon(hero.role),
                      color: _ArenaColors.goldLight,
                      size: 22,
                    ),
                  ),
                )
              else
                Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _ArenaColors.ink.withValues(alpha: .84),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Text(
                  hero.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(color: _ArenaColors.ink, blurRadius: 4),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _RarityMark(hero.rarity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummonPoolHeroCard extends StatelessWidget {
  const _SummonPoolHeroCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.up,
    required this.onTap,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final bool up;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              up ? _ArenaColors.goldLight : accent.withValues(alpha: .82),
              accent.withValues(alpha: owned ? .34 : .20),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: .72),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected || up
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: .34),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: owned
                ? _ArenaColors.cream.withValues(alpha: .96)
                : _ArenaColors.ink.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              _AvatarCircle(hero: hero, locked: !owned),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            up ? '${hero.name} · 本期UP' : hero.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: owned ? _ArenaColors.ink : Colors.white,
                              fontSize: MoeTokens.textXs,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _RarityMark(hero.rarity),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _HeroMetaChip(
                          icon: _roleIcon(hero.role),
                          label: hero.role,
                          color: accent,
                        ),
                        _HeroMetaChip(
                          icon: Icons.flag_rounded,
                          label: hero.faction,
                          color: owned ? _ArenaColors.violet : Colors.white70,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummonReelLightPainter extends CustomPainter {
  const _SummonReelLightPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = (size.width + 80) * progress - 40;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: .0),
          _ArenaColors.goldLight.withValues(alpha: .24),
          Colors.white.withValues(alpha: .0),
        ],
      ).createShader(Rect.fromLTWH(sweepX - 34, 0, 68, size.height));
    final path = Path()
      ..moveTo(sweepX - 28, size.height)
      ..lineTo(sweepX + 2, 0)
      ..lineTo(sweepX + 34, 0)
      ..lineTo(sweepX + 4, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SummonReelLightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CharacterBackground extends StatelessWidget {
  const _CharacterBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFC4DFF1),
              Color(0xFFFFF1D0),
              Color(0xFFC2AAD1),
            ],
          ),
        ),
        child: SizedBox.expand(),
      );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: _ArenaColors.violet,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFFFF1D1), fontSize: 11),
          ),
        ],
      );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(MoeTokens.spaceMd),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .95),
          border: Border.all(color: const Color(0xFFE6C67E)),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332E2440),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.all(MoeTokens.spaceSm),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8E9),
                Color(0xFFFFEFC4),
              ],
            ),
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2430263C),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ArenaColors.violet.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: Icon(
                      icon,
                      color: _ArenaColors.violet,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.ink,
                        fontSize: MoeTokens.textSm,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyPrimaryAction extends StatelessWidget {
  const _LobbyPrimaryAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MoeTokens.spaceMd),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_ArenaColors.goldLight, _ArenaColors.gold],
            ),
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            border: Border.all(color: Colors.white.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFE39B),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: const Icon(
                  Icons.generating_tokens_rounded,
                  color: _ArenaColors.violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.ink,
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: MoeTokens.textXs,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyMiniAction extends StatelessWidget {
  const _LobbyMiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _ArenaColors.cream.withValues(alpha: .90),
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _ArenaColors.violet, size: 18),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.violet,
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyResourceLine extends StatelessWidget {
  const _LobbyResourceLine({
    required this.crystals,
    required this.floor,
  });

  final int crystals;
  final int floor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _ArenaColors.ink.withValues(alpha: .40),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border:
              Border.all(color: _ArenaColors.goldLight.withValues(alpha: .28)),
        ),
        child: Text(
          '星晶 $crystals  ·  爬塔第 $floor 层',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: MoeTokens.textXs,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _LobbyGoalCard extends StatelessWidget {
  const _LobbyGoalCard({
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.progress,
  });

  final String title;
  final String body;
  final String progressLabel;
  final double progress;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: _ArenaColors.violet,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ArenaColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ArenaColors.muted,
                fontSize: MoeTokens.textXs,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      minHeight: 6,
                      color: _ArenaColors.gold,
                      backgroundColor:
                          _ArenaColors.violet.withValues(alpha: .12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  progressLabel,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({
    required this.hero,
    this.locked = false,
    this.showFrame = false,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool locked;
  final bool showFrame;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    Widget portrait = asset == null
        ? _LargeHeroPlaceholder(color: hero.color)
        : ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          );
    if (tint != null && asset != null) {
      portrait = ColorFiltered(
        colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
        child: portrait,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border:
            showFrame ? Border.all(color: _ArenaColors.gold, width: 2) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x4430263C),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          portrait,
          if (locked)
            DecoratedBox(
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .48),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 34),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .74),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${hero.name} · ${hero.rarity.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeHeroPlaceholder extends StatelessWidget {
  const _LargeHeroPlaceholder({required this.color});

  final int color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Color(color).withValues(alpha: .86),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Text(
            '✦',
            style: TextStyle(fontSize: 42, color: Color(0xFFFFF4D0)),
          ),
        ),
      );
}

class _FormationSlot extends StatelessWidget {
  const _FormationSlot({
    required this.hero,
    required this.selected,
    required this.positionLabel,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero? hero;
  final bool selected;
  final String positionLabel;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final currentHero = hero;
    final rarityColor = currentHero == null
        ? _ArenaColors.goldLight
        : _rarityAccent(currentHero.rarity);
    return Container(
      width: 108,
      height: 118,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            selected ? Colors.white : rarityColor,
            rarityColor.withValues(alpha: .50),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: rarityColor.withValues(alpha: .55),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: currentHero == null
            ? const ColoredBox(
                color: Colors.white12,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: _ArenaColors.goldLight,
                    size: 32,
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _FormationSlotPortrait(
                    hero: currentHero,
                    imageAsset: imageAsset,
                    tint: tint,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x0030263C),
                          Color(0xCC30263C),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _ArenaColors.ink.withValues(alpha: .58),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                      ),
                      child: Text(
                        positionLabel,
                        style: const TextStyle(
                          color: _ArenaColors.goldLight,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _RarityMark(currentHero.rarity),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentHero.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: _ArenaColors.ink, blurRadius: 5),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              _roleIcon(currentHero.role),
                              color: _ArenaColors.goldLight,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${currentHero.role} · ${currentHero.faction}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFF0C2),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: _ArenaColors.ink,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FormationSlotPortrait extends StatelessWidget {
  const _FormationSlotPortrait({
    required this.hero,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    if (asset != null) {
      Widget image = Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
      if (tint != null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
          child: image,
        );
      }
      return image;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(hero.color).withValues(alpha: .86),
            _ArenaColors.ink.withValues(alpha: .92),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _roleIcon(hero.role),
          color: _ArenaColors.goldLight.withValues(alpha: .86),
          size: 34,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.inFormation,
    required this.stars,
    required this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final bool inFormation;
  final int stars;
  final VoidCallback onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Opacity(
        opacity: owned ? 1 : .55,
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                rarityColor.withValues(alpha: selected ? .96 : .72),
                _ArenaColors.cream,
              ],
            ),
            border: Border.all(color: rarityColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected || inFormation
                ? [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: .34),
                      blurRadius: 14,
                      spreadRadius: selected ? 1 : 0,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: owned
                  ? _ArenaColors.cream.withValues(alpha: .96)
                  : _ArenaColors.ink.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                _AvatarCircle(
                  hero: hero,
                  locked: !owned,
                  imageAsset: imageAsset,
                  tint: tint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hero.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _RarityMark(hero.rarity),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _HeroMetaChip(
                        icon: _roleIcon(hero.role),
                        label: hero.role,
                        color: rarityColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inFormation
                            ? '上阵中 · ${hero.faction}'
                            : owned
                                ? '${hero.faction} · $stars星'
                                : '未解锁 · ${hero.faction}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: inFormation
                              ? _ArenaColors.violet
                              : _ArenaColors.muted,
                          fontWeight:
                              inFormation ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
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

class _HeroCollectionCard extends StatelessWidget {
  const _HeroCollectionCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.shards,
    required this.stars,
    required this.power,
    required this.inFormation,
    required this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final int shards;
  final int stars;
  final int power;
  final bool inFormation;
  final VoidCallback onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              rarityColor.withValues(alpha: owned ? .86 : .42),
              _raritySurface(hero.rarity).withValues(alpha: owned ? .92 : .46),
            ],
          ),
          border: Border.all(color: rarityColor, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected || inFormation
              ? [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: .30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: owned
                ? _ArenaColors.cream.withValues(alpha: .96)
                : _ArenaColors.ink.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _AvatarCircle(
                hero: hero,
                locked: !owned,
                imageAsset: imageAsset,
                tint: tint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            owned ? hero.name : '${hero.name} · 未解锁',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: owned ? _ArenaColors.ink : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _RarityMark(hero.rarity),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _HeroMetaChip(
                          icon: _roleIcon(hero.role),
                          label: hero.role,
                          color: rarityColor,
                        ),
                        _HeroMetaChip(
                          icon: Icons.flag_rounded,
                          label: hero.faction,
                          color: _ArenaColors.violet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owned
                          ? '战力 $power · ${hero.skillName}'
                          : '碎片 $shards / 40',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: owned ? _ArenaColors.violet : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (inFormation)
                    _MiniStatusPill('上阵')
                  else
                    _MiniStatusPill(owned ? '$stars星' : '召唤'),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: owned ? _ArenaColors.muted : Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _ArenaColors.violet.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _RarityMark extends StatelessWidget {
  const _RarityMark(this.rarity);

  final ArenaRarity rarity;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .18),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          bottomRight: Radius.circular(7),
        ),
        border: Border.all(color: accent.withValues(alpha: .82)),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          color: rarity == ArenaRarity.ssr ? _ArenaColors.ink : accent,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: color.withValues(alpha: .26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.hero,
    this.locked = false,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool locked;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    Widget child;
    if (locked && asset == null) {
      child = const _LockedAvatarSilhouette();
    } else if (asset == null) {
      child = const Center(
        child: Text(
          '✦',
          style: TextStyle(color: Color(0xFFFFF3C7), fontSize: 18),
        ),
      );
    } else {
      Widget image = Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
      if (tint != null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
          child: image,
        );
      }
      child = ClipOval(
        child: locked
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF30263C),
                  BlendMode.saturation,
                ),
                child: image,
              )
            : image,
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(hero.color),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335A3F7D),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (locked)
            DecoratedBox(
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .46),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }
}

class _LockedAvatarSilhouette extends StatelessWidget {
  const _LockedAvatarSilhouette();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5C4A6C), Color(0xFF21192D)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.white.withValues(alpha: .34),
            size: 26,
          ),
        ),
      );
}

class _BattleUnit extends StatelessWidget {
  const _BattleUnit({
    required this.label,
    required this.hp,
    this.hero,
    this.intentLabel,
    this.enemy = false,
    this.active = false,
    this.selected = false,
    this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero? hero;
  final String label;
  final String? intentLabel;
  final int hp;
  final bool enemy;
  final bool active;
  final bool selected;
  final VoidCallback? onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final unitColor =
        enemy ? _ArenaColors.ink : Color(hero?.color ?? 0xFFB88BCE);
    final portraitAsset = imageAsset ?? hero?.imageAsset;
    Widget portrait = portraitAsset == null
        ? _UnitPlaceholder(color: unitColor, enemy: enemy)
        : Image.asset(
            portraitAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          );
    if (portraitAsset != null && tint != null) {
      portrait = ColorFiltered(
        colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
        child: portrait,
      );
    }
    final unit = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (intentLabel != null)
            Positioned(
              top: 0,
              child: _EnemyIntentPill(intentLabel!),
            ),
          if (selected)
            Positioned(
              bottom: 2,
              child: Container(
                width: 86,
                height: 24,
                decoration: BoxDecoration(
                  color: _ArenaColors.goldLight.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88FFE39B),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 72,
              height: 18,
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .20),
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 76,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enemy
                      ? const [Color(0xFF5B466A), Color(0xFF241A31)]
                      : [unitColor.withValues(alpha: .88), _ArenaColors.cream],
                ),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : active
                          ? _ArenaColors.goldLight
                          : _ArenaColors.gold,
                  width: selected || active ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5530263C),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: portrait,
            ),
          ),
          Positioned(
            bottom: 3,
            left: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: (hp / ArenaViewModel.enemyMaxHp)
                          .clamp(0, 1)
                          .toDouble(),
                      minHeight: 4,
                      color: enemy
                          ? const Color(0xFFD47E9B)
                          : const Color(0xFF79B9B0),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return unit;
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: unit,
    );
  }
}

class _UnitPlaceholder extends StatelessWidget {
  const _UnitPlaceholder({required this.color, required this.enemy});

  final Color color;
  final bool enemy;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _UnitPlaceholderPainter(color: color, enemy: enemy),
        child: const SizedBox.expand(),
      );
}

class _EnemyIntentPill extends StatelessWidget {
  const _EnemyIntentPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF3B2A4C).withValues(alpha: .88),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: const Color(0xFFFFC4D4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4430263C),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFC4D4),
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

class _BattleHandStack extends StatelessWidget {
  const _BattleHandStack({
    required this.cards,
    required this.energy,
    required this.finished,
    required this.lastPlayedCardIndex,
    required this.pulse,
    required this.onPlay,
  });

  final List<ArenaCard> cards;
  final int energy;
  final bool finished;
  final int lastPlayedCardIndex;
  final double pulse;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (cards.isEmpty) return const SizedBox.shrink();
          const cardWidth = 82.0;
          const maxStep = 70.0;
          final available = constraints.maxWidth;
          final step = cards.length <= 1
              ? 0.0
              : math.min(maxStep, (available - cardWidth) / (cards.length - 1));
          final safeStep = math.max(46.0, step);
          final handWidth = cardWidth + safeStep * (cards.length - 1);
          final start = math.max(0.0, (available - handWidth) / 2);
          final middle = (cards.length - 1) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: start,
                top: 0,
                child: const _BattleHandLabel(),
              ),
              for (var index = 0; index < cards.length; index++)
                Positioned(
                  left: start + safeStep * index,
                  top: 18 + (index - middle).abs() * 5,
                  child: Transform.rotate(
                    angle: (index - middle) * .055,
                    alignment: Alignment.bottomCenter,
                    child: _SkillCard(
                      card: cards[index],
                      enabled: !finished && energy >= cards[index].cost,
                      highlighted: index == lastPlayedCardIndex,
                      pulse: pulse,
                      onTap: () => onPlay(index),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BattleHandLabel extends StatelessWidget {
  const _BattleHandLabel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _ArenaColors.ink.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border:
              Border.all(color: _ArenaColors.goldLight.withValues(alpha: .4)),
        ),
        child: const Text(
          '本局手牌',
          style: TextStyle(
            color: _ArenaColors.goldLight,
            fontSize: MoeTokens.textXs,
            fontWeight: MoeTokens.fontWeightTitle,
          ),
        ),
      );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.card,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
    this.pulse = 0,
  });

  final ArenaCard card;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final glow = enabled ? (.45 + math.sin(pulse * math.pi * 2) * .18) : .16;
    return MoePressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : .54,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, highlighted ? -8 : 0, 0),
          width: 78,
          height: 124,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(card.color).withValues(alpha: .95),
                _ArenaColors.cream,
              ],
            ),
            border: Border.all(
              color: highlighted
                  ? Colors.white
                  : enabled
                      ? _ArenaColors.goldLight.withValues(alpha: glow + .30)
                      : _ArenaColors.goldLight.withValues(alpha: .52),
              width: highlighted ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? Colors.white.withValues(alpha: .48)
                    : _ArenaColors.goldLight.withValues(alpha: glow),
                blurRadius: highlighted ? 16 : 8 + glow * 8,
                spreadRadius: enabled ? 1 : 0,
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x44302B42),
                blurRadius: 9,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${card.sourceHeroName}技',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: _ArenaColors.cream,
                    child: Text(
                      '${card.cost}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _ArenaColors.violet,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    card.icon,
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: _ArenaColors.violet, blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                card.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: _ArenaColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattleComboBurst extends StatelessWidget {
  const _BattleComboBurst({
    required this.combo,
    required this.card,
  });

  final int combo;
  final ArenaCard card;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Container(
            key: ValueKey('${card.name}-$combo'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: .0),
                  _ArenaColors.ink.withValues(alpha: .84),
                  Color(card.color).withValues(alpha: .78),
                  Colors.white.withValues(alpha: .0),
                ],
              ),
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x6630263C),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  color: _ArenaColors.goldLight,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '连携 $combo',
                  style: const TextStyle(
                    color: _ArenaColors.goldLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: _ArenaColors.ink, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${card.sourceHeroName} · ${card.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _BattleRewardPanel extends StatelessWidget {
  const _BattleRewardPanel({
    required this.choices,
    required this.onChoose,
  });

  final List<ArenaCard> choices;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Text(
                  '胜利奖励 · 选择 1 张加入牌组',
                  style: TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textSm,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
                Spacer(),
                Text(
                  '肉鸽构筑',
                  style: TextStyle(
                    color: _ArenaColors.muted,
                    fontSize: MoeTokens.textXs,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MoeTokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                choices.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoeTokens.spaceXs,
                  ),
                  child: _SkillCard(
                    card: choices[index],
                    enabled: true,
                    highlighted: false,
                    onTap: () => onChoose(index),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SummonResultCard extends StatelessWidget {
  const _SummonResultCard({required this.result});

  final ArenaSummonResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(result.hero.color).withValues(alpha: .28),
            _ArenaColors.cream,
          ],
        ),
        border: Border.all(
          color: result.hero.rarity == ArenaRarity.ssr
              ? _ArenaColors.gold
              : const Color(0xFFE6D5B4),
          width: result.hero.rarity == ArenaRarity.ssr ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarCircle(hero: result.hero),
          const SizedBox(height: 4),
          Text(
            result.hero.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          Text(
            result.isNew ? 'NEW' : '+${result.shards} 碎片',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: _ArenaColors.violet,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterProgressCard extends StatelessWidget {
  const _CharacterProgressCard({
    required this.hero,
    required this.owned,
    required this.shards,
  });

  final ArenaHero hero;
  final bool owned;
  final int shards;

  @override
  Widget build(BuildContext context) {
    final target = hero.rarity == ArenaRarity.ssr ? 60 : 40;
    final progress = (shards / target).clamp(0.0, 1.0);
    return _SurfaceCard(
      child: Row(
        children: [
          _AvatarCircle(hero: hero, locked: !owned),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owned ? '碎片升星' : '召唤解锁',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textSm,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  owned
                      ? '碎片 $shards / $target · 重复角色会自动转化'
                      : '未解锁 · 可通过当前召唤池获得',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: _ArenaColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: LinearProgressIndicator(
                    value: owned ? progress : 0,
                    minHeight: 6,
                    color: _rarityAccent(hero.rarity),
                    backgroundColor: _ArenaColors.violet.withValues(alpha: .12),
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

class _CultivationRow extends StatelessWidget {
  const _CultivationRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.ready,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: ready
              ? _ArenaColors.goldLight.withValues(alpha: .28)
              : _ArenaColors.violet.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          border: Border.all(
            color: ready
                ? _ArenaColors.gold.withValues(alpha: .36)
                : _ArenaColors.violet.withValues(alpha: .12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: ready ? _ArenaColors.violet : _ArenaColors.muted,
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 62,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.violet,
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.muted,
                  fontSize: MoeTokens.textXs,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EquipmentSlot extends StatelessWidget {
  const _EquipmentSlot(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _ArenaColors.ink.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .32)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 13,
                color: _ArenaColors.violet,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textXs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: _ArenaColors.muted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _ArenaColors.violet,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  '$value%',
                  style: const TextStyle(
                    color: _ArenaColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 7,
                color: color,
                backgroundColor: const Color(0xFFE9DCC3),
              ),
            ),
          ],
        ),
      );
}

class _BattleLogRibbon extends StatelessWidget {
  const _BattleLogRibbon({
    required this.hero,
    required this.turn,
    required this.combo,
    required this.objective,
    required this.enemyIntent,
    required this.message,
    required this.finished,
    required this.won,
  });

  final ArenaHero hero;
  final int turn;
  final int combo;
  final String objective;
  final String enemyIntent;
  final String message;
  final bool finished;
  final bool won;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: _ArenaColors.gold.withValues(alpha: .72)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3330263C),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            _AvatarCircle(hero: hero),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BattleLogPill('T$turn'),
                      const SizedBox(width: 6),
                      _BattleLogPill(
                        finished ? (won ? '胜利' : '失败') : '连携 $combo',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ArenaColors.violet,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MoeTokens.spaceXs),
                  Text(
                    '$objective ｜ $enemyIntent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: MoeTokens.textXs,
                      fontWeight: MoeTokens.fontWeightSubtitle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _BattleLogPill extends StatelessWidget {
  const _BattleLogPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _ArenaColors.violet.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _WindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .3);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .30,
        size.height * .18,
        size.width * .4,
        size.height * .55,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .48, size.height * .18, 4, size.height * .55),
      Paint()..color = const Color(0x5573568A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .30, size.height * .43, size.width * .4, 4),
      Paint()..color = const Color(0x5573568A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitPlaceholderPainter extends CustomPainter {
  _UnitPlaceholderPainter({required this.color, required this.enemy});

  final Color color;
  final bool enemy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .55);
    final body = Paint()
      ..color = enemy ? const Color(0xFF241A31) : color.withValues(alpha: .92);
    final accent = Paint()
      ..color = enemy
          ? const Color(0xFF6F5A7C).withValues(alpha: .70)
          : _ArenaColors.goldLight.withValues(alpha: .88);

    canvas.drawCircle(
      Offset(center.dx, size.height * .26),
      size.width * .18,
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * .52,
          height: size.height * .55,
        ),
        const Radius.circular(20),
      ),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .23, size.height * .36)
        ..quadraticBezierTo(size.width * .50, size.height * .18,
            size.width * .77, size.height * .36)
        ..lineTo(size.width * .62, size.height * .44)
        ..quadraticBezierTo(size.width * .50, size.height * .32,
            size.width * .38, size.height * .44)
        ..close(),
      accent,
    );
    if (!enemy) {
      canvas.drawCircle(
        Offset(size.width * .57, size.height * .24),
        2.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size.width * .57, size.height * .24),
        1.0,
        Paint()..color = _ArenaColors.violet,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnitPlaceholderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.enemy != enemy;
}

class _FormationLanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ArenaColors.goldLight.withValues(alpha: .50)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .08, size.height * .50),
      Offset(size.width * .92, size.height * .50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TowerPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final node0 = Offset(size.width * .16, size.height * .66);
    final node1 = Offset(size.width * .35, size.height * .40);
    final node2 = Offset(size.width * .52, size.height * .64);
    final node3 = Offset(size.width * .64, size.height * .34);
    final node4 = Offset(size.width * .82, size.height * .50);
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = LinearGradient(
        colors: [
          _ArenaColors.goldLight.withValues(alpha: .22),
          _ArenaColors.goldLight.withValues(alpha: .78),
          Colors.white.withValues(alpha: .42),
        ],
      ).createShader(Offset.zero & size);
    final dimRoutePaint = Paint()
      ..color = Colors.white.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    void drawRoute(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length; index++) {
        final previous = points[index - 1];
        final current = points[index];
        final control = Offset(
          (previous.dx + current.dx) / 2,
          math.min(previous.dy, current.dy) - size.height * .08,
        );
        path.quadraticBezierTo(control.dx, control.dy, current.dx, current.dy);
      }
      canvas.drawPath(path, paint);
    }

    drawRoute([node0, node1, node3, node4], routePaint);
    drawRoute([node0, node2, node3], dimRoutePaint);
    drawRoute([node2, node4], dimRoutePaint);

    final islandPaint = Paint()
      ..color = _ArenaColors.ink.withValues(alpha: .16)
      ..style = PaintingStyle.fill;
    for (final node in [node0, node1, node2, node3, node4]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(node.dx, node.dy + 31),
          width: 92,
          height: 18,
        ),
        islandPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
