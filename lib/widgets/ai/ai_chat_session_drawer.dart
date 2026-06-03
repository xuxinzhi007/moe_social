import 'package:flutter/material.dart';

import '../../models/ai_chat_session.dart';
import 'ai_brand_tokens.dart';

class AiChatSessionDrawer extends StatelessWidget {
  const AiChatSessionDrawer({
    super.key,
    required this.agentName,
    required this.modelName,
    required this.providerSourceLabel,
    required this.memoryCount,
    required this.userPersona,
    required this.sessions,
    required this.currentSessionId,
    required this.onCreateSession,
    required this.onOpenMemoryManager,
    required this.onEditUserPersona,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  final String agentName;
  final String modelName;
  final String providerSourceLabel;
  final int memoryCount;
  final String userPersona;
  final List<AiChatSession> sessions;
  final String? currentSessionId;
  final VoidCallback onCreateSession;
  final VoidCallback onOpenMemoryManager;
  final VoidCallback onEditUserPersona;
  final ValueChanged<AiChatSession> onLoadSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AiBrandTokens.pageBackground,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: AiBrandTokens.heroGradient,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$providerSourceLabel · $modelName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DrawerActionTile(
            icon: Icons.add_comment_rounded,
            label: '新对话',
            color: AiBrandTokens.primary,
            onTap: () {
              Navigator.pop(context);
              onCreateSession();
            },
          ),
          _DrawerActionTile(
            icon: Icons.psychology_rounded,
            label: '记忆库（$memoryCount 条）',
            color: const Color(0xFF5B8DEF),
            onTap: () {
              Navigator.pop(context);
              onOpenMemoryManager();
            },
          ),
          _DrawerActionTile(
            icon: Icons.person_outline_rounded,
            label: '用户 Persona',
            subtitle: userPersona.isEmpty ? '未设置' : '已设置',
            color: const Color(0xFF00A86B),
            onTap: () {
              Navigator.pop(context);
              onEditUserPersona();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '历史会话',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      '暂无历史会话',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isCurrent = session.id == currentSessionId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AiBrandTokens.primary.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? AiBrandTokens.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? AiBrandTokens.primary
                                  : AiBrandTokens.titleColor,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onLoadSession(session);
                          },
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () => onDeleteSession(session.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }
}
