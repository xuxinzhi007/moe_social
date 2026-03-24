import '../models/ai_memory.dart';
import '../models/user_memory.dart';
import 'api_service.dart';

/// MemoryService 包含两类功能：
///
/// 1. 【用户后端记忆】 - 通过后端 API 存取用户级别的 key-value 记忆（设备信息等）
/// 2. 【AI 聊天长期记忆】 - 纯本地工具方法，用于把记忆注入 system prompt，
///    以及从 AI 回复中解析 [记忆:xxx] 标签
class MemoryService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 一、用户后端记忆（原有功能，勿删）
  // ═══════════════════════════════════════════════════════════════════════════

  /// 获取用户记忆列表
  static Future<List<UserMemory>> getUserMemories(String userId) async {
    final result = await ApiService.get('/api/user/$userId/memories');
    final List<dynamic> list = result['data'] ?? [];
    return list.map((json) => UserMemory.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 按 key 删除用户记忆
  static Future<void> deleteUserMemoryByKey(String userId, String key) async {
    final encodedKey = Uri.encodeComponent(key);
    await ApiService.delete('/api/user/$userId/memories?key=$encodedKey');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 二、AI 聊天长期记忆（新增功能）
  // ═══════════════════════════════════════════════════════════════════════════

  static const _tagPattern = r'\[记忆:([^\]]{1,300})\]';

  /// 把已有记忆列表拼接到基础 system prompt 里，并在末尾追加记忆存储指令
  static String buildPromptWithMemories(
    String basePrompt,
    List<AiMemory> memories,
  ) {
    final buffer = StringBuffer();

    buffer.write(basePrompt.isNotEmpty ? basePrompt : '你是一位友好、智能的 AI 助手。');

    if (memories.isNotEmpty) {
      buffer.write('\n\n─────────────────────────────\n');
      buffer.write('【关于该用户的长期记忆】\n');
      buffer.write('以下是你通过历次对话积累的用户信息，请在回复时自然地参考：\n');
      for (final m in memories) {
        final (_, emoji) = AiMemory.categoryMeta(m.category);
        buffer.write('$emoji ${m.content}\n');
      }
      buffer.write('─────────────────────────────');
    }

    buffer.write('\n\n【记忆存储指令】\n');
    buffer.write(
        '如果本次对话中出现了值得长期记住的信息（例如用户的偏好、习惯、重要事件、待办提醒、个人信息等），');
    buffer.write('请在你的回复正文末尾**另起一行**，用以下格式追加（可多条，勿放在正文中间）：\n');
    buffer.write('[记忆:具体内容]\n');
    buffer.write('示例：[记忆:用户喜欢喝美式咖啡，不加糖]\n');
    buffer.write('若本轮对话无需记录，则不添加该标签。**记忆标签对用户不可见，不会被展示出来。**');

    return buffer.toString();
  }

  /// 从 AI 回复中提取所有 [记忆:xxx] 标签内容
  static List<String> extractMemories(String response) {
    final regex = RegExp(_tagPattern);
    return regex
        .allMatches(response)
        .map((m) => m.group(1)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 移除回复中的记忆标签（用于展示给用户的内容）
  static String cleanResponse(String response) {
    final regex = RegExp(r'\n?\[记忆:[^\]]*\]');
    return response.replaceAll(regex, '').trim();
  }

  /// 根据记忆内容自动推断分类
  static String inferCategory(String content) {
    if (RegExp(r'喜欢|偏好|最爱|讨厌|不喜欢|prefer|love|hate').hasMatch(content)) {
      return 'preference';
    }
    if (RegExp(r'提醒|记得|明天|后天|下周|deadline|到期|会议|约定|appointment')
        .hasMatch(content)) {
      return 'reminder';
    }
    if (RegExp(r'习惯|每天|每周|每月|经常|总是|routine|always|usually')
        .hasMatch(content)) {
      return 'habit';
    }
    if (RegExp(r'叫|名字|年龄|生日|住在|职业|name|age|birthday|job|work')
        .hasMatch(content)) {
      return 'personal';
    }
    return 'general';
  }

  /// 推断记忆重要性（1–5）
  static int inferImportance(String content) {
    if (RegExp(r'提醒|deadline|重要|urgent|紧急|不能忘|appointment')
        .hasMatch(content)) {
      return 5;
    }
    if (RegExp(r'喜欢|讨厌|习惯|每天|每周').hasMatch(content)) {
      return 4;
    }
    return 3;
  }
}
