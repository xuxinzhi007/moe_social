import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/farm/farm_game.dart';
import '../../models/farm_crop_config.dart';
import '../../models/farm_state.dart';
import '../../providers/farm_provider.dart';
import '../../providers/pet_provider.dart';

/// QQ 农场全屏页面（从宠物房间跳转进入）。
///
/// 交互约定（grilling 确认）：点击即触发 + 长按详情 + 种植弹种子选择。
class FarmPage extends StatefulWidget {
  const FarmPage({super.key});

  @override
  State<FarmPage> createState() => _FarmPageState();
}

class _FarmPageState extends State<FarmPage> {
  late final PetProvider _pet;
  late final FarmProvider _farm;
  late final FarmFlameGame _game;

  /// 待释放道具（点了「肥料」后，下一次点田块释放）。
  String? _pendingItem;

  @override
  void initState() {
    super.initState();
    _pet = Provider.of<PetProvider>(context, listen: false);
    _farm = FarmProvider(pet: _pet);
    _game = FarmFlameGame(
      onPlotTap: _onPlotTap,
      onPlotLongPress: _onPlotLongPress,
    );
    unawaited(_farm.load());
    _farm.addListener(_syncGame);
    _pet.addListener(_syncCoins);
  }

  @override
  void dispose() {
    _farm.removeListener(_syncGame);
    _pet.removeListener(_syncCoins);
    _farm.dispose();
    super.dispose();
  }

  void _syncGame() {
    if (!_game.isMounted) return;
    _game.syncState(_farm.state);
    if (mounted) setState(() {});
  }

  void _syncCoins() {
    if (!_game.isMounted) return;
    _game.hud.syncCoins(_pet.profile.coins);
  }

  // ------------------------------------------------------------- 交互

  void _onPlotTap(int index) {
    final state = _farm.state;
    final plot = state.plots[index];

    // 道具释放模式。
    if (_pendingItem == 'fertilizer') {
      setState(() => _pendingItem = null);
      if (_farm.useFertilizer(index)) {
        _game.playItemBoost(index, 'fertilizer');
      } else {
        _toast('这块地用不了肥料');
      }
      return;
    }

    if (plot.isEmpty) {
      _openSeedPicker(index);
      return;
    }
    if (plot.isRipe) {
      final result = _farm.harvestPlot(index);
      if (result == null) return;
      _game.playHarvest(
        index: index,
        coins: result.coins,
        mutation: result.mutation,
        tint: Color(result.config.tint),
      );
      _game.punchCombo(result.combo);
      if (result.isDailyFirst) _game.playDailyFirst();
      return;
    }
    // 生长中：浇水。
    final watered = _farm.waterPlot(index);
    if (watered != null) {
      _game.playWater(index);
    } else {
      _toast('浇水次数用完啦，等它长大吧');
    }
  }

  void _onPlotLongPress(int index) {
    final plot = _farm.state.plots[index];
    _showPlotDetail(plot);
  }

  // ------------------------------------------------------------- 弹层

  void _openSeedPicker(int index) {
    final bag = _farm.state.seedBag;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FarmSheet(
        title: '选择种子',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bag.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('背包里没有种子，去商店买一些吧',
                    style: TextStyle(color: Color(0xFF8A7B60))),
              ),
            for (final entry in bag.entries)
              _SeedRow(
                config: FarmCropConfig.byId(entry.key),
                count: entry.value,
                onPlant: () {
                  Navigator.pop(ctx);
                  final planted = _farm.plantSeed(index, entry.key);
                  if (planted != null) {
                    _game.playPlant(index, planted.config);
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openShop();
                },
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('去种子商店'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5FA052),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlotDetail(FarmPlot plot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FarmSheet(
        title: plot.isEmpty ? '空地' : plot.config.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plot.isEmpty)
              const Text('点击种植：从背包选一颗种子埋下去。',
                  style: TextStyle(color: Color(0xFF8A7B60), fontSize: 13)),
            if (!plot.isEmpty) ...[
              _DetailRow(
                label: '阶段',
                value: switch (plot.stage) {
                  FarmCropStage.seed => '发芽中',
                  FarmCropStage.sprout => '成长中',
                  FarmCropStage.ripe => '成熟待收',
                  FarmCropStage.empty => '-',
                },
              ),
              if (!plot.isRipe)
                _DetailRow(label: '剩余时间', value: plot.remainingLabel),
              _DetailRow(label: '浇水', value: '${plot.waterCount}/2 次'),
              _DetailRow(
                label: '收获可得',
                value: '${plot.config.harvestCoins} 金币'
                    '（变异/combo 有加成）',
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openShop() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _FarmSheet(
          title: '种子商店',
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('种子',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5FA052))),
                for (final c in FarmCropConfig.all)
                  _ShopRow(
                    title: c.label,
                    subtitle: '生长 ${_formatSeconds(c.totalSeconds)} · '
                        '收获 ${c.harvestCoins} 金币',
                    price: c.seedPrice,
                    tint: Color(c.tint),
                    owned: _farm.state.seedCountOf(c.id),
                    onBuy: () {
                      if (_farm.buySeed(c.id)) {
                        setSheetState(() {});
                      } else {
                        _toast('金币不够啦，先收点菜吧');
                      }
                    },
                  ),
                const SizedBox(height: 12),
                const Text('道具',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB08968))),
                for (final i in FarmItemConfig.all)
                  _ShopRow(
                    title: i.label,
                    subtitle: i.description,
                    price: i.price,
                    tint: Color(i.tint),
                    owned: _farm.state.itemCountOf(i.id),
                    onBuy: () {
                      if (_farm.buyItem(i.id)) {
                        setSheetState(() {});
                      } else {
                        _toast('金币不够啦，先收点菜吧');
                      }
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(double seconds) {
    final s = seconds.round();
    if (s < 60) return '$s秒';
    final m = s ~/ 60;
    if (m < 60) return '$m分钟';
    final h = m ~/ 60;
    return '$h小时';
  }

  void _onHarvestAll() {
    final results = _farm.harvestAll();
    if (results.isEmpty) return;
    var total = 0;
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      total += r.coins;
      // 错帧播放，形成「连续收割」节奏感。
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (!mounted || !_game.isMounted) return;
        _game.playHarvest(
          index: r.index,
          coins: r.coins,
          mutation: r.mutation,
          tint: Color(r.config.tint),
        );
        _game.punchCombo(r.combo);
        if (r.isDailyFirst) _game.playDailyFirst();
      });
    }
    Future.delayed(Duration(milliseconds: results.length * 90 + 120), () {
      if (!mounted || !_game.isMounted) return;
      _game.playHarvestAll(total, results.length);
    });
  }

  void _useSunshine() {
    if (_farm.useSunshine()) {
      _game.playItemBoost(null, 'sunshine');
    } else if (_farm.state.itemCountOf('sunshine') <= 0) {
      _toast('没有阳光瓶，去商店看看');
    } else {
      _toast('田里暂时没有在长的作物');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1400),
      behavior: SnackBarBehavior.floating,
      width: 260,
    ));
  }

  // ------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    final ripe = _farm.loaded ? _farm.state.ripeCount : 0;
    final fertilizerCount = _farm.state.itemCountOf('fertilizer');
    final sunshineCount = _farm.state.itemCountOf('sunshine');

    return Scaffold(
      backgroundColor: const Color(0xFF7FBF6E),
      body: Stack(
        children: [
          GameWidget(game: _game, loadingBuilder: (_) => const SizedBox()),
          // 顶栏：返回 + 标题。
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '萌农场',
                    style: TextStyle(
                      color: Color(0xFF4A7A3F),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 右侧道具按钮列。
          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 96,
            child: Column(
              children: [
                _CircleButton(
                  icon: Icons.local_florist_rounded,
                  badge: fertilizerCount,
                  highlight: _pendingItem == 'fertilizer',
                  onTap: () {
                    if (fertilizerCount <= 0) {
                      _toast('没有肥料，去商店买');
                      return;
                    }
                    setState(() {
                      _pendingItem =
                          _pendingItem == 'fertilizer' ? null : 'fertilizer';
                    });
                    if (_pendingItem != null) {
                      _toast('点击一块生长中的田释放肥料');
                    }
                  },
                ),
                const SizedBox(height: 10),
                _CircleButton(
                  icon: Icons.wb_sunny_rounded,
                  badge: sunshineCount,
                  onTap: _useSunshine,
                ),
                const SizedBox(height: 10),
                _CircleButton(
                  icon: Icons.storefront_rounded,
                  onTap: _openShop,
                ),
              ],
            ),
          ),
          // 底部中央：一键全收（≥1 块成熟才出现）。
          if (ripe > 0)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _onHarvestAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE97891),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.eco_rounded),
                  label: Text(ripe > 1 ? '一键全收 ($ripe)' : '收获'),
                ),
              ),
            ),
          // 肥料待释放提示。
          if (_pendingItem == 'fertilizer')
            Positioned(
              top: MediaQuery.paddingOf(context).top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xE6B08968),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '点击田块释放肥料',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 组件

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.highlight = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0xFFB08968)
                  : Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: highlight ? Colors.white : const Color(0xFF5FA052),
              size: 24,
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE97891),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FarmSheet extends StatelessWidget {
  const _FarmSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0x338A7B60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4A7A3F),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _SeedRow extends StatelessWidget {
  const _SeedRow({
    required this.config,
    required this.count,
    required this.onPlant,
  });

  final FarmCropConfig config;
  final int count;
  final VoidCallback onPlant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(config.tint).withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Color(config.tint),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      title: Text(config.label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('背包 ×$count · 收获 ${config.harvestCoins} 金币'),
      trailing: FilledButton(
        onPressed: onPlant,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5FA052),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: const Text('种下'),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8A7B60), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.tint,
    required this.owned,
    required this.onBuy,
  });

  final String title;
  final String subtitle;
  final int price;
  final Color tint;
  final int owned;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration:
                BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
        ),
      ),
      title: Text(
        owned > 0 ? '$title（已有 ×$owned）' : title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A7B60))),
      trailing: OutlinedButton(
        onPressed: onBuy,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB8860B),
          side: const BorderSide(color: Color(0xFFE5C878)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text('$price 币'),
      ),
    );
  }
}
