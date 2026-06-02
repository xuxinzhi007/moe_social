import 'dart:convert';

import '../models/ai_memory.dart';
import '../models/user_memory.dart';
import '../models/user_memory_display.dart';
import '../models/user_memory_profile.dart';
import 'api_response.dart';
import 'api_service.dart';

/// MemoryService 包含两类功能：
///
/// 1. 【用户后端记忆】 - 对话长期记忆（设备信息见 [DeviceService]）
/// 2. 【AI 聊天长期记忆】 - 纯本地工具方法，用于把记忆注入 system prompt，
///    以及从 AI 回复中解析 [记忆:xxx] 标签
class MemoryService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 一、用户后端记忆（原有功能，勿删）
  // ═══════════════════════════════════════════════════════════════════════════

  static const int _defaultMemoryPageSize = 50;

  static bool isTechnicalMemory(UserMemory memory) {
    final key = memory.key.toLowerCase();
    final source = (memory.source ?? '').toLowerCase();
    return key.startsWith('device_info:') ||
        key.startsWith('daily_note:') ||
        source == 'device_sync';
  }

  static List<UserMemory> filterUserFacingMemories(List<UserMemory> memories) {
    return memories.where((m) => !isTechnicalMemory(m)).toList();
  }

  /// 分页获取用户记忆列表（后端支持 limit/offset）
  static Future<Map<String, dynamic>> getUserMemoriesPaged(
    String userId, {
    int limit = _defaultMemoryPageSize,
    int offset = 0,
  }) async {
    final safeLimit = limit <= 0 ? _defaultMemoryPageSize : limit;
    final safeOffset = offset < 0 ? 0 : offset;
    final result = await ApiService.get(
      '/api/user/$userId/memories?limit=$safeLimit&offset=$safeOffset',
    );
    final list = ApiResponse.listOf(result, keys: const ['memories', 'items', 'data']);
    return {
      'items': list
          .whereType<Map>()
          .map((json) => UserMemory.fromJson(Map<String, dynamic>.from(json)))
          .toList(),
      'total': ApiResponse.intField(result, 'total') ?? list.length,
      'limit': ApiResponse.intField(result, 'limit') ?? safeLimit,
      'offset': ApiResponse.intField(result, 'offset') ?? safeOffset,
      'has_more': result['has_more'] == true ||
          ApiResponse.payload(result)['has_more'] == true,
    };
  }

  /// 获取用户记忆列表
  static Future<List<UserMemory>> getUserMemories(String userId) async {
    final paged = await getUserMemoriesPaged(
      userId,
      limit: _defaultMemoryPageSize,
      offset: 0,
    );
    final items = paged['items'];
    if (items is List<UserMemory>) return items;
    return const [];
  }

  /// 记忆文本库检索（SSOT：后端 `/memories/search`，编排层与 memory_search 工具共用）。
  static Future<List<UserMemory>> searchUserMemories(
    String userId, {
    required String query,
    int limit = 8,
  }) async {
    final safeLimit = limit.clamp(1, 20);
    final encodedQ = Uri.encodeQueryComponent(query.trim());
    final result = await ApiService.get(
      '/api/user/$userId/memories/search?q=$encodedQ&limit=$safeLimit',
    );
    final data = ApiResponse.object(result);
    final list = ApiResponse.listOf(data, keys: const ['items']);
    return list.map((json) {
      final item = Map<String, dynamic>.from(json as Map);
      return UserMemory(
        id: (item['id'] as String?) ?? '',
        userId: userId,
        key: (item['key'] as String?) ?? '',
        value: (item['content'] as String?) ?? '',
        memoryType: (item['category'] as String?) ?? '',
        createdAt: (item['updated_at'] as String?) ?? '',
        updatedAt: (item['updated_at'] as String?) ?? '',
      );
    }).toList();
  }

  /// 获取面向用户展示的记忆数据（后端已过滤技术项并生成标题/分类）。
  static Future<UserMemoryDisplayData> getUserMemoriesDisplay(String userId) async {
    final result = await ApiService.get(
      '/api/user/$userId/memories/display',
    );
    return UserMemoryDisplayData.fromJson(ApiResponse.object(result));
  }

  /// 获取后端聚合画像摘要
  static Future<List<UserMemoryProfile>> getUserMemoryProfiles(
    String userId, {
    int limit = 6,
  }) async {
    final safeLimit = limit <= 0 ? 6 : limit;
    final result = await ApiService.get(
        '/api/user/$userId/memories/profiles?limit=$safeLimit');
    final list = ApiResponse.listOf(result, keys: const ['profiles', 'data']);
    return list
        .whereType<Map>()
        .map((json) => UserMemoryProfile.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 按 key 删除用户记忆
  static Future<void> deleteUserMemoryByKey(String userId, String key) async {
    final encodedKey = Uri.encodeComponent(key);
    await ApiService.delete('/api/user/$userId/memories?key=$encodedKey');
  }

  /// 写入或更新用户记忆（服务端账号级）
  static Future<UserMemory> upsertUserMemory({
    required String userId,
    required String key,
    required String value,
    String? memoryType,
    double? confidence,
    String? source,
    String? sourceMsgId,
    String? sessionId,
  }) async {
    final result = await ApiService.post(
      '/api/user/$userId/memories',
      body: {
        'key': key,
        'value': value,
        if (memoryType != null && memoryType.isNotEmpty)
          'memory_type': memoryType,
        if (confidence != null) 'confidence': confidence,
        if (source != null && source.isNotEmpty) 'source': source,
        if (sourceMsgId != null && sourceMsgId.isNotEmpty)
          'source_msg_id': sourceMsgId,
        if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      },
    );
    return UserMemory.fromJson(
      ApiResponse.object(result, keys: const ['memory']),
    );
  }

  /// 按对话相关性选取要注入的记忆（OpenClaw 式：关键词命中 + 新近度兜底）。
  static List<UserMemory> selectRelevantUserMemories({
    required List<UserMemory> memories,
    String queryText = '',
    int maxItems = 8,
    int maxRunes = 520,
  }) {
    if (memories.isEmpty) return const [];
    final safeMax = maxItems <= 0 ? 8 : maxItems;
    final tokens = _extractQueryTokens(queryText);
    final ranked = <_RankedUserMemory>[];

    for (final memory in memories) {
      if (isTechnicalMemory(memory)) continue;
      final value = memory.value.trim();
      if (value.isEmpty) continue;
      final norm = normalizeMemoryText('$value ${memory.key}');
      if (norm.isEmpty) continue;

      var score = 0.0;
      for (final token in tokens) {
        if (norm.contains(token)) score += 2.0;
      }
      final updated = DateTime.tryParse(memory.updatedAt);
      if (updated != null) {
        final ageDays = DateTime.now().difference(updated).inDays;
        score += (30 - ageDays.clamp(0, 30)) / 30.0;
      }
      ranked.add(_RankedUserMemory(memory: memory, score: score));
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    if (tokens.isNotEmpty) {
      final hits = ranked.where((e) => e.score >= 2).toList();
      if (hits.isNotEmpty) {
        return _packUserMemories(hits, safeMax, maxRunes);
      }
    }

    final recent = [...memories]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _packUserMemories(
      recent.map((m) => _RankedUserMemory(memory: m, score: 0)).toList(),
      safeMax,
      maxRunes,
    );
  }

  static List<UserMemory> _packUserMemories(
    List<_RankedUserMemory> ranked,
    int maxItems,
    int maxRunes,
  ) {
    final out = <UserMemory>[];
    var runes = 0;
    final seen = <String>{};
    for (final item in ranked) {
      if (out.length >= maxItems) break;
      final key = item.memory.key;
      if (seen.contains(key)) continue;
      final valueRunes = item.memory.value.runes.length;
      if (runes + valueRunes > maxRunes && out.isNotEmpty) break;
      seen.add(key);
      runes += valueRunes;
      out.add(item.memory);
    }
    return out;
  }

  static Set<String> _extractQueryTokens(String text) {
    final tokens = <String>{};
    final han = RegExp(r'[\u4e00-\u9fa5]{2,}');
    final ascii = RegExp(r'[a-zA-Z0-9_]{2,}');
    for (final match in han.allMatches(text)) {
      tokens.add(match.group(0)!.toLowerCase());
    }
    for (final match in ascii.allMatches(text.toLowerCase())) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  /// 对记忆提交反馈（accept/reject/correct）
  static Future<UserMemory> submitUserMemoryFeedback({
    required String userId,
    required String key,
    required String feedbackType,
    String? correctedValue,
    String? reason,
  }) async {
    final result = await ApiService.post(
      '/api/user/$userId/memories/feedback',
      body: {
        'key': key,
        'feedback_type': feedbackType,
        if (correctedValue != null && correctedValue.isNotEmpty)
          'corrected_value': correctedValue,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return UserMemory.fromJson(
      ApiResponse.object(result, keys: const ['memory']),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 二、AI 聊天长期记忆（新增功能）
  // ═══════════════════════════════════════════════════════════════════════════

  static const _tagPattern = r'\[记忆:([^\]]{1,300})\]';

  /// 把已有记忆列表拼接到基础 system prompt 里（仅注入上下文，不要求 AI 打标签）
  ///
  /// 记忆提取由 AiMemoryOrchestrator + MemoryAgentService 在回合结束后后台完成。
  static String buildPromptWithMemories(
    String basePrompt,
    List<AiMemory> memories,
  ) {
    final buffer = StringBuffer();
    buffer.write(basePrompt.isNotEmpty ? basePrompt : '你是一位友好、智能的 AI 助手。');

    if (memories.isNotEmpty) {
      buffer.write('\n\n--- 你的长期记忆数据库 ---\n');
      buffer.write(
          '（以下是你之前和该用户聊天记住的事实。在回答时，如果相关，请自然地体现出你记得这些事，就像老朋友一样。不要生硬地罗列，只需在对话中表现出你“知道”即可）：\n');
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
  static String buildExtractionPrompt(
      String userMessage, String aiResponse, List<AiMemory> currentMemories) {
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
    if (RegExp(r'习惯|每天|每周|每月|经常|总是|routine|always|usually').hasMatch(content)) {
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
    if (RegExp(r'提醒|deadline|重要|urgent|紧急|不能忘|appointment').hasMatch(content)) {
      return 5;
    }
    if (RegExp(r'喜欢|讨厌|习惯|每天|每周').hasMatch(content)) {
      return 4;
    }
    return 3;
  }
}

class _RankedUserMemory {
  final UserMemory memory;
  final double score;

  const _RankedUserMemory({required this.memory, required this.score});
}
