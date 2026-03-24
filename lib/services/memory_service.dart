import 'dart:convert';

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

  /// 把已有记忆列表拼接到基础 system prompt 里（仅注入上下文，不要求 AI 打标签）
  ///
  /// 记忆提取由独立的背景调用完成（见 ChatPage._extractMemoriesInBackground），
  /// 主对话 prompt 保持简洁，对小模型更友好。
  static String buildPromptWithMemories(
    String basePrompt,
    List<AiMemory> memories,
  ) {
    final buffer = StringBuffer();
    buffer.write(basePrompt.isNotEmpty ? basePrompt : '你是一位友好、智能的 AI 助手。');

    if (memories.isNotEmpty) {
      buffer.write('\n\n--- 你的长期记忆数据库 ---\n');
      buffer.write('（以下是你之前和该用户聊天记住的事实。在回答时，如果相关，请自然地体现出你记得这些事，就像老朋友一样。不要生硬地罗列，只需在对话中表现出你“知道”即可）：\n');
      for (int i = 0; i < memories.length; i++) {
        final (_, emoji) = AiMemory.categoryMeta(memories[i].category);
        buffer.write('${i + 1}. $emoji ${memories[i].content}\n');
      }
      buffer.write('----------------------\n');
    }

    return buffer.toString();
  }

  /// 构建专门用于记忆提取的 prompt
  ///
  /// 传入已有记忆，让大模型判断是新记忆、旧记忆还是有冲突需要更新。
  static String buildExtractionPrompt(String userMessage, String aiResponse, List<AiMemory> currentMemories) {
    String existing = currentMemories.isEmpty 
        ? "无" 
        : currentMemories.map((m) => m.content).join("；");
        
    return '你是信息提取助手。请分析最新对话，提取关于用户的重要长期记忆。\n'
        '【已有记忆】：$existing\n'
        '【提取规则】：\n'
        '1. 提取用户的个人信息（如名字/年龄）、明确偏好（如喜欢/讨厌什么）、重要计划（如明天考试）、日常习惯。\n'
        '2. 去重过滤：如果对话中的信息在【已有记忆】中已经存在，绝对不要重复提取。\n'
        '3. 冲突更新：如果对话中的新信息与【已有记忆】矛盾（如用户之前说叫小明，现在说改名叫小红），请提取新信息。\n'
        '4. 格式：每条新记忆或更新的记忆，用 [记忆:具体内容] 单独一行输出。示例：[记忆:用户明天下午三点有面试]\n'
        '5. 如果本轮对话没有任何值得长期记忆的实质性新信息，请只输出"无"。\n\n'
        '【最新对话】\n'
        '用户：$userMessage\n'
        '助手：$aiResponse';
  }

  static String buildCurationPrompt(List<AiMemory> memories) {
    final raw = memories
        .take(30)
        .map((m) => '- [${m.category}] ${m.content}')
        .join('\n');
    return '你是长期记忆整理助手。请把下面零散的用户记忆整理成稳定的用户画像摘要。\n'
        '请合并重复、消除同义表述、保留最新有效信息。\n'
        '输出 JSON 数组，不要输出额外解释。每项格式如下：\n'
        '[{"profile_type":"identity|preference|habit|plan|style|general","title":"简短标题","summary":"1句话稳定描述","confidence":0.0-1.0}]\n'
        '最多输出 6 项。\n\n'
        '【原始记忆】\n$raw';
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

  static List<Map<String, dynamic>> parseProfiles(String response) {
    try {
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (match == null) return const [];
      final parsed = jsonDecode(match.group(0)!);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String normalizeMemoryText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool isDuplicateMemory(String left, String right) {
    final a = normalizeMemoryText(left);
    final b = normalizeMemoryText(right);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
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
