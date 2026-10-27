part of 'arena_page.dart';

Widget _arenaPageNavigation(_ArenaPageState state) => state._buildNavigation();
Widget _arenaOverlay(_ArenaPageState state, ArenaView view) =>
    state._buildOverlay(view);

extension _ArenaPageOverlays on _ArenaPageState {
  Widget _buildOverlay(ArenaView view) {
    switch (view) {
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
    _refresh(() => _formationSaved = true);
    unawaited(_model.syncFormation());
  }

  void _openSummonPool() {
    _refresh(() => _showSummonPool = true);
  }

  void _closeSummonPool() {
    _refresh(() => _showSummonPool = false);
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
          bottom: _arenaNavHeight + 8,
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
          bottom: _arenaNavHeight + 16,
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
                        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
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
                          icon: Icons.park_rounded,
                          title: '星辉营地',
                          body: '进入共享世界，看看你的英雄今天过得怎么样。',
                          onTap: () => unawaited(_openCampPreview(hero)),
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
                      if (hero.id == ArenaViewModel.flagshipHeroId) ...[
                        const SizedBox(width: MoeTokens.spaceSm),
                        Expanded(
                          child: _HomeActionCard(
                            icon: bond >= ArenaViewModel.heroChatBondRequired
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.lock_outline_rounded,
                            title: '闲聊',
                            body: bond >= ArenaViewModel.heroChatBondRequired
                                ? '和小星聊聊营地里今天发生的事。'
                                : '羁绊 ${ArenaViewModel.heroChatBondRequired} 级解锁 · 当前 $bond 级。',
                            onTap: () => unawaited(_openHeroChat(hero, bond)),
                          ),
                        ),
                      ],
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
                    _refresh(() => _formationSaved = false);
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
                    _model.routeMessage,
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
            child: _goldButton(_model.towerActionLabel, () {
              unawaited(_model.runTowerNode());
            }),
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
          bottom: _arenaNavHeight + 22,
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
      subtitle: _showCardCodex
          ? '通用卡牌 ${_model.catalogCards.length} 张，不绑定英雄。英雄的能力在编队里生效。'
          : '总览所有英雄，点选卡片进入养成详情。后续可扩展筛选、阵营和职业分类。',
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
              const SizedBox(width: 8),
              _codexTab('英雄', !_showCardCodex, () {
                _refresh(() => _showCardCodex = false);
              }),
              const SizedBox(width: 6),
              _codexTab('卡牌', _showCardCodex, () {
                _refresh(() => _showCardCodex = true);
              }),
            ],
          ),
          if (_showCardCodex) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final element in ['全部', ...ArenaCombos.elements])
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(element),
                    selected: _codexElement == element,
                    onSelected: (_) => _refresh(() => _codexElement = element),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _SurfaceCard(
              child: _showCardCodex
                  ? _cardCodexGrid()
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _model.heroes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                          inFormation: _model.formationHeroes.any(
                              (formationHero) => formationHero.id == hero.id),
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

  Widget _codexTab(String label, bool selected, VoidCallback onTap) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _ArenaColors.violet : const Color(0xFFE9DCC3),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ArenaColors.violet,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _cardCodexGrid() {
    final cards = _codexElement == '全部'
        ? _model.catalogCards
        : _model.catalogCards
            .where((card) => card.elements.contains(_codexElement))
            .toList();
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        final effect =
            card.damage < 0 ? '治疗 ${-card.damage}' : '伤害 ${card.damage}';
        final aim = switch (card.targeting) {
          ArenaCardTargeting.allEnemies => '全体',
          ArenaCardTargeting.allyTeam => '治疗',
          ArenaCardTargeting.singleEnemy => '单体',
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Color(card.color).withValues(alpha: .22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(card.color).withValues(alpha: .7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${card.elements.join('·')} · ${card.cost}费 · $aim',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _ArenaColors.violet,
                ),
              ),
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
              Text(
                card.trait == '无' ? effect : '$effect · ${card.trait}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _ArenaColors.muted),
              ),
            ],
          ),
        );
      },
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
          bottom: _arenaNavHeight + 14,
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
          bottom: _arenaNavHeight + 14,
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
                  const Text(
                    '编队能力',
                    style: TextStyle(
                      color: _ArenaColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '不是卡牌。上场后，同元素的通用牌伤害 +4。',
                    style: TextStyle(color: _ArenaColors.muted, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          _buildBattleHud(),
          const SizedBox(height: 6),
          _buildBattleStatusLine(),
          const SizedBox(height: 4),
          Expanded(child: _buildBattleField()),
          const SizedBox(height: 6),
          _buildBattleDock(),
        ],
      ),
    );
  }

  Widget _buildBattleHud() {
    return Row(
      children: [
        _battleMeter(
          label: '我方生命',
          value: _model.playerHp,
          color: const Color(0xFF79B9B0),
        ),
        const SizedBox(width: 8),
        _battleBadge('战力', '${_model.teamPower}'),
        const Spacer(),
        _battleBadge('能量', '${_model.energy} / 10'),
        const SizedBox(width: 8),
        _battleBadge('星晶', '${_model.starCrystals}'),
        const Spacer(),
        _battleMeter(
          label: '敌方生命',
          value: _model.enemyHp,
          color: const Color(0xFFD47E9B),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          height: 28,
          child: _compactGhostButton(
            '返回',
            () => _model.navigate(ArenaView.lobby),
          ),
        ),
      ],
    );
  }

  Widget _battleMeter({
    required String label,
    required int value,
    required Color color,
  }) {
    final ratio = (value / 100).clamp(0, 1).toDouble();
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$value%',
                style: const TextStyle(
                  color: _ArenaColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFE9DCC3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStatusLine() {
    final phase = _model.finished
        ? (_model.won ? '胜利' : '失败')
        : 'T${_model.turn} · 场纹 ${_model.fieldRune}';
    final hint = _playHint;
    final status = hint.isEmpty ? _model.battleMessage : hint;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _ArenaColors.cream.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        border: Border.all(color: _ArenaColors.gold.withValues(alpha: .72)),
      ),
      child: Row(
        children: [
          Text(
            phase,
            style: const TextStyle(
              color: _ArenaColors.violet,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ArenaColors.violet,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_model.battleObjective} ｜ ${_model.enemyIntent}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _ArenaColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleField() {
    return AnimatedBuilder(
      animation: Listenable.merge([_strikeCtrl, _castCtrl]),
      builder: (context, _) {
        final strike = _model.strike;
        final t = _strikeCtrl.value;
        final comboHit =
            _comboSlam && _castCtrl.isAnimating && _castCtrl.value >= .74;
        final shaking = !comboHit &&
            strike != null &&
            strike.damage > 0 &&
            _strikeCtrl.isAnimating &&
            t < 1;
        final punch = comboHit ? 14.0 : 5.0;
        final shakeT =
            comboHit ? ((_castCtrl.value - .74) / .26).clamp(0.0, 1.0) : t;
        final dx = (shaking || comboHit)
            ? math.sin(shakeT * math.pi * 8) * punch * (1 - shakeT)
            : 0.0;
        final dy =
            comboHit ? math.sin(shakeT * math.pi * 5) * 6 * (1 - shakeT) : 0.0;
        final castCard = _castCard;
        final previewBurst = _previewBurst;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Stack(
            children: [
              ..._buildBattleUnits(),
              if (_comboSlam && _comboCards.isNotEmpty && _castCtrl.isAnimating)
                _BattleComboCast(
                  cards: _comboCards,
                  t: _castCtrl.value,
                  target: _castAnchor(_comboAim),
                  impact: _comboResolved ? _comboImpact : null,
                )
              else if (castCard != null && _castCtrl.isAnimating)
                _BattleCastFlight(
                  card: castCard,
                  t: _castCtrl.value,
                  target: _castAnchor(castCard),
                ),
              if (strike != null && _strikeCtrl.isAnimating)
                _BattleStrikeLayer(strike: strike, t: t),
              if (previewBurst != null)
                Positioned(
                  left: 90,
                  right: 90,
                  top: 0,
                  child: previewBurst,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget? get _previewBurst {
    if (_model.hasPendingReward) return null;
    if (_comboSlam && _comboCards.isNotEmpty && !_comboResolved) {
      final preview = _model.previewComboChain(_comboCards);
      if (preview != null) {
        return _BattleComboBurst(
          combo: preview,
          card: _comboCards.last,
          charged: true,
        );
      }
    }
    if (_playQueue.isNotEmpty) {
      final preview = _model.previewComboChain(_playQueue);
      if (preview != null) {
        return _BattleComboBurst(
          combo: preview,
          card: _playQueue.last,
          charged: _playQueue.length >= 2,
        );
      }
    }
    final played = _model.lastPlayedCard;
    final combo = _model.activeCombo;
    if (played == null || combo == null) return null;
    return _BattleComboBurst(
      combo: combo,
      card: played,
      charged: _comboSlam,
    );
  }

  Future<void> _shareBattleResult() async {
    final floor = _model.towerFloor;
    final crystals = _model.crystalRewardForNode();
    BehaviorAnalyticsService.instance.trackTap(
      'game_arena',
      params: {'action': 'share_battle', 'floor': '$floor'},
    );
    await prefillCreatePostShareDraft(
      '我在星辉远征·星砂回廊打过了第 $floor 层！星晶 +$crystals\n\n#星辉远征',
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed('/create-post');
  }

  Widget _buildBattleDock() {
    if (_model.hasPendingReward) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BattleRewardPanel(
            choices: _model.rewardChoices,
            crystalReward: _model.crystalRewardForNode(),
            onChoose: _model.chooseRewardCard,
            onShare: _shareBattleResult,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 112,
              child: _ghostButton('跳过奖励', _model.skipReward, minHeight: 40),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 124,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      decoration: BoxDecoration(
        color: _ArenaColors.cream.withValues(alpha: .46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ArenaColors.gold.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BattlePile(
            label: '牌库',
            count: _model.drawCount,
          ),
          const SizedBox(width: 6),
          _BattlePile(
            label: '弃牌',
            count: _model.discardCount,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _model.hand.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '手牌已打出，结束回合会从牌库或弃牌堆再抽',
                      style: TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _uiPulse,
                    builder: (context, _) => _BattleHandStack(
                      cards: _model.hand,
                      energy: _model.energy,
                      finished: _model.finished,
                      lastPlayedCardIndex: -1,
                      queuedCards: _playQueue,
                      hiddenCards: [
                        if (_castCard != null) _castCard!,
                        if (_comboSlam) ..._comboCards,
                      ],
                      pulse: _uiPulse.value,
                      onPlay: _onHandTap,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 112, child: _buildBattleActions()),
        ],
      ),
    );
  }

  Widget _buildBattleActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_model.finished)
          _goldButton(
            _model.won ? '下一层' : '重新挑战',
            _model.startBattle,
            minHeight: 40,
          )
        else
          _darkButton('结束回合', _endTurn, minHeight: 44),
        if (_model.finished && !_model.won) ...[
          const SizedBox(height: 6),
          _goldButton(
            '调整编队',
            () => _model.navigate(ArenaView.formation),
            minHeight: 36,
          ),
        ],
        if (_model.finished && _model.won) ...[
          const SizedBox(height: 6),
          _ghostButton(
            '回到爬塔',
            () => _model.navigate(ArenaView.tower),
            minHeight: 36,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBattleUnits() {
    final team = _model.formationHeroes;
    const friendlyPositions = _friendlySlots;
    const enemyPositions = _enemySlots;

    return [
      for (var index = 0; index < friendlyPositions.length; index++)
        Align(
          alignment: friendlyPositions[index],
          child: SizedBox(
            width: 92,
            height: 128,
            child: _BattleUnit(
              hero: index < team.length ? team[index] : null,
              label: index < team.length ? team[index].name : '空位',
              active: index == 0 && !_model.finished,
              hp: _model.playerHp,
              maxHp: _model.playerMaxHp,
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
            width: 92,
            height: 128,
            child: _BattleUnit(
              label: '敌影 ${index + 1}',
              intentLabel:
                  index == _model.selectedEnemyIndex && !_model.finished
                      ? '意图 -${_model.enemyTurnDamage}'
                      : null,
              enemy: true,
              active: index == _model.selectedEnemyIndex && !_model.finished,
              selected: index == _model.selectedEnemyIndex && !_model.finished,
              hp: _model.enemyHpAt(index),
              maxHp: _model.encounterMaxHp,
              onTap: () => _onEnemyTap(index),
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
        _arenaNavHeight + _arenaNavGap + 8,
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
              _resource('✧', '${_model.starCrystals}'),
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
            height: _arenaNavHeight,
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

  Widget _goldButton(
    String label,
    VoidCallback onPressed, {
    double minHeight = 34,
  }) =>
      _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.ink,
        minHeight: minHeight,
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

  Widget _darkButton(
    String label,
    VoidCallback onPressed, {
    double minHeight = 34,
  }) =>
      _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: Colors.white,
        minHeight: minHeight,
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

  Widget _ghostButton(
    String label,
    VoidCallback onPressed, {
    double minHeight = 34,
  }) =>
      _ArenaTextButton(
        label: label,
        onPressed: onPressed,
        textColor: _ArenaColors.violet,
        minHeight: minHeight,
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
