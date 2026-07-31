import 'package:flutter/material.dart';

import '../models/gift.dart';
import 'live_gift_effect.dart';
import 'motion/lottie_motion_registry.dart';
import 'motion/moe_lottie_motion.dart';
import 'motion/moe_motion.dart';
import 'motion/moe_vfx_profile.dart';

/// Hybrid 全屏礼物动效：Lottie 氛围 + Flutter 文案；失败 / 无障碍降级 [LiveGiftEffect]。
class LottieGiftEffect extends StatefulWidget {
  final Gift gift;
  final int comboCount;
  final VoidCallback? onComplete;
  final Duration? duration;
  final MoeVfxProfile? vfxProfile;

  const LottieGiftEffect({
    super.key,
    required this.gift,
    this.comboCount = 1,
    this.onComplete,
    this.duration,
    this.vfxProfile,
  });

  @override
  State<LottieGiftEffect> createState() => _LottieGiftEffectState();
}

class _LottieGiftEffectState extends State<LottieGiftEffect>
    with SingleTickerProviderStateMixin {
  bool _useParticleFallback = false;
  bool _depsReady = false;
  late MoeVfxProfile _profile;
  late final AnimationController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _profile = widget.vfxProfile ?? MoeVfxProfile.fromContext(context);
    if (_profile.reduceMotion || moeReduceMotion(context)) {
      _useParticleFallback = true;
      return;
    }
    _labelController.forward();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _switchToFallback() {
    if (!mounted || _useParticleFallback) return;
    setState(() => _useParticleFallback = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_depsReady) return const SizedBox.shrink();

    if (_useParticleFallback) {
      return LiveGiftEffect(
        gift: widget.gift,
        comboCount: widget.comboCount,
        duration: widget.duration,
        vfxProfile: _profile,
        onComplete: widget.onComplete,
      );
    }

    final duration = _profile
        .scaledDuration(widget.duration ?? widget.gift.animationDuration);
    final asset = LottieMotionRegistry.giftBurstFor(widget.gift, _profile);
    final topInset = MediaQuery.paddingOf(context).top;

    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.15,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            if (widget.gift.level == GiftLevel.luxury &&
                _profile.enableLuxuryFlash)
              _LuxuryFlash(color: widget.gift.color, duration: duration),
            Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: MoeLottieMotion(
                  assetPath: asset,
                  duration: duration,
                  tintColor: widget.gift.color,
                  onComplete: widget.onComplete,
                  onError: _switchToFallback,
                ),
              ),
            ),
            if (widget.comboCount > 1)
              Positioned(
                top: topInset + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: _ComboBadge(count: widget.comboCount),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.sizeOf(context).height * 0.58,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _labelController,
                  curve: const Interval(0.35, 1, curve: Curves.easeOut),
                ),
                child: Center(
                  child: _GiftLabel(
                    name: widget.gift.name,
                    color: widget.gift.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryFlash extends StatefulWidget {
  final Color color;
  final Duration duration;

  const _LuxuryFlash({required this.color, required this.duration});

  @override
  State<_LuxuryFlash> createState() => _LuxuryFlashState();
}

class _LuxuryFlashState extends State<_LuxuryFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final flashMs =
        (widget.duration.inMilliseconds * 0.15).round().clamp(120, 400);
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: flashMs),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Opacity(
          opacity: (1 - t) * 0.45,
          child: ColoredBox(
            color: widget.color.withValues(alpha: 0.35),
          ),
        );
      },
    );
  }
}

class _ComboBadge extends StatelessWidget {
  final int count;
  const _ComboBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFFAD00)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '${count}x 连击',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _GiftLabel extends StatelessWidget {
  final String name;
  final Color color;
  const _GiftLabel({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}
