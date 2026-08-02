import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/moe_vfx_profile.dart';

enum PetJuiceKind { feed, care, sleep, farm, other }

class PetJuiceBurst {
  PetJuiceBurst({
    required this.id,
    required this.label,
    required this.color,
    required this.combo,
    required this.createdAt,
    required this.origin,
  });

  final int id;
  final String label;
  final Color color;
  final int combo;
  final DateTime createdAt;
  final Offset origin;
}

/// 照料「爽感」：连击窗口 + 飘字/粒子数据。表现层用 [PetCareJuiceOverlay]。
class PetCareJuiceController extends ChangeNotifier {
  static const comboWindow = Duration(seconds: 8);
  static const burstLife = Duration(milliseconds: 1400);

  final List<PetJuiceBurst> bursts = [];
  int streak = 0;
  DateTime? _lastAt;
  int _seq = 0;
  Timer? _pruneTimer;

  /// 下一次 register 将形成的连击数（用于收获结算加成）。
  int get nextCombo {
    final now = DateTime.now();
    if (_lastAt != null && now.difference(_lastAt!) <= comboWindow) {
      return streak + 1;
    }
    return 1;
  }

  /// 登记一次照料，返回当前连击数。
  int register(
    PetJuiceKind kind, {
    required String label,
    required Color color,
    Offset origin = const Offset(0.5, 0.42),
    MoeVfxProfile profile = MoeVfxProfile.standard,
  }) {
    final now = DateTime.now();
    if (_lastAt != null && now.difference(_lastAt!) <= comboWindow) {
      streak += 1;
    } else {
      streak = 1;
    }
    _lastAt = now;
    _seq += 1;
    bursts.add(
      PetJuiceBurst(
        id: _seq,
        label: streak > 1 ? '连击×$streak  $label' : label,
        color: color,
        combo: streak,
        createdAt: now,
        origin: origin,
      ),
    );
    if (bursts.length > 8) {
      bursts.removeRange(0, bursts.length - 8);
    }

    if (profile.enableHaptics) {
      final haptic = streak >= 3
          ? HapticFeedback.mediumImpact
          : HapticFeedback.lightImpact;
      unawaitedHaptic(haptic);
    }
    _ensurePruneTicker();
    notifyListeners();
    return streak;
  }

  void _ensurePruneTicker() {
    _pruneTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      prune();
      if (bursts.isEmpty) {
        _pruneTimer?.cancel();
        _pruneTimer = null;
      }
    });
  }

  void prune() {
    final now = DateTime.now();
    final before = bursts.length;
    bursts.removeWhere((b) => now.difference(b.createdAt) > burstLife);
    if (bursts.length != before) notifyListeners();
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    super.dispose();
  }

  static void unawaitedHaptic(Future<void> Function() fn) {
    try {
      // ignore: discarded_futures
      fn();
    } catch (_) {
      // 单测 / 无 binding 环境忽略触觉。
    }
  }
}

/// 叠在小家 GameWidget 上的飘字 + 轻粒子爆发。
class PetCareJuiceOverlay extends StatelessWidget {
  const PetCareJuiceOverlay({
    super.key,
    required this.controller,
    required this.profile,
  });

  final PetCareJuiceController controller;
  final MoeVfxProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        controller.prune();
        final bursts = List<PetJuiceBurst>.from(controller.bursts);
        if (bursts.isEmpty) return const SizedBox.shrink();
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final burst in bursts)
                _JuiceBurstView(
                  burst: burst,
                  profile: profile,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _JuiceBurstView extends StatefulWidget {
  const _JuiceBurstView({
    required this.burst,
    required this.profile,
  });

  final PetJuiceBurst burst;
  final MoeVfxProfile profile;

  @override
  State<_JuiceBurstView> createState() => _JuiceBurstViewState();
}

class _JuiceBurstViewState extends State<_JuiceBurstView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: PetCareJuiceController.burstLife,
    )..forward();
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    final rng = math.Random(widget.burst.id);
    final count = widget.profile.enableBurstParticles
        ? (widget.burst.combo >= 3 ? 14 : 8)
        : 0;
    final scale = widget.profile.particleScale;
    _particles = [
      for (var i = 0; i < count; i++)
        _Particle(
          angle: rng.nextDouble() * math.pi * 2,
          speed: (48 + rng.nextDouble() * 90) * scale,
          size: (4 + rng.nextDouble() * 5) * scale,
          hueShift: rng.nextDouble(),
        ),
    ];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final p = _t.value;
        final rise = 36 + 54 * p;
        final opacity = (1 - p).clamp(0.0, 1.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final ox = constraints.maxWidth * widget.burst.origin.dx;
            final oy = constraints.maxHeight * widget.burst.origin.dy;
            return Stack(
              children: [
                if (_particles.isNotEmpty)
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _ParticlePainter(
                      origin: Offset(ox, oy - rise * 0.15),
                      progress: p,
                      particles: _particles,
                      color: widget.burst.color,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: oy - rise,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: 0.92 + 0.18 * (1 - (p - 0.2).abs().clamp(0, 1)),
                      child: Text(
                        widget.burst.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.burst.color,
                          fontSize: widget.burst.combo >= 3 ? 26 : 22,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.9),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.hueShift,
  });

  final double angle;
  final double speed;
  final double size;
  final double hueShift;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.origin,
    required this.progress,
    required this.particles,
    required this.color,
  });

  final Offset origin;
  final double progress;
  final List<_Particle> particles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.speed * progress;
      final pos = Offset(
        origin.dx + math.cos(p.angle) * dist,
        origin.dy + math.sin(p.angle) * dist - 28 * progress,
      );
      final paint = Paint()
        ..color = Color.lerp(
          color,
          const Color(0xFFFFF3B0),
          p.hueShift * 0.45,
        )!
            .withValues(alpha: 0.85 * fade);
      canvas.drawCircle(pos, p.size * (1 - progress * 0.35), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
