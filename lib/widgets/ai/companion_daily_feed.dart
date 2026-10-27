import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/feature_flags.dart';
import '../../models/post.dart';
import '../../pages/ai/companion_hub_viewmodel.dart';
import '../../services/companion_chat_launcher.dart';
import '../../utils/post_navigation.dart';
import '../moe_toast.dart';
import 'ai_brand_tokens.dart';

/// 打开一条「TA 的日常」。聊天、记忆、动态和星辉远征都从这里进。
Future<void> openCompanionDailyItem(
  BuildContext context, {
  required CompanionDailyItem item,
  required String companionName,
}) async {
  switch (item.kind) {
    case 'chat':
      await CompanionChatLauncher.openChat(context);
      return;
    case 'topic':
      final topic = item.fullBody?.trim().isNotEmpty == true
          ? item.fullBody!.trim()
          : item.body.trim();
      await CompanionChatLauncher.openChat(
        context,
        draft: '我们接着聊聊这件事：$topic',
      );
      return;
    case 'moment':
      if (!FeatureFlags.arenaGamePrototype) return;
      await Navigator.of(context).pushNamed('/game/arena');
      return;
    case 'memory':
      await Navigator.of(context).pushNamed(
        '/ai-memories',
        arguments: <String, Object?>{
          if (item.memoryId != null && item.memoryId! > 0)
            'focusMemoryId': item.memoryId,
        },
      );
      return;
    case 'post':
      final id = item.postId?.trim() ?? '';
      if (id.isEmpty) {
        MoeToast.info(context, '这条动态暂时打不开');
        return;
      }
      final name = companionName.trim();
      await openPostDetail(
        context,
        Post(
          id: id,
          userId: '',
          userName: name.isNotEmpty ? name : 'AI 伙伴',
          userAvatar: '',
          content: item.body,
          createdAt: item.at ?? DateTime.now(),
        ),
      );
      return;
    default:
      return;
  }
}

class CompanionDailyFeed extends StatelessWidget {
  const CompanionDailyFeed({
    super.key,
    required this.items,
    required this.onOpenItem,
  });

  final List<CompanionDailyItem> items;
  final Future<void> Function(CompanionDailyItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'TA 的日常',
      icon: Icons.auto_stories_rounded,
      emptyText: '还没有日常动态，聊聊或去世界看看吧',
      child: items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: items
                  .map(
                    (item) => _DailyTile(
                      item: item,
                      onTap: () => unawaited(onOpenItem(item)),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({
    required this.item,
    this.onTap,
  });

  final CompanionDailyItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _dailyKindMeta(item.kind);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: meta.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(meta.icon, size: 18, color: AiBrandTokens.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Colors.grey.shade400,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null
          ? row
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: row,
                ),
              ),
            ),
    );
  }
}

({IconData icon, Color bg}) _dailyKindMeta(String kind) {
  switch (kind) {
    case 'world':
    case 'moment':
      return (icon: Icons.pets_rounded, bg: const Color(0xFFFFF1D6));
    case 'chat':
      return (
        icon: Icons.chat_bubble_outline_rounded,
        bg: const Color(0xFFE8F4FF),
      );
    case 'topic':
      return (icon: Icons.forum_outlined, bg: const Color(0xFFE8F4FF));
    case 'memory':
      return (icon: Icons.psychology_alt_rounded, bg: const Color(0xFFF3E8FF));
    case 'relationship':
      return (icon: Icons.favorite_rounded, bg: const Color(0xFFFFE8EE));
    case 'post':
    default:
      return (icon: Icons.article_outlined, bg: const Color(0xFFEFE7FF));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasContent = child is Column && (child as Column).children.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AiBrandTokens.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasContent)
            child
          else
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }
}
