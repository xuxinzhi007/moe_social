import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/arena/arena_battle_cast.dart';
import '../../game/arena/arena_combos.dart';
import '../../game/arena/arena_view_model.dart';
import '../../game/arena/battle/arena_battle_scene.dart';
import '../../services/behavior_analytics_service.dart';
import '../../services/create_post_draft_prefs.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/motion/moe_pressable.dart';
import 'arena_camp_preview_page.dart';
import 'arena_hero_chat_page.dart';

part 'arena_chrome.dart';
part 'arena_overlays.dart';

const _friendlySlots = <Alignment>[
  Alignment(-.72, .42),
  Alignment(-.46, .08),
  Alignment(-.20, .42),
];

const _enemySlots = <Alignment>[
  Alignment(.20, .42),
  Alignment(.46, .08),
  Alignment(.72, .42),
];

const double _arenaDesignWidth = 800;
const double _arenaDesignHeight = 450;
const double _arenaNavHeight = 56;
const double _arenaNavGap = 12;

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

class _ArenaPageState extends State<ArenaPage> with TickerProviderStateMixin {
  late final ArenaViewModel _model;
  late final ArenaBattleCast _cast;
  late final ArenaBattleGame _game;
  late final AnimationController _uiPulse;
  late final AnimationController _strikeCtrl;
  late final AnimationController _castCtrl;
  late final bool _ownsModel;
  bool _showCardCodex = false;
  String _codexElement = '全部';
  bool _formationSaved = false;
  bool _showSummonPool = false;

  List<ArenaCard> get _playQueue => _cast.playQueue;
  bool get _comboSlam => _cast.comboSlam;
  bool get _comboResolved => _cast.comboResolved;
  int get _comboImpact => _cast.comboImpact;
  List<ArenaCard> get _comboCards => _cast.comboCards;
  ArenaCard? get _castCard => _cast.castCard;
  int get _castTarget => _cast.castTarget;

  void _refresh(VoidCallback update) => setState(update);

  void _applyCast(ArenaCastUpdate update) {
    if (update.rebuild) setState(() {});
    final duration = update.duration;
    if (duration == null) return;
    _castCtrl.duration = duration;
    _castCtrl.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _ownsModel = widget.modelForTesting == null;
    _model = widget.modelForTesting ??
        ArenaViewModel(initialView: widget.initialView);
    _cast = ArenaBattleCast(_model);
    _game = ArenaBattleGame(model: _model);
    _uiPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _strikeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _castCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
    _castCtrl.addListener(_onCastTick);
    _castCtrl.addStatusListener(_onCastStatus);
    _registerOverlays();
    _syncStageOverlays();
    _model.addListener(_onModelSignal);
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

  Future<void> _openCampPreview(ArenaHero hero) async {
    _game.pauseEngine();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArenaCampPreviewPage(hero: hero)),
    );
    if (mounted) _game.resumeEngine();
  }

  Future<void> _openHeroChat(ArenaHero hero, int bond) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArenaHeroChatPage(hero: hero, bond: bond),
      ),
    );
  }

  void _onArenaStrike() {
    if (_cast.takeStrike()) _strikeCtrl.forward(from: 0);
  }

  void _onHandTap(int index) {
    _applyCast(_cast.onHandTap(index, animating: _castCtrl.isAnimating));
  }

  void _onEnemyTap(int index) {
    _applyCast(_cast.onEnemyTap(index, animating: _castCtrl.isAnimating));
  }

  void _onCastTick() {
    _cast.onCastTick(_castCtrl.value);
  }

  void _onCastStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _applyCast(_cast.onCastCompleted());
  }

  void _endTurn() {
    if (_castCtrl.isAnimating) return;
    setState(_cast.clearQueues);
    _model.endTurn();
  }

  void _onModelSignal() {
    _onArenaStrike();
    _syncStageOverlays();
  }

  Widget _stage() {
    return GameWidget<ArenaBattleGame>(
      game: _game,
      overlayBuilderMap: {
        for (final view in ArenaView.values)
          view.name: (context, game) =>
              SizedBox.expand(child: _arenaOverlay(this, view)),
        'nav': (context, game) => SizedBox.expand(
              child: Stack(children: [_arenaPageNavigation(this)]),
            ),
      },
    );
  }

  void _registerOverlays() {
    for (final view in ArenaView.values) {
      _game.overlays.addEntry(
        view.name,
        (context, game) => SizedBox.expand(child: _arenaOverlay(this, view)),
      );
    }
    _game.overlays.addEntry(
      'nav',
      (context, game) => SizedBox.expand(
        child: Stack(children: [_arenaPageNavigation(this)]),
      ),
    );
  }

  void _syncStageOverlays() {
    for (final view in ArenaView.values) {
      _game.overlays.setActive(view.name, active: view == _model.view);
    }
    final showNav =
        _model.view != ArenaView.battle && _model.summonResults.isEmpty;
    if (showNav) {
      if (!_game.overlays.isActive('nav')) {
        _game.overlays.add('nav', priority: 1);
      }
    } else if (_game.overlays.isActive('nav')) {
      _game.overlays.remove('nav');
    }
  }

  ArenaCard get _comboAim {
    for (final card in _comboCards) {
      if (card.damage >= 0) return card;
    }
    return _comboCards.last;
  }

  Alignment _castAnchor(ArenaCard card) {
    switch (card.targeting) {
      case ArenaCardTargeting.allEnemies:
        return const Alignment(.46, .2);
      case ArenaCardTargeting.allyTeam:
        return const Alignment(-.46, .2);
      case ArenaCardTargeting.singleEnemy:
        final index = _castTarget.clamp(0, _enemySlots.length - 1);
        return _enemySlots[index];
    }
  }

  String get _playHint {
    if (_castCtrl.isAnimating && _comboSlam && _comboCards.isNotEmpty) {
      final names = _comboCards.map((card) => card.name).join('、');
      return _comboResolved ? '组合命中 · $names' : '组合汇聚 · $names';
    }
    if (_castCtrl.isAnimating && _castCard != null) {
      return '「${_castCard!.name}」出手中';
    }
    if (_playQueue.isEmpty) return '';
    final preview = _model.previewComboChain(_playQueue);
    final combo =
        preview == null ? '' : '将触发「${preview.name}」${preview.formula} · ';
    if (_playQueue.length == 1) {
      final card = _playQueue.first;
      switch (card.targeting) {
        case ArenaCardTargeting.singleEnemy:
          return '已举起「${card.name}」· $combo点敌影释放';
        case ArenaCardTargeting.allEnemies:
          return '已举起「${card.name}」· $combo再点一次打全体';
        case ArenaCardTargeting.allyTeam:
          return '已举起「${card.name}」· $combo再点一次治疗';
      }
    }
    final names = _playQueue.map((card) => card.name).join('、');
    return '连打 $names · $combo点敌影一起打出';
  }

  @override
  void dispose() {
    _model.removeListener(_onModelSignal);
    _castCtrl
      ..removeListener(_onCastTick)
      ..removeStatusListener(_onCastStatus)
      ..dispose();
    _strikeCtrl.dispose();
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
                  constraints.maxWidth / _arenaDesignWidth,
                  constraints.maxHeight / _arenaDesignHeight,
                );
                return ClipRect(
                  child: Center(
                    child: OverflowBox(
                      minWidth: _arenaDesignWidth,
                      maxWidth: _arenaDesignWidth,
                      minHeight: _arenaDesignHeight,
                      maxHeight: _arenaDesignHeight,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: _arenaDesignWidth,
                          height: _arenaDesignHeight,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(1),
                            ),
                            child: AnimatedBuilder(
                              animation: _model,
                              builder: (context, _) => _stage(),
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
}
