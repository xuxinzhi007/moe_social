import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../../auth_service.dart';
import '../../game/battle/battle_stage_game.dart';
import '../../models/battle_room.dart';
import '../../models/gift.dart';
import '../../providers/battle_room_provider.dart';
import '../../services/gift_catalog_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/gift_animation_manager.dart';
import '../../widgets/gift_icon_widget.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class LivePkRoomPage extends StatefulWidget {
  const LivePkRoomPage({super.key, required this.roomId});
  final String roomId;
  @override
  State<LivePkRoomPage> createState() => _LivePkRoomPageState();
}

class _LivePkRoomPageState extends State<LivePkRoomPage> {
  late final BattleRoomProvider _provider;
  late final BattleStageGame _stage;
  final Map<String, Gift> _giftCatalog = {};
  String? _animatedEventId;
  BattleSide _selectedSide = BattleSide.left;
  double? _balance;
  @override
  void initState() {
    super.initState();
    _provider = BattleRoomProvider(widget.roomId)..load();
    _stage = BattleStageGame();
    _provider.addListener(_playLatestGiftEvent);
    _loadBalance();
  }

  @override
  void dispose() {
    _provider.removeListener(_playLatestGiftEvent);
    _provider.dispose();
    super.dispose();
  }

  void _playLatestGiftEvent() {
    final event = _provider.latestGiftEvent;
    if (!mounted ||
        event == null ||
        event.id.isEmpty ||
        event.id == _animatedEventId) {
      return;
    }
    _animatedEventId = event.id;
    final gift = _giftCatalog[event.giftId] ??
        Gift(
          id: event.giftId,
          name: event.giftName,
          icon: event.giftIcon,
          emoji: event.giftIcon.isEmpty ? '🎁' : event.giftIcon,
          description: '',
          price: 10,
          color: Gift.colorForCategory(GiftCategory.special),
          category: GiftCategory.special,
        );
    _stage.spawn(
      event.side,
      elite:
          event.quantity >= 3 || gift.level.index >= GiftLevel.advanced.index,
      label: event.giftName,
    );
    final overlay = GiftAnimationManager.resolveRootOverlay(context);
    if (overlay == null) {
      return;
    }
    GiftAnimationManager().showOnOverlay(
      overlay,
      gift,
      comboCount: event.quantity,
      comboKey:
          '${widget.roomId}:${event.side.apiValue}:${event.senderUserId}:${event.giftId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<BattleRoomProvider>(
        builder: (context, value, _) {
          if (value.loading) return const Scaffold(body: MoeLoading());
          if (value.error != null && value.room == null) {
            return Scaffold(
              appBar: AppBar(),
              body: MoeErrorState.fromError(value.error, onRetry: value.load),
            );
          }
          final room = value.room!;
          return Scaffold(
            backgroundColor: const Color(0xFF10121F),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: Text('礼物 PK  ·  #${widget.roomId}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                _LiveBadge(connected: value.connected),
                const SizedBox(width: 12),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  children: [
                    _Scoreboard(room: room, remaining: value.remaining),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: GameWidget(game: _stage),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _BattleStatus(room: room, event: value.latestGiftEvent),
                    const SizedBox(height: 14),
                    _GiftDock(
                      room: room,
                      selectedSide: _selectedSide,
                      sending: value.sending,
                      onSelectSide: (side) =>
                          setState(() => _selectedSide = side),
                      onSend: () => _choose(context, value, _selectedSide),
                      onRestart: () =>
                          Navigator.of(context).pushReplacementNamed('/battle'),
                      balance: _balance,
                      onLike: () => _stage.addLike(side: _selectedSide),
                    ),
                    if (room.isFinished) ...[
                      const SizedBox(height: 14),
                      _Result(room: room),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _choose(BuildContext context, BattleRoomProvider provider,
      BattleSide side) async {
    final gifts = await GiftCatalogService.fetch(
      viewerUserId: AuthService.currentUser,
    );
    if (!context.mounted) return;
    final gift = await showModalBottomSheet<Gift>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftPickerSheet(
        gifts: gifts,
        balance: _balance,
        recipient: side == BattleSide.left
            ? provider.room!.left.userName
            : provider.room!.right.userName,
      ),
    );
    if (gift == null || !context.mounted) {
      return;
    }
    _giftCatalog[gift.id] = gift;
    try {
      await provider.send(side, gift.id);
      await _loadBalance();
    } catch (_) {
      if (context.mounted) {
        MoeToast.error(context, '送礼失败，请检查余额后重试');
      }
    }
  }

  Future<void> _loadBalance() async {
    try {
      final user = await AuthService.getUserInfo(forceRefresh: true);
      if (mounted) setState(() => _balance = user.balance);
    } catch (_) {
      // The room remains usable if the wallet request is temporarily unavailable.
    }
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.room, required this.remaining});
  final BattleRoom room;
  final Duration remaining;
  @override
  Widget build(BuildContext context) {
    final total =
        (room.leftScore.score + room.rightScore.score).clamp(1, 1 << 62);
    final left = room.leftScore.score / total;
    final leftLeading = room.leftScore.score >= room.rightScore.score;
    final clock =
        '${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF29243F), Color(0xFF171A2B)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 12))
        ],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.local_fire_department_rounded,
              color: MoeTokens.pastelOrange, size: 18),
          const SizedBox(width: 6),
          Text(room.isRunning ? '礼物对战进行中' : '本局已结束',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 12),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99)),
              child: Text(room.isFinished ? '已结算' : clock,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2))),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _ParticipantCard(
                  participant: room.left,
                  score: room.leftScore.score,
                  tint: MoeTokens.pastelPink,
                  leading: leftLeading)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS',
                  style: TextStyle(
                      color: Colors.white54, fontWeight: FontWeight.w800))),
          Expanded(
              child: _ParticipantCard(
                  participant: room.right,
                  score: room.rightScore.score,
                  tint: MoeTokens.pastelBlue,
                  leading: !leftLeading)),
        ]),
        const SizedBox(height: 20),
        ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
                height: 12,
                child: Row(children: [
                  Expanded(
                      flex: (left * 1000).round().clamp(1, 999),
                      child: const ColoredBox(color: MoeTokens.pastelPink)),
                  Expanded(
                      flex: ((1 - left) * 1000).round().clamp(1, 999),
                      child: const ColoredBox(color: MoeTokens.pastelBlue)),
                ]))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${room.leftScore.score} 能量',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${room.rightScore.score} 能量',
              style: const TextStyle(color: Colors.white70, fontSize: 12))
        ]),
      ]),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: (connected ? MoeTokens.success : MoeTokens.warning)
              .withValues(alpha: .16),
          borderRadius: BorderRadius.circular(99)),
      child: Row(children: [
        Icon(Icons.circle,
            size: 8, color: connected ? MoeTokens.success : MoeTokens.warning),
        const SizedBox(width: 6),
        Text(connected ? 'LIVE' : '重连中',
            style: TextStyle(
                color: connected
                    ? const Color(0xFF9BE7A0)
                    : const Color(0xFFFFC078),
                fontSize: 12,
                fontWeight: FontWeight.w700))
      ]));
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard(
      {required this.participant,
      required this.score,
      required this.tint,
      required this.leading});
  final BattleParticipant participant;
  final int score;
  final Color tint;
  final bool leading;
  @override
  Widget build(BuildContext context) => Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
              radius: 34,
              backgroundColor: tint.withValues(alpha: .22),
              backgroundImage: participant.avatarUrl.trim().isNotEmpty
                  ? NetworkImage(participant.avatarUrl)
                  : null,
              child: participant.avatarUrl.trim().isEmpty
                  ? Text(participant.userName.characters.first,
                      style: TextStyle(
                          color: tint,
                          fontSize: 24,
                          fontWeight: FontWeight.w800))
                  : null),
          if (leading)
            Positioned(
                right: -12,
                top: -4,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: tint, borderRadius: BorderRadius.circular(99)),
                    child: const Text('领先',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 8),
        Text(participant.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('$score',
            style: TextStyle(
                color: tint, fontSize: 24, fontWeight: FontWeight.w900)),
      ]);
}

class _BattleStatus extends StatelessWidget {
  const _BattleStatus({required this.room, required this.event});
  final BattleRoom room;
  final BattleGiftEvent? event;
  @override
  Widget build(BuildContext context) {
    final message = event == null
        ? '等待观众送出第一份礼物'
        : '${event!.side.label}收到 ${event!.giftName} ×${event!.quantity}';
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
            color: const Color(0xFF1C2034),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.bolt_rounded, color: MoeTokens.pastelOrange),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600))),
          Text('第 ${room.lastEventSeq} 条',
              style: const TextStyle(color: Colors.white38, fontSize: 11))
        ]));
  }
}

class _GiftDock extends StatelessWidget {
  const _GiftDock(
      {required this.room,
      required this.selectedSide,
      required this.sending,
      required this.onSelectSide,
      required this.onSend,
      required this.onRestart,
      required this.balance,
      required this.onLike});
  final BattleRoom room;
  final BattleSide selectedSide;
  final bool sending;
  final ValueChanged<BattleSide> onSelectSide;
  final VoidCallback onSend;
  final VoidCallback onRestart;
  final double? balance;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF1C2034),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('为谁加油？',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          const Icon(Icons.account_balance_wallet_outlined,
              color: MoeTokens.pastelOrange, size: 16),
          const SizedBox(width: 5),
          Text(balance == null ? '余额加载中' : '心意 ${balance!.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFFFFD68A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
              child: _SideButton(
                  label: room.left.userName,
                  tint: MoeTokens.pastelPink,
                  selected: selectedSide == BattleSide.left,
                  onTap: () => onSelectSide(BattleSide.left))),
          const SizedBox(width: 8),
          Expanded(
              child: _SideButton(
                  label: room.right.userName,
                  tint: MoeTokens.pastelBlue,
                  selected: selectedSide == BattleSide.right,
                  onTap: () => onSelectSide(BattleSide.right))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: room.isRunning ? onLike : null,
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('点赞召唤'))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: FilledButton.icon(
                  onPressed: room.isRunning && !sending ? onSend : onRestart,
                  icon: Icon(room.isRunning
                      ? Icons.card_giftcard_rounded
                      : Icons.restart_alt_rounded),
                  label: Text(room.isRunning
                      ? (sending ? '礼物发送中…' : '选择礼物并送出')
                      : '返回大厅，再开一局'))),
        ]),
      ]));
}

class _SideButton extends StatelessWidget {
  const _SideButton(
      {required this.label,
      required this.tint,
      required this.selected,
      required this.onTap});
  final String label;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
          duration: MoeTokens.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: .20)
                  : Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? tint : Colors.transparent)),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 17, color: tint),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)))
          ])));
}

class _GiftPickerSheet extends StatefulWidget {
  const _GiftPickerSheet({
    required this.gifts,
    required this.balance,
    required this.recipient,
  });

  final List<Gift> gifts;
  final double? balance;
  final String recipient;

  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet> {
  Gift? _selected;

  @override
  Widget build(BuildContext context) {
    final available =
        widget.gifts.where((gift) => gift.canSendViaBackendApi).toList();
    final canSend = _selected != null &&
        (_selected!.ownedQuantity > 0 ||
            widget.balance == null ||
            _selected!.price <= widget.balance!);
    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .48,
      maxChildSize: .92,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF171A2B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                const Text('选择礼物',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                const Icon(Icons.account_balance_wallet_rounded,
                    color: MoeTokens.pastelOrange, size: 18),
                const SizedBox(width: 6),
                Text(
                    widget.balance == null
                        ? '余额加载中'
                        : '心意 ${widget.balance!.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFFFFD68A), fontWeight: FontWeight.w700)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.favorite_rounded,
                    color: MoeTokens.pastelPink, size: 17),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('将礼物送给 ${widget.recipient}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)))
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: available.isEmpty
                  ? const Center(
                      child: Text('暂无可送礼物',
                          style: TextStyle(color: Colors.white54)))
                  : GridView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: .78),
                      itemCount: available.length,
                      itemBuilder: (_, index) {
                        final gift = available[index];
                        final affordable = gift.ownedQuantity > 0 ||
                            widget.balance == null ||
                            gift.price <= widget.balance!;
                        final selected = _selected?.id == gift.id;
                        return InkWell(
                          onTap: affordable
                              ? () => setState(() => _selected = gift)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: MoeTokens.motionFast,
                            padding: const EdgeInsets.symmetric(
                                vertical: 7, horizontal: 4),
                            decoration: BoxDecoration(
                                color: selected
                                    ? gift.color.withValues(alpha: .22)
                                    : Colors.white.withValues(alpha: .05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: selected
                                        ? gift.color
                                        : Colors.transparent)),
                            child: Opacity(
                                opacity: affordable ? 1 : .42,
                                child: Column(children: [
                                  GiftIconWidget(gift: gift, size: 42),
                                  const SizedBox(height: 5),
                                  Text(gift.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                      gift.ownedQuantity > 0
                                          ? '背包 x${gift.ownedQuantity}'
                                          : '${gift.price.toStringAsFixed(0)} 心意',
                                      style: TextStyle(
                                          color: gift.ownedQuantity > 0
                                              ? MoeTokens.pastelTeal
                                              : const Color(0xFFFFD68A),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ])),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: .08)))),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSend
                        ? () => Navigator.pop(context, _selected)
                        : null,
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: Text(_selected == null
                        ? '选择一份礼物'
                        : (_selected!.ownedQuantity > 0
                            ? '从背包送出 ${_selected!.name}'
                            : '送出 ${_selected!.name} · ${_selected!.price.toStringAsFixed(0)} 心意')),
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.room});
  final BattleRoom room;
  @override
  Widget build(BuildContext context) {
    final text = room.winnerSide == null
        ? '本局平局'
        : room.winnerSide == BattleSide.left
            ? '${room.left.userName} 获胜'
            : '${room.right.userName} 获胜';
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFF29243F),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.emoji_events_rounded,
              color: MoeTokens.pastelOrange, size: 28),
          const SizedBox(width: 12),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800))
        ]));
  }
}
