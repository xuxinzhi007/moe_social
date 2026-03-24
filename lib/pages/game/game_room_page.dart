import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/moe_toast.dart';
import '../../models/game_room.dart';
import '../../providers/game_provider.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;

  const GameRoomPage({super.key, required this.roomId});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> with TickerProviderStateMixin {
  BetOption? _myBigSmallBet;
  BetOption? _myColorBet;
  double _bigSmallAmount = 10;
  double _colorAmount = 10;
  bool _showMyBets = false;

  final List<_FakeBet> _liveBets = [];
  final Random _random = Random();
  Timer? _fakeBetTimer;

  static const _fakeNames = [
    '樱桃兔', '星空猫', '泡泡鱼', '糖果熊', '彩虹羊', '蜂蜜猫', '薄荷兔', '月光狼',
    '草莓熊', '奶茶鸟', '棉花糖', '小橘猫',
  ];
  static const _betAmounts = [5.0, 10.0, 20.0, 50.0, 100.0];

  @override
  void initState() {
    super.initState();
    final provider = context.read<GameProvider>();
    final room = provider.rooms[widget.roomId]!;
    _bigSmallAmount = room.minBet;
    _colorAmount = room.minBet;
    _startFakeBets();
  }

  void _startFakeBets() {
    _fakeBetTimer?.cancel();
    _fakeBetTimer = Timer.periodic(
      Duration(milliseconds: 600 + _random.nextInt(1400)),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final provider = context.read<GameProvider>();
        final room = provider.rooms[widget.roomId];
        if (room == null || room.phase != GamePhase.betting) return;

        if (_liveBets.length >= 15) {
          _liveBets.removeAt(0); // 移除最旧的，防止无限增长
        }
        final options = BetOption.values;
        setState(() {
          _liveBets.add(_FakeBet(
            name: _fakeNames[_random.nextInt(_fakeNames.length)],
            option: options[_random.nextInt(options.length)],
            amount: _betAmounts[_random.nextInt(_betAmounts.length)],
          ));
        });
      },
    );
  }

  void _placeBet(GameProvider provider) {
    if (_myBigSmallBet == null && _myColorBet == null) {
      MoeToast.error(context, '请先选择大小或颜色');
      return;
    }
    HapticFeedback.lightImpact();
    provider.placeBet(widget.roomId, _myBigSmallBet, _bigSmallAmount, _myColorBet, _colorAmount);
    MoeToast.success(context, '下注成功，等待开奖！');
    
    // 清空本地选择状态（可选，让用户知道下注成功且已重置）
    setState(() {
      _myBigSmallBet = null;
      _myColorBet = null;
    });
  }

  @override
  void dispose() {
    _fakeBetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final room = provider.rooms[widget.roomId];
        if (room == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _showMyBets = !_showMyBets);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: _showMyBets ? const Color(0xFF7F7FD5).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showMyBets ? const Color(0xFF7F7FD5) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: _showMyBets ? const Color(0xFF7F7FD5) : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '我的记录',
                        style: TextStyle(
                            color: _showMyBets ? const Color(0xFF7F7FD5) : Colors.white70,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 背景装饰
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F7FD5).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFF86A8E7).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              _showMyBets ? _buildMyBetsView(provider) : _buildGameView(provider, room),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameView(GameProvider provider, GameRoomState room) {
    return Column(
      children: [
        _buildTopBar(room, provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_liveBets.isNotEmpty) ...[
                  _buildLiveBetsScroll(),
                  const SizedBox(height: 16),
                ],
                _buildBetPanel(provider, room),
                const SizedBox(height: 16),
                if (room.history.isNotEmpty) _buildHistoryRow(room),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(GameRoomState room, GameProvider provider) {
    final isUrgent = room.countdown <= 5 && room.phase == GamePhase.betting;
    final hasBet = provider.hasBet(room.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF16213E), const Color(0xFF0F3460)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          // 倒计时圆圈
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7F7FD5).withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: room.phase == GamePhase.betting ? room.countdown / room.totalTime : 0,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUrgent ? Colors.redAccent : Colors.white,
                  ),
                  strokeWidth: 3,
                ),
                room.phase == GamePhase.betting
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${room.countdown}',
                            style: TextStyle(
                              color: isUrgent ? Colors.redAccent : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('秒',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      )
                    : const Icon(Icons.hourglass_bottom_rounded, color: Colors.white70, size: 24),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: room.phase == GamePhase.result && room.currentResult != null
                ? _buildResultChip(room.currentResult!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.phase == GamePhase.betting
                            ? '第 ${room.roundNumber} 局 · 下注中'
                            : '第 ${room.roundNumber} 局 · 开奖中...',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasBet ? '已下注，等待开奖结果' : '选好后点击确认下注',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
          if (room.phase == GamePhase.result && room.roundProfit != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: room.roundProfit >= 0 ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: room.roundProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Text(
                '${room.roundProfit >= 0 ? '+' : ''}¥${room.roundProfit.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: room.roundProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultChip(int result) {
    final isBig = result >= 6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBig
              ? [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)]
              : [const Color(0xFF91EAE4), const Color(0xFF7F7FD5)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isBig ? const Color(0xFF7F7FD5).withOpacity(0.4) : const Color(0xFF91EAE4).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$result',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isBig ? '大 · 红' : '小 · 黑',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBetsScroll() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _liveBets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = _liveBets[_liveBets.length - 1 - i]; // 最新在最前
          final color = _optionColor(b.option);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  b.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '押${_optionLabel(b.option)}',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '¥${b.amount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBetPanel(GameProvider provider, GameRoomState room) {
    final hasBet = provider.hasBet(room.id);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF16213E), const Color(0x8016213E)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBetGroupRow('大 / 小', [BetOption.big, BetOption.small],
              _myBigSmallBet, (o) => setState(() => _myBigSmallBet = o), hasBet),
          const SizedBox(height: 12),
          _buildAmountRow(_bigSmallAmount, (v) => setState(() => _bigSmallAmount = v), room.minBet, hasBet),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.white.withOpacity(0.2), Colors.transparent],
              ),
            ),
          ),

          _buildBetGroupRow('红 / 黑', [BetOption.red, BetOption.black],
              _myColorBet, (o) => setState(() => _myColorBet = o), hasBet),
          const SizedBox(height: 12),
          _buildAmountRow(_colorAmount, (v) => setState(() => _colorAmount = v), room.minBet, hasBet),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (hasBet || room.phase != GamePhase.betting) ? null : () => _placeBet(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                shadowColor: const Color(0xFF7F7FD5).withOpacity(0.5),
                elevation: 8,
              ),
              child: Text(
                hasBet
                    ? '已下注 · 等待开奖'
                    : room.phase != GamePhase.betting
                        ? '开奖中...'
                        : '确认下注',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetGroupRow(String label, List<BetOption> options, BetOption? selected, ValueChanged<BetOption?> onSelect, bool hasBet) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        const SizedBox(width: 16),
        ...options.map((opt) {
          final isSelected = selected == opt;
          final color = _optionColor(opt);
          return GestureDetector(
            onTap: hasBet ? null : () {
              HapticFeedback.lightImpact();
              onSelect(isSelected ? null : opt);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.25) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : [],
              ),
              child: Text(
                _optionLabel(opt),
                style: TextStyle(
                  color: isSelected ? color : Colors.white38,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAmountRow(double value, ValueChanged<double> onChanged, double minBet, bool hasBet) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('金额', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: value.clamp(minBet, minBet * 100),
            min: minBet,
            max: minBet * 100,
            divisions: 99,
            activeColor: const Color(0xFF7F7FD5),
            inactiveColor: Colors.white12,
            thumbColor: const Color(0xFF7F7FD5),
            onChanged: hasBet ? null : onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7F7FD5).withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '¥${value.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryRow(GameRoomState room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('最近开奖', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: room.history.take(12).map((r) {
            final isBig = (r.result ?? 0) >= 6;
            final color = isBig ? const Color(0xFF7F7FD5) : const Color(0xFF86A8E7);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${r.result} ${isBig ? '大' : '小'}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMyBetsView(GameProvider provider) {
    final bets = provider.myBetHistory;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF16213E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('总局数', '${bets.length}', const Color(0xFF86A8E7)),
              _buildStatItem(
                  '盈亏',
                  '${bets.fold(0.0, (s, b) => s + b.profit) >= 0 ? '+' : ''}¥${bets.fold(0.0, (s, b) => s + b.profit).toStringAsFixed(2)}',
                  bets.fold(0.0, (s, b) => s + b.profit) >= 0 ? Colors.greenAccent : Colors.redAccent),
              _buildStatItem('胜场', '${bets.where((b) => b.profit > 0).length}', Colors.greenAccent),
            ],
          ),
        ),
        Expanded(
          child: bets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.casino_outlined, color: Colors.white24, size: 48),
                      SizedBox(height: 12),
                      Text('本次暂无下注记录', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: bets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _buildBetRecordCard(bets[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildBetRecordCard(MyBetRecord b) {
    final isBig = b.result >= 6;
    final won = b.profit > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (won ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (won ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              won ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: won ? Colors.greenAccent : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(b.roomName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('第 ${b.roundNumber} 局', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (b.bigSmall != null) '${_optionLabel(b.bigSmall!)} ¥${b.bigSmallAmount.toStringAsFixed(0)}',
                    if (b.color != null) '${_optionLabel(b.color!)} ¥${b.colorAmount.toStringAsFixed(0)}',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${b.result} · ${isBig ? '大/红' : '小/黑'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${b.profit >= 0 ? '+' : ''}¥${b.profit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: won ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _optionLabel(BetOption opt) {
    switch (opt) {
      case BetOption.big: return '大';
      case BetOption.small: return '小';
      case BetOption.red: return '红';
      case BetOption.black: return '黑';
    }
  }

  Color _optionColor(BetOption opt) {
    switch (opt) {
      case BetOption.big: return const Color(0xFF86A8E7);
      case BetOption.small: return const Color(0xFF91EAE4);
      case BetOption.red: return const Color(0xFFFF6B6B);
      case BetOption.black: return Colors.white60;
    }
  }
}

class _FakeBet {
  final String name;
  final BetOption option;
  final double amount;
  _FakeBet({required this.name, required this.option, required this.amount});
}
