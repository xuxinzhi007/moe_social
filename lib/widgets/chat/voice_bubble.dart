import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../theme/moe_tokens.dart';

/// 语音消息气泡内容：播放按钮 + 伪波形 + 时长标签。
///
/// 波形为按 [durationSec] 作种子的确定性伪随机竖条，播放进度由
/// just_audio 的 positionStream 驱动，已播放部分高亮。
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.url,
    required this.durationSec,
    required this.isMe,
  });

  final String url;
  final int durationSec;

  /// 是否位于我方（主色）气泡内，决定波形 / 按钮配色。
  final bool isMe;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _prepared = false;
  bool _playing = false;
  bool _loadFailed = false;
  Duration _position = Duration.zero;

  Color get _activeColor => widget.isMe ? Colors.white : MoeTokens.primary;
  Color get _inactiveColor =>
      widget.isMe ? Colors.white.withValues(alpha: 0.42) : MoeTokens.hintText;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
        unawaitedPause();
        return;
      }
      final playing = state.playing;
      if (playing != _playing) {
        setState(() => _playing = playing);
      }
    });
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
  }

  Future<void> unawaitedPause() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_loadFailed) {
      // 允许失败后重试（如弱网）。
      _loadFailed = false;
    }
    try {
      if (!_prepared) {
        await _player.setUrl(widget.url);
        _prepared = true;
      }
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationSec > 0
        ? Duration(seconds: widget.durationSec)
        : (_player.duration ?? const Duration(seconds: 1));
    final totalMs = total.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 播放 / 暂停按钮
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.22)
                  : MoeTokens.primary.withValues(alpha: 0.12),
            ),
            child: _loadFailed
                ? Icon(Icons.refresh_rounded, size: 18, color: _activeColor)
                : Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 18,
                    color: _activeColor,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // 伪波形
        SizedBox(
          width: _waveformWidth,
          height: 24,
          child: CustomPaint(
            painter: _WaveformPainter(
              seed: widget.durationSec,
              progress: progress,
              activeColor: _activeColor,
              inactiveColor: _inactiveColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 时长标签
        Text(
          _formatDuration(total),
          style: TextStyle(
            fontSize: MoeTokens.textXs,
            fontWeight: FontWeight.w500,
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.85)
                : MoeTokens.hintText,
          ),
        ),
      ],
    );
  }

  double get _waveformWidth {
    // 条数随时长增长（15-25 根），宽度随之伸缩但设上限避免过长。
    final bars = _WaveformPainter.barCountFor(widget.durationSec);
    return math.min(bars * 4.0 + 6.0, 148.0);
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// 伪波形绘制：seed 决定竖条高度序列（固定不抖动），progress 前后分色。
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  }) : _heights = _heightsFor(seed);

  final int seed;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final List<double> _heights;

  /// 按 seed 生成 15-25 根竖条的固定相对高度（0.25 ~ 1.0）。
  static List<double> _heightsFor(int seed) {
    final count = barCountFor(seed);
    final random = math.Random(seed == 0 ? 42 : seed);
    return List<double>.generate(
      count,
      (_) => 0.25 + random.nextDouble() * 0.75,
    );
  }

  static int barCountFor(int durationSec) => (15 + durationSec).clamp(15, 25);

  @override
  void paint(Canvas canvas, Size size) {
    final count = _heights.length;
    const barWidth = 3.0;
    final gap =
        count > 1 ? (size.width - barWidth * count) / (count - 1) : 0.0;
    final centerY = size.height / 2;
    final activeUpTo = progress * count;

    for (var i = 0; i < count; i++) {
      final h = _heights[i] * size.height;
      final x = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - h / 2, barWidth, h),
        const Radius.circular(1.5),
      );
      final isActive = i < activeUpTo;
      canvas.drawRRect(
        rect,
        Paint()..color = isActive ? activeColor : inactiveColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.seed != seed ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
