import 'package:flutter/material.dart';

/// 伙伴聊天启动器 —— 打开 [CompanionChatPage]（后端 SSE 流式聊天）。
///
/// 所有 Prompt 构建、LLM 调用、记忆管理均由后端 companion 模块处理。
/// 前端只负责 UI 展示和 SSE 事件消费。
class CompanionChatLauncher {
  /// 从伙伴主页进入聊天。
  static Future<void> openChat(
    BuildContext context, {
    String? draft,
  }) async {
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(
      '/ai-chat',
      arguments: <String, Object?>{
        if (draft != null && draft.trim().isNotEmpty) 'draft': draft.trim(),
      },
    );
  }
}
