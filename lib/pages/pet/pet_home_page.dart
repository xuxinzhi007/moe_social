import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/feature_flags.dart';
import '../../game/pet/pet_adventure_game.dart';
import '../../game/pet/pet_labels.dart';
import '../../game/pet/pet_room_game.dart';
import '../../models/pet_state.dart';
import '../../providers/pet_provider.dart';
import '../../services/pet_career_config.dart';
import 'pet_dressing_page.dart';

/// 养成主页：Flame Room + 照料 HUD + 九宫格（P0–P4）。
class PetHomePage extends StatefulWidget {
  const PetHomePage({super.key});

  @override
  State<PetHomePage> createState() => _PetHomePageState();
}

class _PetHomePageState extends State<PetHomePage> {
  static const _hintPrefsKey = 'pet_home_move_hint_dismissed_v1';

  late final PetRoomGame _game;
  PetProvider? _pet;
  var _ownsProvider = false;
  var _bootstrapped = false;
  var _decorateMode = false;
  int? _selectedFurn;
  var _showMoveHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _game = PetRoomGame(
      onFurnitureMoved: (index, x, y, rotation, scale) {
        _pet?.moveFurniture(
          index,
          x,
          y,
          rotation: rotation,
          scale: scale,
        );
      },
      onFurnitureSelected: (index) {
        if (!mounted) return;
        setState(() => _selectedFurn = index);
      },
      onActorMoved: (x, y) {
        _dismissMoveHint();
        _pet?.moveActor(x, y);
      },
    );
  }

  void _setDecorateMode(bool on) {
    setState(() {
      _decorateMode = on;
      if (!on) _selectedFurn = null;
    });
    _game.setDecorateMode(on);
    if (on) _dismissMoveHint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    PetProvider? existing;
    try {
      existing = Provider.of<PetProvider>(context, listen: false);
    } catch (_) {
      existing = null;
    }
    if (existing != null) {
      _pet = existing;
    } else {
      _pet = PetProvider();
      _ownsProvider = true;
    }
    _pet!.addListener(_onPet);
    _pet!.load().then((_) {
      if (!mounted) return;
      _game.syncProfile(_pet!.profile);
      _maybeShowMoveHint();
    });
  }

  PetProvider get pet => _pet!;

  Future<void> _maybeShowMoveHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hintPrefsKey) == true) return;
    if (!mounted) return;
    setState(() => _showMoveHint = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 5), _dismissMoveHint);
  }

  Future<void> _dismissMoveHint() async {
    _hintTimer?.cancel();
    if (!_showMoveHint) return;
    if (mounted) setState(() => _showMoveHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hintPrefsKey, true);
  }

  void _onPet() {
    if (!mounted || _pet == null) return;
    _game.syncProfile(pet.profile);
    setState(() {});
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pet?.removeListener(_onPet);
    if (_ownsProvider) _pet?.dispose();
    super.dispose();
  }

  Future<void> _feed() async {
    await pet.feed();
    _game.playCareFx('喂食 +');
  }

  Future<void> _care() async {
    await pet.care();
    _game.playCareFx('陪伴 ♥');
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MoreGrid(
        onDress: () {
          Navigator.pop(ctx);
          _showDressSheet();
        },
        onFurniture: () {
          Navigator.pop(ctx);
          _showFurnitureSheet();
        },
        onSchool: () {
          Navigator.pop(ctx);
          _showSchoolSheet();
        },
        onWork: () async {
          Navigator.pop(ctx);
          await pet.work();
          _toast();
        },
        onSocial: () {
          Navigator.pop(ctx);
          _showSocialSheet();
        },
        onAdventure: () {
          Navigator.pop(ctx);
          _openAdventure();
        },
        onShop: () {
          Navigator.pop(ctx);
          _showShopSheet();
        },
        onIap: () async {
          Navigator.pop(ctx);
          await pet.purchaseIapPlaceholder();
          _toast();
        },
      ),
    );
  }

  void _toast() {
    final msg = pet.lastMessage;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 统一可滚动半屏弹层，避免 Column 溢出。
  Future<T?> _showScrollSheet<T>({
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.86;
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: maxH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDressSheet() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: pet,
          child: const PetDressingPage(),
        ),
      ),
    );
  }

  void _showFurnitureSheet() {
    const catalog = <(String id, String asset)>[
      ('bed_cozy', 'assets/pet/furniture/bed_basic.png'),
      ('table_wood', 'assets/pet/furniture/table_wood.png'),
      ('lamp_soft', 'assets/pet/furniture/lamp_basic.png'),
      ('rug_heart', 'assets/pet/furniture/rug_basic.png'),
      ('window_lace', 'assets/pet/furniture/window_lace.png'),
    ];
    _showScrollSheet(
      title: '布置家具',
      children: [
        Text(
          '点选添加后布置：拖动 · 四角缩放 · 顶柄旋转。'
          '每房间最多 ${PetFurniture.maxPerScene} 件，同款最多 ${PetFurniture.maxSameIdPerScene} 件。',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: [
            for (final e in catalog)
              InkWell(
                onTap: () async {
                  final before = pet.profile.furniture.length;
                  await pet.placeFurniture(
                    PetFurniture(
                      id: e.$1,
                      x: 0.5,
                      y: 0.62,
                      scene: pet.profile.sceneId,
                    ),
                  );
                  if (!mounted) return;
                  _toast();
                  if (pet.profile.furniture.length <= before) return;
                  Navigator.pop(context);
                  final idx = pet.profile.furniture.length - 1;
                  _setDecorateMode(true);
                  setState(() => _selectedFurn = idx);
                  _game.selectFurniture(idx);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x22000000)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          e.$2,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.chair_rounded, size: 40),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PetLabels.of(e.$1),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _setDecorateMode(true);
          },
          icon: const Icon(Icons.open_with_rounded),
          label: const Text('进入布置模式（调整已有家具）'),
        ),
      ],
    );
  }

  Widget _decorateBar() {
    final idx = _selectedFurn;
    String title = '布置：拖动 · 四角缩放 · 顶柄旋转';
    if (idx != null &&
        idx >= 0 &&
        idx < pet.profile.furniture.length) {
      final f = pet.profile.furniture[idx];
      title =
          '${PetLabels.of(f.id)} · ${f.rotation}° · ${(f.scale * 100).round()}%';
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33E97891)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE97891).withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF5A4638),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DecorToolBtn(
                    icon: Icons.zoom_out_map_rounded,
                    label: '缩小',
                    onTap: () => _game.scaleSelected(-0.08),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DecorToolBtn(
                    icon: Icons.zoom_in_rounded,
                    label: '放大',
                    onTap: () => _game.scaleSelected(0.08),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DecorToolBtn(
                    icon: Icons.rotate_right_rounded,
                    label: '转90°',
                    onTap: () => _game.rotateSelected(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (idx != null)
                  Expanded(
                    child: _DecorToolBtn(
                      icon: Icons.delete_outline_rounded,
                      label: '移除',
                      tint: const Color(0xFFE57373),
                      fill: const Color(0xFFFFEBEE),
                      onTap: () async {
                        await pet.removeFurniture(idx);
                        setState(() => _selectedFurn = null);
                        _game.selectFurniture(null);
                      },
                    ),
                  ),
                if (idx != null) const SizedBox(width: 8),
                Expanded(
                  child: _DecorToolBtn(
                    icon: Icons.check_rounded,
                    label: '完成',
                    tint: const Color(0xFF5C6BC0),
                    fill: const Color(0xFFE8EAF6),
                    onTap: () => _setDecorateMode(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSchoolSheet() async {
    final cfg = await PetCareerConfig.load();
    if (!mounted) return;
    final p = pet.profile;
    await _showScrollSheet(
      title: '学校 · ${p.ageYears}岁',
      children: [
        Text(
          '德${p.virtue}  智${p.intel}  体${p.sport}  美${p.art}  劳${p.labor}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _PetSheetAction(
          icon: Icons.cake_rounded,
          label: '过生日（年龄+1）',
          tint: const Color(0xFFFF8A65),
          fill: const Color(0xFFFFF3E0),
          onTap: () async {
            await pet.ageUp();
            if (mounted) Navigator.pop(context);
            _toast();
          },
        ),
        const SizedBox(height: 14),
        const Text('课程', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final s in cfg.subjects) ...[
          _PetSheetAction(
            icon: Icons.menu_book_rounded,
            label: '上${s.name}课',
            onTap: () async {
              await pet.study(s.id);
              if (mounted) Navigator.pop(context);
              _toast();
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        const Text('职场', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final j in cfg.jobs) ...[
          _PetSheetAction(
            icon: Icons.work_outline_rounded,
            label: '${j.name}（+${j.basePay}）',
            tint: const Color(0xFF5C6BC0),
            fill: const Color(0xFFE8EAF6),
            onTap: () async {
              await pet.work(jobId: j.id);
              if (mounted) Navigator.pop(context);
              _toast();
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _showSocialSheet() {
    final friendCtrl = TextEditingController();
    _showScrollSheet(
      title: '社交 / 结婚',
      children: [
        Text(
          '好友：${pet.profile.friends.isEmpty ? '暂无' : pet.profile.friends.join('、')}',
        ),
        Text(
          '配偶：${pet.profile.spouseId.isEmpty ? '未婚' : pet.profile.spouseId}'
          '　宝宝：${pet.profile.hasBaby ? '有' : '无'}',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: friendCtrl,
          decoration: const InputDecoration(
            labelText: '好友 / 配偶 ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _PetSheetAction(
          icon: Icons.person_add_alt_1_rounded,
          label: '加好友',
          onTap: () async {
            final id = friendCtrl.text.trim();
            if (id.isEmpty) return;
            await pet.addFriend(id);
            if (mounted) Navigator.pop(context);
            _toast();
          },
        ),
        const SizedBox(height: 8),
        _PetSheetAction(
          icon: Icons.favorite_rounded,
          label: '求婚结婚',
          tint: const Color(0xFFE97891),
          fill: const Color(0xFFFFE4EC),
          onTap: () async {
            final id = friendCtrl.text.trim();
            if (id.isEmpty) return;
            await pet.marry(id);
            if (mounted) Navigator.pop(context);
            _toast();
          },
        ),
        const SizedBox(height: 8),
        _PetSheetAction(
          icon: Icons.child_care_rounded,
          label: '生子',
          tint: const Color(0xFFFF8A65),
          fill: const Color(0xFFFFF3E0),
          onTap: () async {
            await pet.haveBaby();
            if (mounted) Navigator.pop(context);
            _toast();
          },
        ),
        const SizedBox(height: 12),
        const Text(
          '合规：未成年人社交规则由产品侧另行配置；当前为内测简化闭环。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  void _showShopSheet() {
    const items = ['hat_crown', 'top_hoodie', 'bed_cozy', 'lamp_soft'];
    _showScrollSheet(
      title: '商店 · ${pet.profile.coins} 币',
      children: [
        for (final id in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(PetLabels.of(id)),
            subtitle: const Text('40 币'),
            onTap: () async {
              await pet.buySoft(id);
              if (mounted) Navigator.pop(context);
              _toast();
            },
          ),
      ],
    );
  }

  Future<void> _openAdventure() async {
    final power = pet.profile.sport +
        pet.profile.labor +
        (pet.profile.mood ~/ 10);
    final adv = PetAdventureGame(playerPower: power);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF2E3A4A),
          appBar: AppBar(
            title: const Text('轻冒险'),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              GameWidget(game: adv),
              Positioned(
                left: 16,
                right: 16,
                bottom: 28,
                child: ElevatedButton(
                  onPressed: () async {
                    await pet.adventure();
                    if (mounted) {
                      Navigator.pop(context);
                      _toast();
                    }
                  },
                  child: const Text('结算并返回'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.petLifeSim) {
      return const Scaffold(body: Center(child: Text('养成域未开启')));
    }
    if (_pet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = pet.profile;
    return ChangeNotifierProvider.value(
      value: pet,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: _game),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: const Color(0xFF5A4638),
                        ),
                        Expanded(
                          child: Text(
                            '${p.name}的小家',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF5A4638),
                            ),
                          ),
                        ),
                        _CoinPill(coins: p.coins),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SceneTabs(
                      sceneId: p.sceneId,
                      onSelect: pet.setScene,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: FractionallySizedBox(
                        widthFactor: 0.48,
                        child: _StatusBars(profile: p),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_decorateMode) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _decorateBar(),
                    ),
                  ] else ...[
                    if (_showMoveHint)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: _dismissMoveHint,
                          child: Text(
                            '拖角色可在房间走动 · 布置模式调家具',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5A4638).withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                    if (pet.lastMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              pet.lastMessage!,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    _CareBar(
                      busy: pet.busy,
                      onFeed: _feed,
                      onCare: _care,
                      onMore: _openMore,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (!pet.loaded)
              const ColoredBox(
                color: Color(0x55FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SceneTabs extends StatelessWidget {
  const _SceneTabs({required this.sceneId, required this.onSelect});

  final String sceneId;
  final ValueChanged<String> onSelect;

  static const _items = [
    (id: 'living', label: '客厅', icon: Icons.weekend_rounded),
    (id: 'yard', label: '院子', icon: Icons.park_rounded),
    (id: 'bedroom', label: '卧室', icon: Icons.bed_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33E8A0B0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC48B9A).withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _SceneTab(
                label: item.label,
                icon: item.icon,
                selected: sceneId == item.id,
                onTap: () => onSelect(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SceneTab extends StatelessWidget {
  const _SceneTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFE4EC) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFFE97891)
                    : const Color(0xFF8A7364),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF5A4638)
                      : const Color(0xFF8A7364),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/pet/ui/coin.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Text('🪙'),
          ),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusBars extends StatelessWidget {
  const _StatusBars({required this.profile});
  final PetProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _bar('饱食', profile.hunger, const Color(0xFFFF8A65)),
        _bar('精力', profile.energy, const Color(0xFF4FC3F7)),
        _bar('心情', profile.mood, const Color(0xFFF06292)),
      ],
    );
  }

  Widget _bar(String label, double v, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (v / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.white54,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareBar extends StatelessWidget {
  const _CareBar({
    required this.busy,
    required this.onFeed,
    required this.onCare,
    required this.onMore,
  });

  final bool busy;
  final VoidCallback onFeed;
  final VoidCallback onCare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _CareBtn(
              icon: Icons.restaurant_rounded,
              label: '喂食',
              tint: const Color(0xFFFFB74D),
              fill: const Color(0xFFFFF3E0),
              onTap: busy ? null : onFeed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CareBtn(
              icon: Icons.favorite_rounded,
              label: '陪伴',
              tint: const Color(0xFFE97891),
              fill: const Color(0xFFFFE4EC),
              onTap: busy ? null : onCare,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CareBtn(
              icon: Icons.grid_view_rounded,
              label: '更多',
              tint: const Color(0xFF8E7CC3),
              fill: const Color(0xFFF0E9FF),
              onTap: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareBtn extends StatelessWidget {
  const _CareBtn({
    required this.icon,
    required this.label,
    required this.tint,
    required this.fill,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              fill,
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tint, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF5A4638),
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
}

class _DecorToolBtn extends StatelessWidget {
  const _DecorToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = const Color(0xFFE97891),
    this.fill = const Color(0xFFFFE4EC),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetSheetAction extends StatelessWidget {
  const _PetSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint = const Color(0xFF7E57C2),
    this.fill = const Color(0xFFF3E5F5),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF5A4638),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tint.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreGrid extends StatelessWidget {
  const _MoreGrid({
    required this.onDress,
    required this.onFurniture,
    required this.onSchool,
    required this.onWork,
    required this.onSocial,
    required this.onAdventure,
    required this.onShop,
    required this.onIap,
  });

  final VoidCallback onDress;
  final VoidCallback onFurniture;
  final VoidCallback onSchool;
  final VoidCallback onWork;
  final VoidCallback onSocial;
  final VoidCallback onAdventure;
  final VoidCallback onShop;
  final VoidCallback onIap;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.checkroom_rounded, '换衣间', onDress),
      (Icons.chair_rounded, '布置', onFurniture),
      (Icons.school_rounded, '学校', onSchool),
      (Icons.work_rounded, '打工', onWork),
      (Icons.people_rounded, '社交', onSocial),
      (Icons.sports_martial_arts_rounded, '冒险', onAdventure),
      (Icons.storefront_rounded, '商店', onShop),
      (Icons.card_giftcard_rounded, '内购', onIap),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('更多', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final it in items)
                  InkWell(
                    onTap: it.$3,
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFFFE8EE),
                          child: Icon(it.$1, color: const Color(0xFFE97891)),
                        ),
                        const SizedBox(height: 6),
                        Text(it.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
