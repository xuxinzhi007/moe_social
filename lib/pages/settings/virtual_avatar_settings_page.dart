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
        title: const Text('虚拟助手设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _card(
            child: Column(
              children: [
                _switchActionTile(
                  title: '启用虚拟助手',
                  subtitle: '默认关闭，开启后显示可悬浮助手',
                  value: avatar.enabled,
                  onChanged: (v) async {
                    await avatar.setEnabled(v);
                    if (!context.mounted) return;
                    MoeToast.info(context, v ? '虚拟助手已开启' : '虚拟助手已关闭');
                  },
                ),
                _actionTile(
                  icon: Icons.refresh_rounded,
                  title: '恢复显示',
                  subtitle: const Text('清除“隐藏本次会话/隐藏到今天结束”状态'),
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
                    '快捷功能自定义',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                _quickActionTile(
                  context,
                  avatar,
                  id: AvatarQuickActions.notifications,
                  title: '通知中心',
                  subtitle: '快速查看通知',
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
                  subtitle: '助手互动文案反馈',
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
          const SizedBox(height: 14),
          _card(
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.face_retouching_natural_rounded,
                  title: '角色形象',
                  subtitle: Text(
                    avatar.characterId == 'default_moe' ? '默认助手（当前）' : '自定义角色',
                  ),
                  onTap: () async {
                    await avatar.setCharacterId('default_moe');
                    if (!context.mounted) return;
                    MoeToast.info(context, '更多角色即将上线');
                  },
                ),
                _actionTile(
                  icon: Icons.style_rounded,
                  title: '皮肤主题',
                  subtitle: Text(
                    avatar.skinId == 'classic' ? '经典皮肤（当前）' : '自定义皮肤',
                  ),
                  onTap: () async {
                    await avatar.setSkinId('classic');
                    if (!context.mounted) return;
                    MoeToast.info(context, '更多皮肤即将上线');
                  },
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
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
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
