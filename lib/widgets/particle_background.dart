import 'package:flutter/material.dart';
import 'dart:math' as math;

class ParticleBackground extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final int particleCount;

  const ParticleBackground({
    super.key,
    this.primaryColor = const Color(0xFF7F7FD5),
    this.secondaryColor = const Color(0xFF86A8E7),
    this.particleCount = 30,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _particles = List.generate(
      widget.particleCount,
      (index) => Particle(
        color: index % 2 == 0 ? widget.primaryColor : widget.secondaryColor,
        size: math.Random().nextDouble() * 4 + 1,
        speed: math.Random().nextDouble() * 0.5 + 0.2,
        direction: math.Random().nextDouble() * 360,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              time: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class Particle {
  final Color color;
  final double size;
  final double speed;
  final double direction;
  double x;
  double y;

  Particle({
    required this.color,
    required this.size,
    required this.speed,
    required this.direction,
  })  : x = math.Random().nextDouble(),
        y = math.Random().nextDouble();
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double time;

  ParticlePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update particle position
      double angle = particle.direction * (3.14159 / 180);
      particle.x += (particle.speed * math.cos(angle)) * 0.01;
      particle.y += (particle.speed * math.sin(angle)) * 0.01;

      // Wrap around
      if (particle.x < 0) particle.x = 1;
      if (particle.x > 1) particle.x = 0;
      if (particle.y < 0) particle.y = 1;
      if (particle.y > 1) particle.y = 0;

      // Draw particle
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        Paint()
          ..color = particle.color.withOpacity(0.3)
          ..blendMode = BlendMode.overlay,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

