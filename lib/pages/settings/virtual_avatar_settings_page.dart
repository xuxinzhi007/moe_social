import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/virtual_avatar_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_toast.dart';

class VirtualAvatarSettingsPage extends StatelessWidget {
  const VirtualAvatarSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<VirtualAvatarProvider>();

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI 助手设置'),
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
                  Row(
                    children: const [
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
                    'AI 不再作为独立页面存在，而是以真实社区账号参与发动态、评论、点赞和互动。帖子会直接出现在社区流中，并带有 AI 标签。',
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
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
          const SizedBox(height: 14),
          _card(
            child: Column(
              children: [
                _switchActionTile(
                  title: '启用悬浮助手入口',
                  subtitle: '保留设置页和全局悬浮入口，作为社区 AI 的控制入口',
                  value: avatar.enabled,
                  onChanged: (v) async {
                    await avatar.setEnabled(v);
                    if (!context.mounted) return;
                    MoeToast.info(context, v ? 'AI 助手入口已开启' : 'AI 助手入口已关闭');
                  },
                ),
                _actionTile(
                  icon: Icons.refresh_rounded,
                  title: '恢复悬浮入口显示',
                  subtitle: const Text('清除本次会话中的隐藏状态，恢复助手入口'),
                  onTap: () async {
                    await avatar.restoreVisibility();
                    if (!context.mounted) return;
                    MoeToast.success(context, '已恢复显示');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    '悬浮入口快捷功能',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                _quickActionTile(
                  context,
                  avatar,
                  id: AvatarQuickActions.notifications,
                  title: '通知中心',
                  subtitle: '快速查看互动和通知',
                ),
                _quickActionTile(
                  context,
                  avatar,
                  id: AvatarQuickActions.createPost,
                  title: '发布动态',
                  subtitle: '一键跳转发帖页',
                ),
                _quickActionTile(
                  context,
                  avatar,
                  id: AvatarQuickActions.greet,
                  title: '打招呼',
                  subtitle: '保留轻量助手反馈入口',
                ),
                _quickActionTile(
                  context,
                  avatar,
                  id: AvatarQuickActions.checkin,
                  title: '去签到',
                  subtitle: '快速进入签到页',
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Text(
                    '至少保留 1 个快捷功能',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(
    BuildContext context,
    VirtualAvatarProvider avatar, {
    required String id,
    required String title,
    required String subtitle,
  }) {
    return _switchActionTile(
      title: title,
      subtitle: subtitle,
      value: avatar.quickActions.contains(id),
      onChanged: (v) async {
        final before = avatar.quickActions.contains(id);
        await avatar.setQuickActionEnabled(id, v);
        if (!context.mounted) return;
        final after = avatar.quickActions.contains(id);
        if (before && !v && after) {
          MoeToast.warning(context, '至少保留一个快捷功能');
          return;
        }
        MoeToast.info(context, v ? '已开启：$title' : '已关闭：$title');
      },
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

  Widget _actionTile({
    required IconData icon,
    required String title,
    required Widget subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: MoeTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      child: subtitle,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchActionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: MoeTokens.primary,
            onChanged: onChanged,
          ),
        ],
      ),
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
