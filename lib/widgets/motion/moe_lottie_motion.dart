import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'moe_motion.dart';

/// 通用 Lottie 播放器：加载失败走 [onError]/reduceMotion 走 [fallback]。
///
/// 成功播完才触发 [onComplete]；失败不会误触发完成（由上层接 fallback 动效）。
class MoeLottieMotion extends StatefulWidget {
  final String assetPath;
  final Duration? duration;
  final bool repeat;
  final Widget? centerChild;
  final Color? tintColor;
  final VoidCallback? onComplete;
  final VoidCallback? onError;
  final Widget? fallback;
  final BoxFit fit;

  const MoeLottieMotion({
    super.key,
    required this.assetPath,
    this.duration,
    this.repeat = false,
    this.centerChild,
    this.tintColor,
    this.onComplete,
    this.onError,
    this.fallback,
    this.fit = BoxFit.contain,
  });

  /// 预载模板（忽略失败，由播放时再降级）。
  static Future<void> precache(List<String> assetPaths) async {
    for (final path in assetPaths) {
      try {
        await AssetLottie(path).load();
      } catch (_) {
        // 预载失败不阻断送礼；播放时走 fallback。
      }
    }
  }

  @override
  State<MoeLottieMotion> createState() => _MoeLottieMotionState();
}

class _MoeLottieMotionState extends State<MoeLottieMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _failed = false;
  bool _completed = false;
  bool _reduceMotion = false;
  bool _depsReady = false;
  bool _errorNotified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _reduceMotion = moeReduceMotion(context);
  }

  @override
  void didUpdateWidget(covariant MoeLottieMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _failed = false;
      _completed = false;
      _errorNotified = false;
      _controller
        ..stop()
        ..reset();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    if (widget.repeat) {
      _controller.repeat();
      return;
    }
    _completed = true;
    widget.onComplete?.call();
  }

  void _notifyError() {
    if (_errorNotified) return;
    _errorNotified = true;
    widget.onError?.call();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion || _failed) {
      if (_failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notifyError());
      }
      return widget.fallback ?? (widget.centerChild ?? const SizedBox.shrink());
    }

    Widget lottie = Lottie.asset(
      widget.assetPath,
      controller: _controller,
      fit: widget.fit,
      onLoaded: (composition) {
        if (!mounted || _failed) return;
        _controller.duration = widget.duration ?? composition.duration;
        _controller.forward(from: 0);
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _failed) return;
          setState(() => _failed = true);
          _notifyError();
        });
        return widget.fallback ??
            (widget.centerChild ?? const SizedBox.shrink());
      },
    );

    final tint = widget.tintColor;
    if (tint != null) {
      lottie = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: lottie,
      );
    }

    final center = widget.centerChild;
    if (center == null) return lottie;

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        lottie,
        center,
      ],
    );
  }
}
