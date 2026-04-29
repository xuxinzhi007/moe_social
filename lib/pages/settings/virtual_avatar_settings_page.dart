import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/virtual_avatar_provider.dart';
import '../../widgets/moe_toast.dart';

class VirtualAvatarSettingsPage extends StatelessWidget {
  const VirtualAvatarSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<VirtualAvatarProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                SwitchListTile.adaptive(
                  title: const Text('启用虚拟助手'),
                  subtitle: const Text('默认关闭，开启后显示可悬浮助手'),
                  value: avatar.enabled,
                  activeThumbColor: const Color(0xFF7F7FD5),
                  onChanged: (v) async {
                    await avatar.setEnabled(v);
                    if (!context.mounted) return;
                    MoeToast.info(context, v ? '虚拟助手已开启' : '虚拟助手已关闭');
                  },
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: const Text('恢复显示'),
                  subtitle: const Text('清除“隐藏本次会话/隐藏到今天结束”状态'),
                  trailing: const Icon(Icons.refresh_rounded),
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
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural_rounded),
                  title: const Text('角色形象'),
                  subtitle: Text(
                    avatar.characterId == 'default_moe' ? '默认助手（当前）' : '自定义角色',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await avatar.setCharacterId('default_moe');
                    if (!context.mounted) return;
                    MoeToast.info(context, '更多角色即将上线');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.style_rounded),
                  title: const Text('皮肤主题'),
                  subtitle: Text(
                    avatar.skinId == 'classic' ? '经典皮肤（当前）' : '自定义皮肤',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
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
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: Text(subtitle),
      value: avatar.quickActions.contains(id),
      activeThumbColor: const Color(0xFF7F7FD5),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
