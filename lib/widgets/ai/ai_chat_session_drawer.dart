import 'package:flutter/material.dart';

import '../../models/ai_chat_session.dart';
import '../../theme/moe_tokens.dart';
import '../moe_action_row.dart';
import 'ai_brand_tokens.dart';

class AiChatSessionDrawer extends StatelessWidget {
  const AiChatSessionDrawer({
    super.key,
    required this.agentName,
    required this.modelName,
    required this.providerSourceLabel,
    required this.userPersona,
    required this.sessions,
    required this.currentSessionId,
    required this.onCreateSession,
    required this.onEditUserPersona,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  final String agentName;
  final String modelName;
  final String providerSourceLabel;
  final String userPersona;
  final List<AiChatSession> sessions;
  final String? currentSessionId;
  final VoidCallback onCreateSession;
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
          MoeActionRow(
            icon: Icons.add_comment_rounded,
            title: '新对话',
            iconColor: AiBrandTokens.primary,
            onTap: () {
              Navigator.pop(context);
              onCreateSession();
            },
          ),
          MoeActionRow(
            icon: Icons.person_outline_rounded,
            title: '用户 Persona',
            subtitle: Text(userPersona.isEmpty ? '未设置' : '已设置'),
            iconColor: MoeTokens.accent,
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
                        child: MoeActionRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: session.title,
                          iconColor: isCurrent
                              ? AiBrandTokens.primary
                              : Colors.grey.shade600,
                          iconBackgroundColor: isCurrent
                              ? AiBrandTokens.primary.withValues(alpha: 0.12)
                              : Colors.grey.shade200,
                          selected: isCurrent,
                          selectedBackgroundColor:
                              AiBrandTokens.primary.withValues(alpha: 0.1),
                          selectedBorderColor:
                              AiBrandTokens.primary.withValues(alpha: 0.3),
                          selectedTitleColor: AiBrandTokens.primary,
                          backgroundColor: Colors.white,
                          borderColor: Colors.transparent,
                          titleStyle: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent
                                ? AiBrandTokens.primary
                                : AiBrandTokens.titleColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          showDefaultTrailing: false,
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
