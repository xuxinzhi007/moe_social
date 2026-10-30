import 'package:flutter/material.dart';

import '../../constants/feature_flags.dart';
import '../../models/post.dart';
import '../../pages/ai/companion_hub_viewmodel.dart';
import '../../services/companion_chat_launcher.dart';
import '../../utils/post_navigation.dart';
import '../moe_toast.dart';

/// 打开一条「我们的历程」中的日常条目（聊天、未完话题、记忆、动态或星辉远征）。
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
