import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final Future<void> Function()? onInit;
  final Widget Function(BuildContext) onComplete;
  final Duration? minDuration;

  const SplashScreen({
    super.key,
    this.onInit,
    required this.onComplete,
    this.minDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<double> _logoFloat;
  double _progress = 0.0;
  String _statusText = '正在初始化...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleUp = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack)),
    );

    _logoFloat = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.forward();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    final startTime = DateTime.now();

    if (widget.onInit != null) {
      try {
        await widget.onInit!();
        _statusText = '准备就绪...';
        _progress = 1.0;
      } catch (e) {
        _statusText = '初始化失败';
        await Future.delayed(const Duration(milliseconds: 500));
        rethrow;
      }
    }

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < widget.minDuration!) {
      await Future.delayed(widget.minDuration! - elapsed);
    }

    _navigateToApp();
  }

  void _navigateToApp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.onComplete(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeIn,
              child: Transform.scale(
                scale: _scaleUp.value,
                child: Transform.translate(
                  offset: Offset(0, _logoFloat.value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(theme),
                      const SizedBox(height: 32),
                      _buildTitle(theme),
                      const SizedBox(height: 48),
                      _buildProgressIndicator(),
                      const SizedBox(height: 16),
                      _buildStatusText(theme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF91EAE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.star,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Text(
      'Moe Social',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF91EAE4)],
          ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: 200,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.transparent,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5)),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildStatusText(ThemeData theme) {
    return Text(
      _statusText,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
    );
  }
}