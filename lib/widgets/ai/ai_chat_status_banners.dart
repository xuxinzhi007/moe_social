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

class AiGeneratingBanner extends StatelessWidget {
  const AiGeneratingBanner({
    super.key,
    required this.agentName,
    required this.onStop,
  });

  final String agentName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AiBrandTokens.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AiBrandTokens.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$agentName 正在回复...',
              style: AiTheme.caption.copyWith(
                color: AiBrandTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onStop,
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
