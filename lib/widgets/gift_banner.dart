import 'dart:async';
import 'package:flutter/material.dart';
import '../models/gift.dart';
import 'optimized_gift_animation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GiftBannerManager — singleton queue for receive-side banners
// ─────────────────────────────────────────────────────────────────────────────

class GiftBannerManager {
  static final GiftBannerManager _instance = GiftBannerManager._internal();
  factory GiftBannerManager() => _instance;
  GiftBannerManager._internal();

  final List<OverlayEntry> _entries = [];
  double _nextTopOffset = 0;

  static const double _bannerHeight = 56.0;
  static const double _bannerSpacing = 8.0;
  static const double _topPadding = 60.0; // safe area / status bar

  /// Show a gift received banner. Pass [senderName], [senderAvatar],
  /// [gift]. If [gift.price >= 50] also triggers a luxury full-screen rain.
  void showBanner(
    BuildContext context, {
    required String senderName,
    required String? senderAvatar,
    required Gift gift,
  }) {
    OverlayState? overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (_) {
      return;
    }

    final myTop = _topPadding + _nextTopOffset;
    _nextTopOffset += _bannerHeight + _bannerSpacing;
    if (_nextTopOffset > (_bannerHeight + _bannerSpacing) * 5) {
      _nextTopOffset = 0;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GiftBannerWidget(
        senderName: senderName,
        senderAvatar: senderAvatar,
        gift: gift,
        topOffset: myTop,
        onDismissed: () {
          try {
            entry.remove();
          } catch (_) {}
          _entries.remove(entry);
          if (_entries.isEmpty) _nextTopOffset = 0;
        },
      ),
    );
    _entries.add(entry);
    overlay.insert(entry);

    // Luxury: also show gift rain
    if (gift.price >= 50) {
      _showLuxuryRain(overlay, gift);
    }
  }

  void _showLuxuryRain(OverlayState overlay, Gift gift) {
    late OverlayEntry rainEntry;
    rainEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _LuxuryRainOverlay(
          gift: gift,
          onComplete: () {
            try {
              rainEntry.remove();
            } catch (_) {}
          },
        ),
      ),
    );
    overlay.insert(rainEntry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GiftBannerWidget
// ─────────────────────────────────────────────────────────────────────────────

class _GiftBannerWidget extends StatefulWidget {
  final String senderName;
  final String? senderAvatar;
  final Gift gift;
  final double topOffset;
  final VoidCallback onDismissed;

  const _GiftBannerWidget({
    required this.senderName,
    required this.senderAvatar,
    required this.gift,
    required this.topOffset,
    required this.onDismissed,
  });

  @override
  State<_GiftBannerWidget> createState() => _GiftBannerWidgetState();
}

class _GiftBannerWidgetState extends State<_GiftBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4)),
    );

    _controller.forward();

    _dismissTimer = Timer(
      const Duration(milliseconds: 3000),
      _dismissBanner,
    );
  }

  void _dismissBanner() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Positioned(
      top: widget.topOffset,
      right: 12,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buildCard(screenW),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(double screenW) {
    final maxWidth = screenW * 0.72;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.gift.color.withValues(alpha: 0.92),
            widget.gift.color.withValues(alpha: 0.75),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: widget.gift.color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.senderName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          const Text('送出了', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            widget.gift.emoji,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.gift.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.senderAvatar != null && widget.senderAvatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(widget.senderAvatar!),
        backgroundColor: Colors.white24,
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white24,
      child: Text(
        widget.senderName.isNotEmpty
            ? widget.senderName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Luxury rain overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LuxuryRainOverlay extends StatefulWidget {
  final Gift gift;
  final VoidCallback onComplete;

  const _LuxuryRainOverlay({required this.gift, required this.onComplete});

  @override
  State<_LuxuryRainOverlay> createState() => _LuxuryRainOverlayState();
}

class _LuxuryRainOverlayState extends State<_LuxuryRainOverlay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GiftRainWidget(
        gifts: [widget.gift],
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
