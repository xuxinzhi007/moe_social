import 'arena_view_model.dart';

/// 战斗出牌队列的一次界面更新。
///
/// [duration] 非空时，页面用这个时长播放出手动画。
/// [rebuild] 为真时，队列变了但模型没有通知，页面需要自己刷新。
class ArenaCastUpdate {
  const ArenaCastUpdate({this.duration, this.rebuild = false});

  final Duration? duration;
  final bool rebuild;

  static const none = ArenaCastUpdate();
}

/// 星辉战斗的出牌队列与连携时机。
///
/// 伤害结算仍在 [ArenaViewModel.playCard]。这里只决定哪张牌何时结算，
/// 以及出手动画该播多久。页面持有动画控制器，按 [ArenaCastUpdate] 播放。
class ArenaBattleCast {
  ArenaBattleCast(this.model);

  final ArenaViewModel model;

  static const singleCast = Duration(milliseconds: 880);
  static const comboCast = Duration(milliseconds: 1280);

  final List<ArenaCard> playQueue = <ArenaCard>[];
  final List<ArenaCard> pendingQueue = <ArenaCard>[];
  final List<ArenaCard> comboCards = <ArenaCard>[];

  bool comboSlam = false;
  bool comboResolved = false;
  bool muteStrike = false;
  int comboImpact = 0;
  int seenStrikeId = 0;
  ArenaCard? castCard;
  int castTarget = 0;
  bool castCommitted = false;

  /// 模型打出新一击时返回 true，页面再播打击动画。连携结算期间静音。
  bool takeStrike() {
    if (muteStrike) return false;
    final strike = model.strike;
    if (strike == null || strike.id == seenStrikeId) return false;
    seenStrikeId = strike.id;
    return true;
  }

  ArenaCastUpdate onHandTap(int index, {required bool animating}) {
    if (model.finished || animating) return ArenaCastUpdate.none;
    if (index < 0 || index >= model.hand.length) return ArenaCastUpdate.none;
    final card = model.hand[index];
    final queuedAt = playQueue.indexWhere((entry) => identical(entry, card));
    if (queuedAt >= 0) {
      final onlyCard = playQueue.length == 1;
      if (onlyCard && card.targeting != ArenaCardTargeting.singleEnemy) {
        return confirmQueue(animating: animating);
      }
      playQueue.removeAt(queuedAt);
      return const ArenaCastUpdate(rebuild: true);
    }
    if (model.energy < card.cost) {
      model.playCard(index);
      return ArenaCastUpdate.none;
    }
    final queuedCost = playQueue.fold<int>(0, (sum, entry) => sum + entry.cost);
    if (model.energy < queuedCost + card.cost) {
      model.noteBattle('能量不够把「${card.name}」连进去');
      return ArenaCastUpdate.none;
    }
    playQueue.add(card);
    return const ArenaCastUpdate(rebuild: true);
  }

  ArenaCastUpdate onEnemyTap(int index, {required bool animating}) {
    if (animating) return ArenaCastUpdate.none;
    model.selectEnemy(index);
    if (playQueue.isEmpty) return ArenaCastUpdate.none;
    return confirmQueue(animating: false);
  }

  ArenaCastUpdate confirmQueue({required bool animating}) {
    if (playQueue.isEmpty || animating) return ArenaCastUpdate.none;
    if (playQueue.length >= 2) return _beginComboCast();
    comboSlam = false;
    pendingQueue
      ..clear()
      ..addAll(playQueue);
    playQueue.clear();
    return _castNextQueued();
  }

  void onCastTick(double value) {
    if (comboSlam) {
      if (!comboResolved && value >= .74) {
        comboResolved = true;
        _resolveCombo();
      }
      return;
    }
    final card = castCard;
    if (card == null) return;
    if (!castCommitted && value >= .42) {
      castCommitted = true;
      final index = model.hand.indexWhere((entry) => identical(entry, card));
      if (index >= 0) model.playCard(index);
    }
  }

  ArenaCastUpdate onCastCompleted() {
    if (!comboSlam && pendingQueue.isNotEmpty) return _castNextQueued();
    castCard = null;
    comboSlam = false;
    comboResolved = false;
    comboImpact = 0;
    comboCards.clear();
    return const ArenaCastUpdate(rebuild: true);
  }

  void clearQueues() {
    playQueue.clear();
    pendingQueue.clear();
    comboCards.clear();
    comboSlam = false;
    comboResolved = false;
    comboImpact = 0;
  }

  ArenaCastUpdate _beginComboCast() {
    comboSlam = true;
    comboResolved = false;
    comboImpact = 0;
    comboCards
      ..clear()
      ..addAll(playQueue);
    playQueue.clear();
    pendingQueue.clear();
    castCard = null;
    castTarget = model.selectedEnemyIndex;
    return const ArenaCastUpdate(duration: comboCast, rebuild: true);
  }

  void _resolveCombo() {
    final before = <int>[
      for (var index = 0; index < ArenaViewModel.enemyCount; index++)
        model.enemyHpAt(index),
    ];
    final playerBefore = model.playerHp;
    muteStrike = true;
    for (final card in comboCards) {
      final index = model.hand.indexWhere((entry) => identical(entry, card));
      if (index >= 0) model.playCard(index);
    }
    muteStrike = false;
    final strike = model.strike;
    if (strike != null) seenStrikeId = strike.id;
    var dealt = 0;
    for (var index = 0; index < before.length; index++) {
      dealt += before[index] - model.enemyHpAt(index);
    }
    final healed = model.playerHp - playerBefore;
    comboImpact = dealt > 0 ? dealt : (healed > 0 ? -healed : 0);
  }

  ArenaCastUpdate _castNextQueued() {
    if (pendingQueue.isEmpty) return ArenaCastUpdate.none;
    final card = pendingQueue.removeAt(0);
    final index = model.hand.indexWhere((entry) => identical(entry, card));
    if (index < 0) return _castNextQueued();
    return _beginCast(index);
  }

  ArenaCastUpdate _beginCast(int index) {
    final card = model.hand[index];
    castCommitted = false;
    castCard = card;
    castTarget = model.selectedEnemyIndex;
    return const ArenaCastUpdate(duration: singleCast, rebuild: true);
  }
}
