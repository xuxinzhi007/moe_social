import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gift.dart';
import 'motion/category_particle_vfx.dart';
import 'motion/gift_particle_system.dart';
import 'motion/gift_vfx_layout.dart';
import 'motion/moe_vfx_profile.dart';

/// 直播级全屏礼物动效（比例坐标 + Alignment，自适应任意屏幕）。
class LiveGiftEffect extends StatefulWidget {
  final Gift gift;
  final int comboCount;
  final VoidCallback? onComplete;
  final Duration? duration;
  final MoeVfxProfile? vfxProfile;

  const LiveGiftEffect({
    super.key,
    required this.gift,
    this.comboCount = 1,
    this.onComplete,
    this.duration,
    this.vfxProfile,
  });

  @override
  State<LiveGiftEffect> createState() => _LiveGiftEffectState();
}

class _LiveGiftEffectState extends State<LiveGiftEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final GiftParticleEngine _engine;
  late MoeVfxProfile _profile;

  bool _initialized = false;
  bool _impactEmitted = false;
  bool _rainEmitted = false;
  double _lastTrailAt = 0;
  double _lastAmbientAt = 0;

  static const _anchorNorm = GiftVfxLayout.anchorNorm;
  static const _flyStartNorm = GiftVfxLayout.flyStartNorm;

  @override
  void initState() {
    super.initState();
    _engine = GiftParticleEngine(seed: widget.gift.id.hashCode);
    _controller = AnimationController(vsync: this);
    _controller.addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _profile = widget.vfxProfile ?? MoeVfxProfile.fromContext(context);
    _controller.duration = _profile.scaledDuration(
      widget.duration ?? widget.gift.animationDuration,
    );
    _controller.forward().then((_) => widget.onComplete?.call());
  }

  void _onTick() {
    final t = _controller.value;
    final flyT = Curves.easeOutCubic.transform((t / 0.22).clamp(0.0, 1.0));
    final flyPos = GiftVfxLayout.lerpNorm(_flyStartNorm, _anchorNorm, flyT);

    if (t < 0.22 && t > 0.02) {
      final step = (flyT * 12).floor();
      if (step > (_lastTrailAt * 12).floor()) {
        _engine.emitTrail(
          normFrom: flyPos - const Offset(0, 0.02),
          normTo: flyPos,
          count: _trailCount(4),
          color: widget.gift.color,
        );
        _lastTrailAt = flyT;
      }
    }

    if (t >= 0.20 && !_impactEmitted) {
      _impactEmitted = true;
      _emitImpact();
    }

    if (t >= 0.25 && t < 0.78 && (t - _lastAmbientAt) > 0.06) {
      _engine.emitAmbient(
        normCenter: _anchorNorm,
        count: _ambientCount(3),
        color: widget.gift.color,
        normRadius: 0.1,
      );
      _lastAmbientAt = t;
    }

    if (widget.gift.level == GiftLevel.luxury &&
        t >= 0.22 &&
        !_rainEmitted &&
        !_profile.reduceMotion) {
      _rainEmitted = true;
      _engine.emitRain(
        count: _rainCount(18),
        color: widget.gift.color,
        category: widget.gift.category,
      );
    }
  }

  void _emitImpact() {
    final dominant = _dominantShape(widget.gift.category);
    final burst = _burstCount();
    final isHigh = widget.gift.level.index >= GiftLevel.advanced.index;

    _engine.emitBurst(
      normOrigin: _anchorNorm,
      count: burst,
      color: widget.gift.color,
      speedMax: isHigh ? 0.65 : 0.5,
      sizeMax: isHigh ? 0.022 : 0.018,
      dominantShape: dominant,
    );
    _engine.emitShockwave(
      normCenter: _anchorNorm,
      normRadius: 0.1,
      color: widget.gift.color,
    );
    if (widget.gift.level.index >= GiftLevel.medium.index) {
      _engine.emitBurst(
        normOrigin: _anchorNorm,
        count: (burst * 0.4).round(),
        color: Colors.white.withValues(alpha: 0.9),
        speedMin: 0.08,
        speedMax: 0.28,
        sizeMin: 0.003,
        sizeMax: 0.01,
        dominantShape: GiftParticleShape.star,
        gravityY: 0.15,
      );
    }
  }

  GiftParticleShape _dominantShape(GiftCategory category) {
    return switch (CategoryParticleVfx.dominantShape(category)) {
      2 => GiftParticleShape.heart,
      1 => GiftParticleShape.star,
      3 => GiftParticleShape.diamond,
      _ => GiftParticleShape.circle,
    };
  }

  double _displayBoost() => switch (widget.gift.level) {
        GiftLevel.basic => 1.75,
        GiftLevel.medium => 1.4,
        GiftLevel.advanced => 1.2,
        GiftLevel.luxury => 1.1,
      };

  double _iconSize(Size canvas) =>
      widget.gift.iconSize *
      _profile.layoutScale *
      _displayBoost() *
      (math.min(canvas.width, canvas.height) / 400).clamp(0.85, 1.35);

  Alignment _giftAlignment(double t) {
    final flyT = Curves.easeOutCubic.transform((t / 0.22).clamp(0.0, 1.0));
    final norm = t < 0.22
        ? GiftVfxLayout.lerpNorm(_flyStartNorm, _anchorNorm, flyT)
        : _anchorNorm;
    // 弧线抬高
    final lift = t < 0.22 ? -0.06 * math.sin(flyT * math.pi) : 0.0;
    return GiftVfxLayout.toAlignment(Offset(norm.dx, norm.dy + lift));
  }

  int _burstCount() {
    final base = widget.gift.particleCount;
    return (_profile.enableBurstParticles
            ? (base * _profile.particleScale * _displayBoost()).round()
            : (base * 0.5 * _displayBoost()).round())
        .clamp(12, 80);
  }

  int _trailCount(int base) =>
      (_profile.reduceMotion ? 0 : base * _profile.particleScale).round().clamp(0, 8);

  int _ambientCount(int base) =>
      (_profile.reduceMotion ? 0 : base).clamp(0, 6);

  int _rainCount(int base) =>
      _profile.tier == MoeVfxTier.low ? 0 : (base * _profile.particleScale).round();

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = GiftVfxLayout.resolveSize(context, constraints);
        final topInset = MediaQuery.paddingOf(context).top;
        final iconSize = _iconSize(canvas);

        return SizedBox(
          width: canvas.width > 0 ? canvas.width : null,
          height: canvas.height > 0 ? canvas.height : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final opacity =
                  t < 0.82 ? 1.0 : ((1.0 - t) / 0.18).clamp(0.0, 1.0);
              final alignment = _giftAlignment(t);
              final floatBob = t >= 0.22 && t <= 0.65
                  ? math.sin((t - 0.22) / 0.43 * math.pi) * -8
                  : 0.0;
              final scale = t < 0.22
                  ? 0.2 + Curves.easeOutBack.transform(t / 0.22) * 0.95
                  : t < 0.82
                      ? 1.15
                      : 1.15 - (t - 0.82) / 0.18 * 0.25;
              final pulse = t >= 0.22 && t < 0.82
                  ? 0.5 + math.sin((t - 0.22) * math.pi * 4) * 0.5
                  : 0.0;
              final coreConverge = t < 0.22 ? t / 0.22 : 1.0;
              final corePoints = CategoryParticleVfx.shapePoints(
                widget.gift.category,
                (_profile.scaledCoreCount(20 + widget.gift.level.index * 8) *
                        _displayBoost())
                    .round()
                    .clamp(12, 48),
              );

              return Opacity(
                opacity: opacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.1),
                            radius: 1.15,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.gift.level == GiftLevel.luxury &&
                        _profile.enableLuxuryFlash &&
                        t < 0.15)
                      IgnorePointer(
                        child: Opacity(
                          opacity: (1 - t / 0.15) * 0.5,
                          child: ColoredBox(
                            color: widget.gift.color.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: GiftParticleLayer(
                        engine: _engine,
                        running: t < 0.95,
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
                    // Align + 比例定位：任意屏幕尺寸自动居中
                    Positioned.fill(
                      child: Align(
                        alignment: alignment,
                        child: Transform.translate(
                          offset: Offset(0, floatBob),
                          child: Transform.scale(
                            scale: scale,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                if (pulse > 0.1)
                                  Container(
                                    width: iconSize * 2.2,
                                    height: iconSize * 2.2,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          widget.gift.color
                                              .withValues(alpha: 0.35 * pulse),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                if (corePoints.isNotEmpty)
                                  CustomPaint(
                                    painter: CategoryParticleClusterPainter(
                                      targets: corePoints,
                                      primaryColor: widget.gift.color,
                                      secondaryColor: widget.gift.color
                                          .withValues(alpha: 0.6),
                                      converge: coreConverge,
                                      pulse: pulse,
                                      expand: t >= 0.22
                                          ? (t - 0.22) / 0.3
                                          : 0,
                                      seed: widget.gift.id.hashCode,
                                      dominantShape:
                                          CategoryParticleVfx.dominantShape(
                                        widget.gift.category,
                                      ),
                                    ),
                                    size: Size(iconSize * 1.3, iconSize * 1.3),
                                  ),
                                Positioned(
                                  bottom: -iconSize * 0.5,
                                  child: Opacity(
                                    opacity: t > 0.35
                                        ? ((t - 0.35) / 0.2).clamp(0.0, 1.0)
                                        : 0,
                                    child: _GiftLabel(
                                      name: widget.gift.name,
                                      color: widget.gift.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
