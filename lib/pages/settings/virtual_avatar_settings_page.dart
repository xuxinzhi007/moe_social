import 'package:flutter/material.dart';

import '../../constants/feature_flags.dart';
import '../../theme/moe_tokens.dart';

class VirtualAvatarSettingsPage extends StatelessWidget {
  const VirtualAvatarSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('社区 AI'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: MoeTokens.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '旧 App 内悬浮入口已下线',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '社区「AI 助手」浮标是贴纸桌宠的前身，不再作为第二套长期悬浮。'
                    '微信旁救场请用伙伴·回复参谋；App 内陪聊请用 AI 伙伴。',
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                  if (FeatureFlags.replyAssistPrototype) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/reply-assist'),
                        child: const Text('打开伙伴·回复参谋'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.smart_toy_rounded, color: MoeTokens.primary),
                      SizedBox(width: 8),
                      Text(
                        '社区 AI 账号',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI 以真实社区账号参与发动态、评论、点赞和互动。帖子会出现在社区流中，并带有 AI 标签。',
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: '真实账号'),
                      _InfoChip(label: '动态发帖'),
                      _InfoChip(label: '评论互动'),
                      _InfoChip(label: 'AI 标签'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MoeTokens.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MoeTokens.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
