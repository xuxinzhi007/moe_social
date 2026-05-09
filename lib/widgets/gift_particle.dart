import 'dart:math' as math;
import 'package:flutter/material.dart';

class OptimizedParticle {
  Offset position;
  Offset velocity;
  double life;
  double maxLife;
  Color color;
  double size;

  OptimizedParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    this.size = 4.0,
  })  : maxLife = life;

  void update(double deltaTime, {double gravity = 0.5}) {
    position += velocity * deltaTime * 60;
    velocity += Offset(0, gravity * deltaTime * 60);
    life -= deltaTime;
  }

  bool get isAlive => life > 0;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);

  void reset({
    required Offset position,
    required Offset velocity,
    required double life,
    required Color color,
    double size = 4.0,
  }) {
    this.position = position;
    this.velocity = velocity;
    this.life = life;
    this.maxLife = life;
    this.color = color;
    this.size = size;
  }
}

class ParticlePool {
  final List<OptimizedParticle> _pool = [];
  final List<OptimizedParticle> _activeParticles = [];
  final int maxPoolSize;

  ParticlePool({this.maxPoolSize = 100});

  OptimizedParticle? acquire() {
    if (_pool.isNotEmpty) {
      final particle = _pool.removeLast();
      _activeParticles.add(particle);
      return particle;
    }
    if (_activeParticles.length < maxPoolSize) {
      final particle = OptimizedParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        life: 1.0,
        color: Colors.white,
      );
      _activeParticles.add(particle);
      return particle;
    }
    return null;
  }

  void release(OptimizedParticle particle) {
    if (_activeParticles.contains(particle)) {
      _activeParticles.remove(particle);
      if (_pool.length < maxPoolSize) {
        _pool.add(particle);
      }
    }
  }

  void releaseAll() {
    _pool.addAll(_activeParticles);
    _activeParticles.clear();
  }

  List<OptimizedParticle> get activeParticles => List.unmodifiable(_activeParticles);

  int get poolSize => _pool.length;
  int get activeCount => _activeParticles.length;
}

class OptimizedParticleSystem extends StatefulWidget {
  final Color color;
  final int particleCount;
  final double size;
  final Duration duration;
  final double gravity;
  final Offset spawnCenter;
  final double spawnRadius;

  const OptimizedParticleSystem({
    super.key,
    required this.color,
    this.particleCount = 20,
    this.size = 200,
    this.duration = const Duration(milliseconds: 1500),
    this.gravity = 0.5,
    this.spawnCenter = Offset.zero,
    this.spawnRadius = 100,
  });

  @override
  State<OptimizedParticleSystem> createState() => _OptimizedParticleSystemState();
}

class _OptimizedParticleSystemState extends State<OptimizedParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ParticlePool _pool = ParticlePool();
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _spawnParticles();

    _controller.forward();
    _controller.addListener(_updateParticles);
  }

  void _spawnParticles() {
    for (int i = 0; i < widget.particleCount; i++) {
      final particle = _pool.acquire();
      if (particle == null) break;

      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = _random.nextDouble() * widget.spawnRadius;
      final position = Offset(
        widget.spawnCenter.dx + math.cos(angle) * distance,
        widget.spawnCenter.dy + math.sin(angle) * distance,
      );

      final speed = _random.nextDouble() * 3 + 1;
      final velocity = Offset(
        (_random.nextDouble() - 0.5) * 4,
        -(_random.nextDouble() * 3 + speed),
      );

      particle.reset(
        position: position,
        velocity: velocity,
        life: _random.nextDouble() * 0.5 + 0.5,
        color: widget.color,
        size: _random.nextDouble() * 2 + 2,
      );
    }
  }

  void _updateParticles() {
    setState(() {
      final deltaTime = 0.016;
      final toRemove = <OptimizedParticle>[];

      for (final particle in _pool.activeParticles) {
        particle.update(deltaTime, gravity: widget.gravity);
        if (!particle.isAlive) {
          toRemove.add(particle);
        }
      }

      for (final particle in toRemove) {
        _pool.release(particle);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pool.releaseAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: OptimizedParticlePainter(
        particles: _pool.activeParticles,
        progress: _controller.value,
        center: Offset(widget.size / 2, widget.size / 2),
      ),
      size: Size(widget.size, widget.size),
    );
  }
}

class OptimizedParticlePainter extends CustomPainter {
  final List<OptimizedParticle> particles;
  final double progress;
  final Offset center;

  OptimizedParticlePainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (particle.isAlive) {
        final paint = Paint()
          ..color = particle.color.withValues(alpha: particle.alpha * 0.8)
          ..style = PaintingStyle.fill;

        final drawPosition = center + particle.position * progress;
        canvas.drawCircle(
          drawPosition,
          particle.size * particle.alpha,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(OptimizedParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class ComboParticleEffect extends StatefulWidget {
  final int comboCount;
  final Color color;
  final VoidCallback? onComplete;

  const ComboParticleEffect({
    super.key,
    required this.comboCount,
    required this.color,
    this.onComplete,
  });

  @override
  State<ComboParticleEffect> createState() => _ComboParticleEffectState();
}

class _ComboParticleEffectState extends State<ComboParticleEffect>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  final math.Random _random = math.Random();

  final List<_ComboParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _generateParticles();

    _scaleController.forward();
    _particleController.forward();

    _particleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  void _generateParticles() {
    final count = (widget.comboCount * 2).clamp(4, 20);
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      _particles.add(_ComboParticle(
        angle: angle,
        speed: _random.nextDouble() * 2 + 1,
        size: _random.nextDouble() * 4 + 2,
      ));
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _particleController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _ComboParticlePainter(
                particles: _particles,
                progress: _particleController.value,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComboParticle {
  final double angle;
  final double speed;
  final double size;

  _ComboParticle({
    required this.angle,
    required this.speed,
    required this.size,
  });
}

class _ComboParticlePainter extends CustomPainter {
  final List<_ComboParticle> particles;
  final double progress;
  final Color color;

  _ComboParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = size.width / 2;

    for (final particle in particles) {
      final distance = progress * particle.speed * maxDistance;
      final alpha = (1 - progress).clamp(0.0, 1.0);

      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1 - progress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ComboParticlePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
