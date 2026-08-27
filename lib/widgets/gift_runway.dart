import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gift.dart';
import 'moe_icon.dart';

/// 直播风格左侧礼物跑道（与全屏 Lottie 分层；连送合并同一条）。
class GiftRunwayController {
  static final GiftRunwayController _instance = GiftRunwayController._();
  factory GiftRunwayController() => _instance;
  GiftRunwayController._();

  OverlayEntry? _entry;
  final GlobalKey<_GiftRunwayHostState> _hostKey = GlobalKey();

  static const mergeWindow = Duration(seconds: 3);
  static const maxVisible = 3;

  void push(
    OverlayState overlay, {
    required Gift gift,
    required int comboCount,
    String senderLabel = '我',
  }) {
    _ensureHost(overlay);
    void deliver() {
      _hostKey.currentState?.push(
        gift: gift,
        comboCount: comboCount,
        senderLabel: senderLabel,
      );
    }

    if (_hostKey.currentState != null) {
      deliver();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => deliver());
    }
  }

  void _ensureHost(OverlayState overlay) {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) => GiftRunwayHost(key: _hostKey, onEmpty: clear),
    );
    overlay.insert(_entry!);
  }

  void clear() {
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
  }
}

class GiftRunwayHost extends StatefulWidget {
  final VoidCallback onEmpty;

  const GiftRunwayHost({super.key, required this.onEmpty});

  @override
  State<GiftRunwayHost> createState() => _GiftRunwayHostState();
}

class _GiftRunwayHostState extends State<GiftRunwayHost> {
  final List<_RunwayItem> _items = [];

  void push({
    required Gift gift,
    required int comboCount,
    required String senderLabel,
  }) {
    final now = DateTime.now();
    for (final item in _items) {
      if (item.gift.id == gift.id &&
          now.difference(item.updatedAt) < GiftRunwayController.mergeWindow) {
        setState(() {
          item.comboCount = comboCount;
          item.updatedAt = now;
          item.bump();
        });
        return;
      }
    }

    final item = _RunwayItem(
      gift: gift,
      comboCount: comboCount,
      senderLabel: senderLabel,
      updatedAt: now,
    );
    setState(() {
      _items.insert(0, item);
      while (_items.length > GiftRunwayController.maxVisible) {
        _items.removeLast().dispose();
      }
    });
    item.scheduleDismiss(() {
      if (!mounted) return;
      setState(() {
        _items.remove(item);
        item.dispose();
      });
      if (_items.isEmpty) widget.onEmpty();
    });
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 72;
    return Positioned(
      left: 12,
      top: top,
      width: 220,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RunwayBanner(item: item),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunwayItem {
  final Gift gift;
  final String senderLabel;
  int comboCount;
  DateTime updatedAt;
  final ValueNotifier<int> pulse = ValueNotifier(0);
  Timer? _timer;

  _RunwayItem({
    required this.gift,
    required this.comboCount,
    required this.senderLabel,
    required this.updatedAt,
  });

  void bump() => pulse.value++;

  void scheduleDismiss(VoidCallback onDone) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 3200), onDone);
  }

  void dispose() {
    _timer?.cancel();
    pulse.dispose();
  }
}

class _RunwayBanner extends StatelessWidget {
  final _RunwayItem item;

  const _RunwayBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((-1 + t) * 36, 0),
            child: child,
          ),
        );
      },
      child: ValueListenableBuilder<int>(
        valueListenable: item.pulse,
        builder: (context, _, __) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: item.gift.color.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: item.gift.color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.gift.color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  // 礼物 emoji 缺失时的 🎁 占位改用统一 MoeIcon SVG；
                  // size 按原 fontSize 14×1.2 换算，白色在彩色圆底上清晰可读。
                  child: item.gift.emoji.isNotEmpty
                      ? Text(
                          item.gift.emoji,
                          style: const TextStyle(fontSize: 14),
                        )
                      : const MoeIcon(
                          name: 'gift',
                          size: 17,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: item.senderLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' 送出 '),
                        TextSpan(
                          text: item.gift.name,
                          style: TextStyle(
                            color: item.gift.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.comboCount > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    'x${item.comboCount}',
                    style: TextStyle(
                      color: item.gift.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
