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
  const ArenaPage({super.key});

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  static const double _designWidth = 800;
  static const double _designHeight = 450;
  static const double _navHeight = 56;
  static const double _navGap = 12;

  late final ArenaViewModel _model;
  late final ArenaBattleGame _game;

  @override
  void initState() {
    super.initState();
    _model = ArenaViewModel();
    _game = ArenaBattleGame(model: _model);
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    _model.dispose();
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
                            child: ExcludeSemantics(
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
          left: 318,
          bottom: _navHeight + 10,
          width: 210,
          height: 255,
          child: _HeroPortrait(hero: hero, showFrame: true),
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
          top: 104,
          width: 168,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _smallAction('✧  星晶 ${_model.starCrystals}', () {}),
              const SizedBox(height: 9),
              _smallAction('图鉴 ${_model.ownedCount}/${_model.heroes.length}',
                  () => _model.navigate(ArenaView.collection)),
              const SizedBox(height: 9),
              _smallAction('召唤澜星 UP', () => _model.navigate(ArenaView.summon)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormation() {
    final formation = _model.ownedHeroes.take(3).toList();
    return _panelScaffold(
      title: '编队',
      subtitle: '已拥有角色才能上阵，站位决定承伤顺序。',
      child: Column(
        children: [
          Expanded(
            flex: 5,
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
                        return _FormationSlot(
                          hero: index < formation.length
                              ? formation[index]
                              : null,
                        );
                      }),
                    ),
                  ),
                ],
              ),
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
              Text(
                '队伍战力 ${_model.teamPower}',
                style: const TextStyle(
                  color: _ArenaColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              _goldButton('保存并挑战', _model.startBattle),
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
                  onTap: () => _model.selectHero(index),
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
          _towerNode(.14, .74, Icons.local_fire_department_rounded, false),
          _towerNode(.33, .58, Icons.local_cafe_rounded, false),
          _towerNode(.54, .38, Icons.auto_awesome_rounded, true),
          _towerNode(.42, .20, Icons.storefront_rounded, false),
          _towerNode(.70, .14, Icons.workspace_premium_rounded, false),
          Positioned(
            left: 18,
            bottom: 14,
            child: _SurfaceCard(
              width: 246,
              child: const Text(
                '当前构筑：星潮减费 + 月霜虚弱。下一层胜利后可选新技能牌。',
                style: TextStyle(fontSize: 11, height: 1.45),
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
        const Positioned.fill(child: _SummonBackground()),
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
          left: 318,
          top: 44,
          width: 205,
          height: 245,
          child: _HeroPortrait(hero: upHero, showFrame: true),
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
      ],
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
      subtitle: '收集角色，查看技能、碎片和养成状态。',
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
              _ghostButton('去召唤', () => _model.navigate(ArenaView.summon)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _model.heroes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final hero = _model.heroes[index];
                return _HeroCollectionCard(
                  hero: hero,
                  owned: _model.isOwned(hero),
                  shards: _model.shardsOf(hero),
                  onTap: () {
                    _model.selectHero(index);
                    _model.navigate(ArenaView.character);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _SurfaceCard(
              child: Row(
                children: [
                  _AvatarCircle(
                    hero: _model.activeHero,
                    locked: !_model.isOwned(_model.activeHero),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_model.activeHero.name} · ${_model.activeHero.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _model.activeHero.skillDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ArenaColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _goldButton(
                    _model.isOwned(_model.activeHero) ? '查看详情' : '去召唤',
                    () => _model.isOwned(_model.activeHero)
                        ? _model.navigate(ArenaView.character)
                        : _model.navigate(ArenaView.summon),
                  ),
                ],
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
          child: _HeroPortrait(hero: hero, locked: !owned, showFrame: true),
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
                      _StatBox('等级', owned ? '${hero.level}' : '--'),
                      _StatBox('好感度', owned ? '${hero.favorite}' : '--'),
                      _StatBox('战力', owned ? '${hero.power}' : '--'),
                    ],
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
                  _SurfaceCard(
                    child: Row(
                      children: [
                        _AvatarCircle(hero: hero, locked: !owned),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            owned
                                ? '碎片 ${_model.shardsOf(hero)} · 可继续召唤升星'
                                : '未解锁 · 可通过星辉召唤获得',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _ArenaColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
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
          top: 112,
          left: 220,
          right: 220,
          child: _BattleLogRibbon(
            hero: _model.activeHero,
            turn: _model.turn,
            combo: _model.combo,
            message: _model.battleMessage,
            finished: _model.finished,
            won: _model.won,
          ),
        ),
        Positioned(
          left: 92,
          right: 182,
          bottom: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _model.cards.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _SkillCard(
                  card: _model.cards[index],
                  enabled: !_model.finished &&
                      _model.energy >= _model.cards[index].cost,
                  highlighted: index == _model.lastPlayedCardIndex,
                  onTap: () => _model.playCard(index),
                ),
              ),
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
              _darkButton('结束回合', _model.endTurn),
              if (_model.finished) ...[
                const SizedBox(height: 8),
                _goldButton(
                  _model.won ? '再战一次' : '重新挑战',
                  _model.startBattle,
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
    final team = _model.ownedHeroes.take(3).toList();
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
              enemy: true,
              active: index == 1 && !_model.finished,
              hp: _model.enemyHp,
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _ArenaColors.violet,
            ),
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
              _iconButton('⚙', () {}),
            ],
          ),
        ),
      );

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
        child: _iconButton('×', () => _model.navigate(ArenaView.lobby)),
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

  Widget _smallAction(String label, VoidCallback onPressed) => _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.violet,
        fontWeight: FontWeight.w800,
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(10),
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

  Widget _towerNode(double left, double top, IconData icon, bool active) =>
      Align(
        alignment: Alignment(left * 2 - 1, top * 2 - 1),
        child: MoePressable(
          onTap: _model.startBattle,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 58 : 50,
            height: active ? 58 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFFFFF0B8) : _ArenaColors.cream,
              border: Border.all(
                color: active ? _ArenaColors.goldLight : _ArenaColors.gold,
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
            child: Icon(icon, color: _ArenaColors.ink, size: active ? 26 : 22),
          ),
        ),
      );
}

class _ArenaTextButton extends StatelessWidget {
  const _ArenaTextButton({
    required this.label,
    required this.onPressed,
    required this.textColor,
    required this.decoration,
    this.fontWeight = FontWeight.w900,
  });

  final String label;
  final VoidCallback onPressed;
  final Color textColor;
  final Decoration decoration;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: decoration,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: fontWeight,
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
  const _SummonBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
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
        child: SizedBox.expand(),
      );
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

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({
    required this.hero,
    this.locked = false,
    this.showFrame = false,
  });

  final ArenaHero hero;
  final bool locked;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final imageAsset = hero.imageAsset;
    final portrait = imageAsset == null
        ? _LargeHeroPlaceholder(color: hero.color)
        : ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          );

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
  const _FormationSlot({required this.hero});

  final ArenaHero? hero;

  @override
  Widget build(BuildContext context) => Container(
        width: 92,
        height: 92,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white12,
          border: Border.all(color: _ArenaColors.goldLight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: hero == null
            ? const Icon(Icons.add_rounded, color: _ArenaColors.goldLight)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AvatarCircle(hero: hero!),
                  const SizedBox(height: 5),
                  Text(
                    hero!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Opacity(
        opacity: owned ? 1 : .55,
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _ArenaColors.cream,
            border: Border.all(
              color: selected ? _ArenaColors.gold : const Color(0xFFE6D5B4),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              _AvatarCircle(hero: hero, locked: !owned),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hero.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      hero.role,
                      style: const TextStyle(
                        fontSize: 9,
                        color: _ArenaColors.muted,
                      ),
                    ),
                    Text(
                      '${hero.rarity.label} · ${hero.stars} 星',
                      style: const TextStyle(
                        fontSize: 9,
                        color: _ArenaColors.violet,
                      ),
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

class _HeroCollectionCard extends StatelessWidget {
  const _HeroCollectionCard({
    required this.hero,
    required this.owned,
    required this.shards,
    required this.onTap,
  });

  final ArenaHero hero;
  final bool owned;
  final int shards;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 178,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: owned
              ? _ArenaColors.cream
              : _ArenaColors.cream.withValues(alpha: .64),
          border: Border.all(
            color: owned ? const Color(0xFFE6C67E) : const Color(0xFFC9B8CF),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _AvatarCircle(hero: hero, locked: !owned),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          owned ? hero.name : '未解锁',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        hero.rarity.label,
                        style: const TextStyle(
                          color: _ArenaColors.violet,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owned
                        ? '${hero.role} · ${hero.faction}'
                        : '碎片 $shards / 40',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: _ArenaColors.muted,
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
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.hero, this.locked = false});

  final ArenaHero hero;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final imageAsset = hero.imageAsset;
    Widget child;
    if (imageAsset == null) {
      child = const Center(
        child: Text(
          '✦',
          style: TextStyle(color: Color(0xFFFFF3C7), fontSize: 18),
        ),
      );
    } else {
      child = ClipOval(
        child: Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
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

class _BattleUnit extends StatelessWidget {
  const _BattleUnit({
    required this.label,
    required this.hp,
    this.hero,
    this.enemy = false,
    this.active = false,
  });

  final ArenaHero? hero;
  final String label;
  final int hp;
  final bool enemy;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final unitColor =
        enemy ? _ArenaColors.ink : Color(hero?.color ?? 0xFFB88BCE);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
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
                  color: active ? _ArenaColors.goldLight : _ArenaColors.gold,
                  width: active ? 3 : 2,
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
              child: hero?.imageAsset == null
                  ? _UnitPlaceholder(color: unitColor, enemy: enemy)
                  : Image.asset(
                      hero!.imageAsset!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
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
                      value: hp / 100,
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

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.card,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
  });

  final ArenaCard card;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              color: highlighted ? Colors.white : _ArenaColors.goldLight,
              width: highlighted ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55302B42),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: CircleAvatar(
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
    required this.message,
    required this.finished,
    required this.won,
  });

  final ArenaHero hero;
  final int turn;
  final int combo;
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
            _BattleLogPill('T$turn'),
            const SizedBox(width: 6),
            _BattleLogPill(finished ? (won ? '胜利' : '失败') : '连携 $combo'),
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
    final path = Path()
      ..moveTo(size.width * .18, size.height * .82)
      ..cubicTo(
        size.width * .34,
        size.height * .64,
        size.width * .60,
        size.height * .72,
        size.width * .76,
        size.height * .46,
      )
      ..cubicTo(
        size.width * .62,
        size.height * .28,
        size.width * .40,
        size.height * .30,
        size.width * .50,
        size.height * .12,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = _ArenaColors.goldLight.withValues(alpha: .70)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
