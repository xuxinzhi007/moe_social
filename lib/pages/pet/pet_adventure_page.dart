import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../game/pet/pet_adventure_game.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/moe_loading.dart';

/// 小院试炼：可操作回合战（攻击 / 防御 / 必杀）。
class PetAdventurePage extends StatefulWidget {
  const PetAdventurePage({super.key});

  @override
  State<PetAdventurePage> createState() => _PetAdventurePageState();
}

class _PetAdventurePageState extends State<PetAdventurePage> {
  PetAdventureGame? _game;
  var _settling = false;
  String? _resultLine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final pet = context.read<PetProvider>();
    final p = pet.profile;
    final power = p.sport + p.labor + (p.mood ~/ 10);
    _game = PetAdventureGame(
      playerPower: power,
      stageLabel: '小院试炼',
      hatId: p.hatId,
      topId: p.topId,
      bottomId: p.bottomId,
      shoesId: p.shoesId,
    )
      ..onChanged = () {
        if (mounted) setState(() {});
      }
      ..onFinished = (win) {
        if (!mounted) return;
        setState(() {});
        unawaited(_onFightFinished(win));
      };
  }

  Future<void> _onFightFinished(bool win) async {
    if (_settling || !mounted) return;
    _settling = true;
    HapticFeedback.mediumImpact();
    final pet = context.read<PetProvider>();
    final ok = await pet.adventure(forcedWin: win);
    if (!mounted) return;
    setState(() {
      _resultLine = pet.lastMessage ?? (ok ? (win ? '胜利！' : '惜败') : '无法结算');
    });
  }

  void _act(PetAdventureAction action) {
    final game = _game;
    if (game == null || !game.playerTurn) return;
    final haptic = switch (action) {
      PetAdventureAction.attack => HapticFeedback.lightImpact,
      PetAdventureAction.guard => HapticFeedback.selectionClick,
      PetAdventureAction.skill => HapticFeedback.mediumImpact,
    };
    unawaited(haptic());
    game.perform(action);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(
        body: Center(child: MoeLoading()),
      );
    }
    final pet = context.watch<PetProvider>();
    final fighting = !game.finished;
    final myTurn = game.playerTurn;
    return Scaffold(
      backgroundColor: PetAdventureGame.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: PetAdventureGame.ink,
                      ),
                      const Expanded(
                        child: Text(
                          '小院试炼',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: PetAdventureGame.ink,
                          ),
                        ),
                      ),
                      _Pill(
                        label: '精力 ${pet.profile.energy.round()}',
                        color: const Color(0xFF5C9EAD),
                      ),
                      const SizedBox(width: 6),
                      _Pill(
                        label: '币 ${pet.profile.coins}',
                        color: const Color(0xFFD4A017),
                      ),
                    ],
                  ),
                ),
                if (fighting)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      myTurn ? '你的回合 · 快出手！' : '野怪行动中…',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: myTurn
                            ? PetAdventureGame.rose
                            : PetAdventureGame.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                const Spacer(),
                if (fighting)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: '攻击',
                            subtitle: '造成伤害',
                            color: PetAdventureGame.rose,
                            enabled: myTurn,
                            onTap: () => _act(PetAdventureAction.attack),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            label: '防御',
                            subtitle: '减伤一轮',
                            color: const Color(0xFF5C9EAD),
                            enabled: myTurn,
                            onTap: () => _act(PetAdventureAction.guard),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionBtn(
                            label: game.canSkill
                                ? '必杀'
                                : '必杀(${game.skillCooldown})',
                            subtitle: '高伤 · CD2',
                            color: const Color(0xFF7E8CE0),
                            enabled: myTurn && game.canSkill,
                            onTap: () => _act(PetAdventureAction.skill),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      children: [
                        if (_resultLine != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _resultLine!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: game.won == true
                                    ? PetAdventureGame.winGreen
                                    : PetAdventureGame.loseRose,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.maybePop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: PetAdventureGame.rose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '回小家',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
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
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withValues(alpha: 0.35);
    return Material(
      color: c.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: c,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
