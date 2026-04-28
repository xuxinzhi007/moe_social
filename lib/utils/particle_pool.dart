import 'dart:math' as math;
import 'package:flutter/material.dart';

class Particle {
  Offset position;
  Offset velocity;
  double life;
  double maxLife;
  Color color;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
    this.size = 4.0,
  }) : maxLife = life;

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
  final List<Particle> _pool = [];
  final List<Particle> _activeParticles = [];
  final int maxPoolSize;

  ParticlePool({this.maxPoolSize = 200});

  Particle? acquire() {
    if (_pool.isNotEmpty) {
      final particle = _pool.removeLast();
      _activeParticles.add(particle);
      return particle;
    }
    if (_activeParticles.length < maxPoolSize) {
      final particle = Particle(
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

  void release(Particle particle) {
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

  List<Particle> get activeParticles => List.unmodifiable(_activeParticles);

  int get poolSize => _pool.length;
  int get activeCount => _activeParticles.length;
}

class ParticleSystem {
  final ParticlePool _pool = ParticlePool();
  final math.Random _random = math.Random();
  final List<Particle> _emittedParticles = [];

  void emit({
    required Offset center,
    required Color color,
    int count = 10,
    double speed = 3.0,
    double life = 1.0,
    double size = 4.0,
    double spread = 1.0,
  }) {
    for (int i = 0; i < count; i++) {
      final particle = _pool.acquire();
      if (particle == null) break;

      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = _random.nextDouble() * 50 * spread;
      final position = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );

      final particleSpeed = _random.nextDouble() * speed + speed * 0.5;
      final velocity = Offset(
        (_random.nextDouble() - 0.5) * particleSpeed,
        -(_random.nextDouble() * particleSpeed * 0.5 + particleSpeed),
      );

      particle.reset(
        position: position,
        velocity: velocity,
        life: _random.nextDouble() * life * 0.5 + life * 0.5,
        color: color,
        size: _random.nextDouble() * size * 0.5 + size * 0.5,
      );
      _emittedParticles.add(particle);
    }
  }

  void update(double deltaTime) {
    for (var i = _emittedParticles.length - 1; i >= 0; i--) {
      final particle = _emittedParticles[i];
      particle.update(deltaTime);
      if (!particle.isAlive) {
        _pool.release(particle);
        _emittedParticles.removeAt(i);
      }
    }
  }

  void paint(Canvas canvas, Offset center, double progress) {
    for (final particle in _emittedParticles) {
      if (particle.isAlive) {
        final paint = Paint()
          ..color = particle.color.withOpacity(particle.alpha * 0.8)
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

  void clear() {
    for (final particle in _emittedParticles) {
      _pool.release(particle);
    }
    _emittedParticles.clear();
  }

  bool get isEmpty => _emittedParticles.isEmpty;
}
