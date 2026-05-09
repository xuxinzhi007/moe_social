import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_agent.dart';
import '../models/ai_memory.dart';
import '../models/ai_memory_profile.dart';
import '../models/ai_memory_settings.dart';
import 'ai_db_service.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';
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
    if (userMessage.trim().isEmpty || aiResponse.trim().isEmpty) return const [];
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
      if (allKnown.any((m) => MemoryService.isDuplicateMemory(m.content, text))) {
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
          confidence: ((item['confidence'] as num?)?.toDouble() ?? 0.7)
              .clamp(0.0, 1.0),
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

  Future<String> _callModel({
    required String model,
    required String userPrompt,
    required double temperature,
    required Duration timeout,
  }) async {
    final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();
    final uri = await LlmEndpointConfig.chatUri();
    ApiService.logDirectHttp('POST', uri);
    final token = ApiService.token;
    final headers = ApiService.mergeTunnelHeaders(uri, headers: {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': temperature,
            if (terminalMode) 'stream': false,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('模型调用失败: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (terminalMode) {
      final message = data is Map ? data['message'] : null;
      if (message is Map && message['content'] is String) {
        return message['content'] as String;
      }
    } else {
      if (data is Map && data['content'] is String) {
        return data['content'] as String;
      }
    }
    return '';
  }
}
