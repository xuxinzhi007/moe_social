import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ai_agent.dart';
import '../models/ai_memory.dart';
import '../models/ai_memory_profile.dart';
import '../models/ai_memory_settings.dart';
import '../models/ai_provider_profile.dart';
import 'ai_db_service.dart';
import 'ai_memory_learn_result.dart';
import 'llm_memory_config_service.dart';
import 'memory_extract_llm_client.dart';
import 'memory_daily_note.dart';
import 'memory_heuristic_extract.dart';
import 'memory_service.dart';

class MemoryAgentProcessResult {
  final int newMemoryCount;
  final int profileCount;

  const MemoryAgentProcessResult({
    required this.newMemoryCount,
    required this.profileCount,
  });
}

class MemoryAgentService {
  MemoryAgentService._();

  static final MemoryAgentService _instance = MemoryAgentService._();
  factory MemoryAgentService() => _instance;

  final AiDbService _db = AiDbService();

  Future<AiMemorySettings> getOrCreateSettings(AiAgent agent) async {
    final existing = await _db.getMemorySettings(agent.id);
    if (existing != null) return existing;
    final defaults = AiMemorySettings.defaults(
      agentId: agent.id,
      fallbackModel: agent.modelName,
    );
    await _db.upsertMemorySettings(defaults);
    return defaults;
  }

  Future<String> buildInjectedPrompt(AiAgent agent) async {
    final settings = await getOrCreateSettings(agent);
    final profiles = await _db.getMemoryProfiles(agent.id);
    final memories = await _db.getMemories(agent.id);

    final buffer = StringBuffer();
    buffer.write(
      agent.systemPrompt.isNotEmpty ? agent.systemPrompt : '你是一位友好、智能的 AI 助手。',
    );

    if (profiles.isNotEmpty) {
      buffer.write('\n\n=== 用户长期画像 ===\n');
      for (final profile in profiles) {
        buffer.write('- ${profile.title}：${profile.summary}\n');
      }
    }

    if (settings.injectMode != 'profile_only' && memories.isNotEmpty) {
      final rawCount = settings.maxInjectedRawItems.clamp(0, 20);
      final selected = memories.take(rawCount).toList();
      if (selected.isNotEmpty) {
        buffer.write('\n=== 当前高优先级原始记忆 ===\n');
        for (final memory in selected) {
          final (_, emoji) = AiMemory.categoryMeta(memory.category);
          buffer.write('- $emoji ${memory.content}\n');
        }
      }
    }

    buffer.write(
      '\n请把这些信息当作你已经了解的用户背景，在合适的时候自然参考，不要机械复述。',
    );
    return buffer.toString();
  }

  /// 账号级记忆：回合结束后提取并 Upsert（优先中转站，回退本机 llama.cpp）。
  Future<AiMemoryLearnResult> extractAndUpsertServerMemories({
    required String userId,
    required String userMessage,
    required String aiResponse,
    required String sessionId,
    required String sourceMsgId,
    String? model,
    AiProviderProfile? providerProfile,
    String? chatModel,
  }) async {
    if (userMessage.trim().isEmpty || aiResponse.trim().isEmpty) {
      return const AiMemoryLearnResult();
    }

    final configModel = await LlmMemoryConfigService().resolveMemoryModel(
      fallback: model?.trim() ?? '',
    );
    final extractModel = _resolveExtractModel(
      providerProfile: providerProfile,
      chatModel: chatModel,
      configModel: configModel,
    );
    final relayModel = _resolveRelayExtractModel(
      providerProfile: providerProfile,
      chatModel: chatModel,
    );

    var saved = 0;
    saved += await _upsertHeuristicMemories(
      userId: userId,
      userMessage: userMessage,
      sessionId: sessionId,
      sourceMsgId: sourceMsgId,
    );

    final prompt = '请分析以下对话，提取关于「用户本人」的新的、永久性信息。\n'
        '应提取：用户昵称/改名、偏好、职业、关系等。使用英文蛇形 key（如 user_nickname、user_preference）。\n'
        '不要提取：AI 角色自报名字、当晚临时扮演设定、纯闲聊。\n'
        '严格仅返回 JSON 数组，每项含 key 与 value。无新信息返回 []。不要 Markdown。\n\n'
        '用户：$userMessage\n助手：$aiResponse';

    String? extractError;
    try {
      final raw = await MemoryExtractLlmClient.complete(
        providerProfile: providerProfile,
        relayModel: providerProfile?.isOpenAiCompatible == true
            ? relayModel
            : '',
        extractModel: extractModel,
        userPrompt: prompt,
      );
      final items = _parseServerMemoryItems(raw);
      for (final item in items) {
        final key = (item['key'] as String? ?? '').trim();
        final value = (item['value'] as String? ?? '').trim();
        if (key.isEmpty || value.isEmpty) continue;
        try {
          await MemoryService.upsertUserMemory(
            userId: userId,
            key: key,
            value: value,
            memoryType: (item['memory_type'] as String?)?.trim(),
            confidence: (item['confidence'] as num?)?.toDouble(),
            source: 'llm_extract_client',
            sourceMsgId: sourceMsgId,
            sessionId: sessionId,
          );
          saved++;
        } catch (_) {}
      }
      if (kDebugMode && saved > 0) {
        debugPrint('🧠 [Memory] llm extract upsert saved=$saved');
      }
    } catch (e) {
      extractError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (kDebugMode) {
        debugPrint('🧠 [Memory] llm extract failed: $extractError');
      }
    }

    saved += await _upsertTaggedMemories(
      userId: userId,
      userMessage: userMessage,
      aiResponse: aiResponse,
      sessionId: sessionId,
      sourceMsgId: sourceMsgId,
    );

    try {
      final u = userMessage.trim();
      final a = aiResponse.trim();
      if (u.isNotEmpty || a.isNotEmpty) {
        final snippet = StringBuffer('回合');
        if (u.isNotEmpty) {
          snippet.write(' 用户:${_truncate(u, 80)}');
        }
        if (a.isNotEmpty) {
          snippet.write(' 助手:${_truncate(a, 120)}');
        }
        await MemoryDailyNote.appendObservation(
          userId,
          snippet.toString(),
          sessionId: sessionId,
          sourceMsgId: sourceMsgId,
        );
      }
    } catch (_) {}

    if (saved == 0 && extractError != null) {
      return AiMemoryLearnResult(
        savedCount: 0,
        errorMessage: '未能从对话中提取新记忆：$extractError',
      );
    }
    return AiMemoryLearnResult(savedCount: saved);
  }

  String _resolveExtractModel({
    AiProviderProfile? providerProfile,
    String? chatModel,
    required String configModel,
  }) {
    final fromAgent = chatModel?.trim() ?? '';
    if (fromAgent.isNotEmpty) return fromAgent;
    if (providerProfile != null) {
      final def = providerProfile.defaultModel.trim();
      if (def.isNotEmpty) return def;
      final manual = providerProfile.effectiveModelIds;
      if (manual.isNotEmpty) return manual.first;
    }
    final fb = configModel.trim();
    return fb.isNotEmpty ? fb : 'qwen2';
  }

  String _resolveRelayExtractModel({
    AiProviderProfile? providerProfile,
    String? chatModel,
  }) {
    final fromAgent = chatModel?.trim() ?? '';
    if (fromAgent.isNotEmpty) return fromAgent;
    final def = providerProfile?.defaultModel.trim() ?? '';
    if (def.isNotEmpty) return def;
    final manual = providerProfile?.effectiveModelIds ?? const [];
    if (manual.isNotEmpty) return manual.first;
    return '';
  }

  Future<int> _upsertHeuristicMemories({
    required String userId,
    required String userMessage,
    required String sessionId,
    required String sourceMsgId,
  }) async {
    final items = MemoryHeuristicExtract.fromUserMessage(userMessage);
    if (items.isEmpty) return 0;

    var saved = 0;
    for (final item in items) {
      final key = item['key'] ?? '';
      final value = item['value'] ?? '';
      if (key.isEmpty || value.isEmpty) continue;
      try {
        await MemoryService.upsertUserMemory(
          userId: userId,
          key: key,
          value: value,
          memoryType: item['memory_type'],
          source: 'heuristic_extract',
          sourceMsgId: sourceMsgId,
          sessionId: sessionId,
        );
        saved++;
        if (kDebugMode) {
          debugPrint('🧠 [Memory] heuristic saved key=$key value=$value');
        }
      } catch (_) {}
    }
    return saved;
  }

  Future<int> _upsertTaggedMemories({
    required String userId,
    required String userMessage,
    required String aiResponse,
    required String sessionId,
    required String sourceMsgId,
  }) async {
    final texts = <String>{
      ...MemoryService.extractMemories(userMessage),
      ...MemoryService.extractMemories(aiResponse),
    };
    if (texts.isEmpty) return 0;

    var saved = 0;
    for (final text in texts) {
      final value = text.trim();
      if (value.isEmpty) continue;
      final norm = MemoryService.normalizeMemoryText(value);
      final key = 'tag_${norm.hashCode.abs()}';
      try {
        await MemoryService.upsertUserMemory(
          userId: userId,
          key: key,
          value: value,
          memoryType: MemoryService.inferCategory(value),
          source: 'tag_extract',
          sourceMsgId: sourceMsgId,
          sessionId: sessionId,
        );
        saved++;
      } catch (_) {}
    }
    return saved;
  }

  /// OpenClaw 式遗忘：超出容量时 prune 低价值、过旧条目。
  Future<int> pruneStaleLocalMemories(String agentId,
      {int maxKeep = 40}) async {
    final memories = await _db.getMemories(agentId);
    if (memories.length <= maxKeep) return 0;

    final sorted = [...memories]..sort((a, b) {
        final imp = a.importance.compareTo(b.importance);
        if (imp != 0) return imp;
        return a.updatedAt.compareTo(b.updatedAt);
      });

    final toRemove = sorted.take(memories.length - maxKeep);
    var removed = 0;
    for (final memory in toRemove) {
      await _db.deleteMemory(memory.id);
      removed++;
    }
    return removed;
  }

  List<Map<String, dynamic>> _parseServerMemoryItems(String response) {
    var content = response.trim();
    if (content.isEmpty || content == '[]') return const [];
    content = content.replaceFirst(RegExp(r'^```json\s*'), '');
    content = content.replaceFirst(RegExp(r'^```\s*'), '');
    content = content.replaceFirst(RegExp(r'\s*```$'), '');
    try {
      final parsed = jsonDecode(content);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<MemoryAgentProcessResult> processConversationTurn({
    required AiAgent agent,
    required String sessionId,
    required String userMessage,
    required String aiResponse,
  }) async {
    final settings = await getOrCreateSettings(agent);
    if (!settings.autoExtract) {
      final profileCount = (await _db.getMemoryProfiles(agent.id)).length;
      return MemoryAgentProcessResult(
        newMemoryCount: 0,
        profileCount: profileCount,
      );
    }

    final existingMemories = await _db.getMemories(agent.id);
    final newMemories = await _extractNewMemories(
      agent: agent,
      settings: settings,
      userMessage: userMessage,
      aiResponse: aiResponse,
      existingMemories: existingMemories,
    );

    var profileCount = (await _db.getMemoryProfiles(agent.id)).length;
    final totalMemories = existingMemories.length + newMemories.length;
    final shouldCurate = settings.autoCurate &&
        (newMemories.isNotEmpty &&
            (totalMemories % settings.curateEveryNMemories == 0 ||
                profileCount == 0));

    if (shouldCurate) {
      final profiles = await curateProfiles(agent: agent, settings: settings);
      profileCount = profiles.length;
    }

    await pruneStaleLocalMemories(agent.id);

    return MemoryAgentProcessResult(
      newMemoryCount: newMemories.length,
      profileCount: profileCount,
    );
  }

  Future<List<AiMemory>> _extractNewMemories({
    required AiAgent agent,
    required AiMemorySettings settings,
    required String userMessage,
    required String aiResponse,
    required List<AiMemory> existingMemories,
  }) async {
    if (userMessage.trim().isEmpty || aiResponse.trim().isEmpty) {
      return const [];
    }
    if (aiResponse.startsWith('Ollama 错误') ||
        aiResponse.startsWith('请求失败') ||
        aiResponse.startsWith('请求出错') ||
        aiResponse.startsWith('响应格式异常')) {
      return const [];
    }

    final prompt = MemoryService.buildExtractionPrompt(
      userMessage,
      aiResponse,
      existingMemories,
    );
    final extracted = await _callModel(
      model: settings.extractModel,
      userPrompt: prompt,
      temperature: 0.1,
      timeout: const Duration(seconds: 45),
    );
    final texts = MemoryService.extractMemories(extracted);
    if (texts.isEmpty) return const [];

    final newMemories = <AiMemory>[];
    final allKnown = [...existingMemories];
    for (var i = 0; i < texts.length; i++) {
      final text = texts[i].trim();
      if (text.isEmpty) continue;
      if (allKnown
          .any((m) => MemoryService.isDuplicateMemory(m.content, text))) {
        continue;
      }
      final now = DateTime.now();
      final memory = AiMemory(
        id: '${now.millisecondsSinceEpoch}_$i',
        agentId: agent.id,
        content: text,
        category: MemoryService.inferCategory(text),
        importance: MemoryService.inferImportance(text),
        createdAt: now,
        updatedAt: now,
      );
      await _db.insertMemory(memory);
      newMemories.add(memory);
      allKnown.add(memory);
    }
    return newMemories;
  }

  Future<List<AiMemoryProfile>> curateProfiles({
    required AiAgent agent,
    AiMemorySettings? settings,
  }) async {
    final localSettings = settings ?? await getOrCreateSettings(agent);
    final memories = await _db.getMemories(agent.id);
    if (memories.isEmpty) {
      await _db.clearMemoryProfiles(agent.id);
      return const [];
    }

    final prompt = MemoryService.buildCurationPrompt(memories);
    final raw = await _callModel(
      model: localSettings.curateModel,
      userPrompt: prompt,
      temperature: 0.1,
      timeout: const Duration(seconds: 60),
    );
    final parsed = MemoryService.parseProfiles(raw);
    if (parsed.isEmpty) return await _db.getMemoryProfiles(agent.id);

    final now = DateTime.now();
    final profiles = <AiMemoryProfile>[];
    for (var i = 0; i < parsed.length; i++) {
      final item = parsed[i];
      final title = (item['title'] as String? ?? '').trim();
      final summary = (item['summary'] as String? ?? '').trim();
      if (title.isEmpty || summary.isEmpty) continue;
      profiles.add(
        AiMemoryProfile(
          id: '${agent.id}_profile_$i',
          agentId: agent.id,
          profileType: (item['profile_type'] as String? ?? 'general').trim(),
          title: title,
          summary: summary,
          confidence:
              ((item['confidence'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
          updatedAt: now,
        ),
      );
    }

    if (profiles.isNotEmpty) {
      await _db.replaceMemoryProfiles(agent.id, profiles);
      return profiles;
    }
    return await _db.getMemoryProfiles(agent.id);
  }

  static String _truncate(String s, int max) {
    final r = s.runes.toList();
    if (r.length <= max) return s;
    return '${String.fromCharCodes(r.take(max))}…';
  }

  /// 本地 Agent 记忆整理（优先本机 llama.cpp）。
  Future<String> _callModel({
    required String model,
    required String userPrompt,
    required double temperature,
    required Duration timeout,
  }) async {
    return MemoryExtractLlmClient.complete(
      providerProfile: null,
      relayModel: '',
      extractModel: model,
      userPrompt: userPrompt,
      timeout: timeout,
    );
  }
}
