import 'package:flutter/material.dart';

import 'ai_brand_tokens.dart';
import 'ai_theme.dart';

class AiTerminalModeBanner extends StatelessWidget {
  const AiTerminalModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.bug_report_outlined,
              size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '终端调试模式：记忆注入与自动提取已关闭',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiGeneratingBanner extends StatefulWidget {
  const AiGeneratingBanner({
    super.key,
    required this.agentName,
    required this.onStop,
  });

  final String agentName;
  final VoidCallback onStop;

  @override
  State<AiGeneratingBanner> createState() => _AiGeneratingBannerState();
}

class _AiGeneratingBannerState extends State<AiGeneratingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AiBrandTokens.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _dotController,
            builder: (context, child) {
              final t = _dotController.value;
              final scale = 0.9 + (t < 0.5 ? t * 0.4 : (1 - t) * 0.4);
              return Transform.scale(scale: scale, child: child);
            },
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AiBrandTokens.primary.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '${widget.agentName} 回复中',
                    style: AiTheme.caption.copyWith(
                      color: AiBrandTokens.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _InlineTypingDots(controller: _dotController),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onStop,
            style: TextButton.styleFrom(
              foregroundColor: AiTheme.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('停止'),
          ),
        ],
      ),
    );
  }
}

class _InlineTypingDots extends StatelessWidget {
  const _InlineTypingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final phase = (controller.value + index * 0.18) % 1.0;
            final opacity =
                0.35 + (phase < 0.5 ? phase * 1.2 : (1 - phase) * 1.2);
            return Opacity(
              opacity: opacity.clamp(0.35, 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: child,
              ),
            );
          },
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AiBrandTokens.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
