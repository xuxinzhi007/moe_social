import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../models/ai_agent.dart';
import '../models/ai_memory.dart';
import '../models/ai_memory_profile.dart';
import '../models/user_memory.dart';
import '../models/user_memory_display.dart';
import '../models/user_memory_profile.dart';
import 'ai_db_service.dart';
import 'ai_memory_learn_result.dart';
import 'ai_provider_service.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';
import 'memory_agent_service.dart';
import 'memory_daily_note.dart';
import 'memory_service.dart';

/// 记忆子系统路由（参考 OpenClaw：画像为源、检索注入、回合后写入、定期整理）。
///
/// 页面层请只通过 [AiMemoryOrchestrator] 访问记忆能力，勿直接调用
/// [MemoryService] / [MemoryAgentService]。
enum AiMemoryMode {
  server,
  local,
  disabled,
}

/// 单次对话 system prompt 记忆注入结果（供聊天页展示状态）。
class AiMemoryEnrichResult {
  final String prompt;
  final int injectedCount;
  final int availableCount;
  final AiMemoryMode mode;
  final bool injectedByServer;
  final String statusLine;

  const AiMemoryEnrichResult({
    required this.prompt,
    required this.injectedCount,
    required this.availableCount,
    required this.mode,
    required this.injectedByServer,
    required this.statusLine,
  });
}

/// 聊天页记忆预览（抽屉角标等）。
class AiMemoryChatPreview {
  final AiMemoryMode mode;
  final int count;
  final String modeLabel;

  const AiMemoryChatPreview({
    required this.mode,
    required this.count,
    required this.modeLabel,
  });
}

/// 记忆管理页聚合状态。
class AiMemoryManagerState {
  final AiMemoryMode activeMode;
  final String activeModeLabel;
  final String activeModeDescription;
  final List<UserMemory> accountMemories;
  final List<UserMemoryProfile> accountProfiles;
  final UserMemoryDisplayData? display;
  final List<AiMemory> localMemories;
  final List<AiMemoryProfile> localProfiles;
  final String promptPreview;
  final bool terminalModeEnabled;
  final Map<String, dynamic>? llmConfig;

  const AiMemoryManagerState({
    required this.activeMode,
    required this.activeModeLabel,
    required this.activeModeDescription,
    required this.accountMemories,
    required this.accountProfiles,
    this.display,
    required this.localMemories,
    required this.localProfiles,
    required this.promptPreview,
    required this.terminalModeEnabled,
    this.llmConfig,
  });
}

class AiMemoryOrchestrator {
  AiMemoryOrchestrator._();

  static final AiMemoryOrchestrator _instance = AiMemoryOrchestrator._();
  factory AiMemoryOrchestrator() => _instance;

  final MemoryAgentService _agent = MemoryAgentService();
  final AiDbService _db = AiDbService();
  final Map<String, int> _turnCounters = {};
  AiMemoryTurnStats _turnStats = const AiMemoryTurnStats();

  /// 上一回合注入/写入统计（供设置 Sheet 展示）。
  AiMemoryTurnStats get turnStats => _turnStats;

  // ─── 模式 ───────────────────────────────────────────────────────────────

  Future<AiMemoryMode> resolveMode(AiAgent agent) async {
    if (await LlmEndpointConfig.isTerminalModeEnabled()) {
      return AiMemoryMode.disabled;
    }
    // 产品路径：登录用户统一走后端记忆，不在客户端暴露 local/server 双轨。
    return AiMemoryMode.server;
  }

  String modeLabel(AiMemoryMode mode) => switch (mode) {
        AiMemoryMode.server => '关于你的记忆',
        AiMemoryMode.local => '关于你的记忆',
        AiMemoryMode.disabled => '记忆未开启',
      };

  String modeDescription(AiMemoryMode mode) => switch (mode) {
        AiMemoryMode.server => '聊天时会自动参考你已保存的信息，无需手动设置。',
        AiMemoryMode.local => '聊天时会自动参考你已保存的信息，无需手动设置。',
        AiMemoryMode.disabled => '开发者调试模式已开启，记忆功能已暂停。',
      };

  // ─── 聊天 / 内容生成 ─────────────────────────────────────────────────────

  Future<String> enrichSystemPrompt({
    required AiAgent agent,
    required String basePrompt,
    String latestUserMessage = '',
  }) async {
    final result = await enrichSystemPromptWithMeta(
      agent: agent,
      basePrompt: basePrompt,
      latestUserMessage: latestUserMessage,
    );
    return result.prompt;
  }

  Future<AiMemoryEnrichResult> enrichSystemPromptWithMeta({
    required AiAgent agent,
    required String basePrompt,
    String latestUserMessage = '',
  }) async {
    final mode = await resolveMode(agent);
    if (mode == AiMemoryMode.disabled) {
      return AiMemoryEnrichResult(
        prompt: basePrompt,
        injectedCount: 0,
        availableCount: 0,
        mode: mode,
        injectedByServer: false,
        statusLine: modeDescription(mode),
      );
    }

    if (!await _isUserAuthenticated()) {
      return AiMemoryEnrichResult(
        prompt: basePrompt,
        injectedCount: 0,
        availableCount: 0,
        mode: mode,
        injectedByServer: false,
        statusLine: '请先登录账号，记忆才会在对话中生效',
      );
    }

    final account = await _loadAccountMemoryState();
    final availableCount = account.memories.length;
    final profile = await AiProviderService().resolveProfile(agent.providerProfileId);
    final memoryToolsAdvanced = profile.supportsToolCalls &&
        (profile.isLocalGguf || !profile.isBackendOllama);

    if (mode == AiMemoryMode.server) {
      final injected = await _queryMemoriesForInject(
        query: latestUserMessage,
        fallbackMemories: account.memories,
      );
      final hasBootstrap = account.display != null &&
          account.display!.profiles.any((p) => p.summary.trim().isNotEmpty);

      final prompt = await _composeMemoryPrompt(
        basePrompt,
        display: account.display,
        selectedMemories: injected,
        memoryToolsAdvanced: memoryToolsAdvanced,
      );
      final injectedCount = injected.length;
      _turnStats = AiMemoryTurnStats(
        lastInjectedCount: injectedCount,
        lastSavedCount: _turnStats.lastSavedCount,
        lastLearnError: _turnStats.lastLearnError,
        updatedAt: DateTime.now(),
      );
      return AiMemoryEnrichResult(
        prompt: prompt,
        injectedCount: injectedCount,
        availableCount: availableCount,
        mode: mode,
        injectedByServer: false,
        statusLine: injectedCount > 0
            ? '已从记忆库查询并参考 $injectedCount 条'
            : (hasBootstrap
                ? '已加载用户画像摘要'
                : (availableCount > 0
                    ? '记忆库共 $availableCount 条，本句暂无强相关命中'
                    : '继续聊天后会自动写入记忆库')),
      );
    }

    final prompt = await _agent.buildInjectedPrompt(agent);
    return AiMemoryEnrichResult(
      prompt: prompt,
      injectedCount: 0,
      availableCount: availableCount,
      mode: mode,
      injectedByServer: false,
      statusLine: '使用本地记忆模式',
    );
  }

  void learnFromTurnInBackground({
    required AiAgent agent,
    required String sessionId,
    required String userMessage,
    required String aiResponse,
    String? sourceMsgId,
    void Function(AiMemoryLearnResult result)? onComplete,
  }) {
    unawaited(
      _learnFromTurn(
        agent: agent,
        sessionId: sessionId,
        userMessage: userMessage,
        aiResponse: aiResponse,
        sourceMsgId: sourceMsgId,
        onComplete: onComplete,
      ),
    );
  }

  /// 聊天抽屉等处的记忆数量预览。
  Future<AiMemoryChatPreview> loadChatMemoryPreview(AiAgent agent) async {
    final mode = await resolveMode(agent);
    if (mode == AiMemoryMode.disabled) {
      return AiMemoryChatPreview(
        mode: mode,
        count: 0,
        modeLabel: modeLabel(mode),
      );
    }
    try {
      final user = await AuthService.getUserInfo();
      final display = await MemoryService.getUserMemoriesDisplay(user.id);
      return AiMemoryChatPreview(
        mode: mode,
        count: display.total,
        modeLabel: modeLabel(mode),
      );
    } catch (_) {
      return AiMemoryChatPreview(
        mode: mode,
        count: 0,
        modeLabel: modeLabel(mode),
      );
    }
  }

  // ─── 记忆管理页 ───────────────────────────────────────────────────────────

  Future<AiMemoryManagerState> loadManagerState(AiAgent agent) async {
    final mode = await resolveMode(agent);
    final terminal = await LlmEndpointConfig.isTerminalModeEnabled();
    final ({
      List<UserMemory> memories,
      List<UserMemoryProfile> profiles,
      UserMemoryDisplayData? display,
    }) account;
    if (mode == AiMemoryMode.disabled) {
      account = (
        memories: <UserMemory>[],
        profiles: <UserMemoryProfile>[],
        display: null,
      );
    } else {
      account = await _loadAccountMemoryState();
    }

    return AiMemoryManagerState(
      activeMode: mode,
      activeModeLabel: modeLabel(mode),
      activeModeDescription: modeDescription(mode),
      accountMemories: account.memories,
      accountProfiles: account.profiles,
      display: account.display,
      localMemories: const [],
      localProfiles: const [],
      promptPreview: '',
      terminalModeEnabled: terminal,
      llmConfig: const {},
    );
  }

  Future<String> buildPromptPreview({
    required AiAgent agent,
    required String basePrompt,
    String latestUserMessage = '',
  }) async {
    final enriched = await enrichSystemPrompt(
      agent: agent,
      basePrompt: basePrompt,
      latestUserMessage: latestUserMessage,
    );
    if (enriched.trim() == basePrompt.trim()) {
      return '$basePrompt\n\n（当前暂无可注入记忆）';
    }
    return enriched;
  }

  Future<void> deleteAccountMemory(UserMemory memory) async {
    await MemoryService.deleteUserMemoryByKey(memory.userId, memory.key);
  }

  Future<void> clearAllAccountMemories(List<UserMemory> memories) async {
    for (final m in memories) {
      await MemoryService.deleteUserMemoryByKey(m.userId, m.key);
    }
  }

  Future<void> deleteLocalMemory(String memoryId) async {
    await _db.deleteMemory(memoryId);
  }

  Future<void> clearLocalMemories(String agentId) async {
    await _db.clearMemories(agentId);
    await _db.clearMemoryProfiles(agentId);
  }

  // ─── 内部 ─────────────────────────────────────────────────────────────────

  Future<void> _learnFromTurn({
    required AiAgent agent,
    required String sessionId,
    required String userMessage,
    required String aiResponse,
    String? sourceMsgId,
    void Function(AiMemoryLearnResult result)? onComplete,
  }) async {
    if (userMessage.trim().isEmpty || aiResponse.trim().isEmpty) return;
    if (_isErrorLikeResponse(aiResponse)) return;

    final mode = await resolveMode(agent);
    if (mode == AiMemoryMode.disabled) return;

    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );

    if (profile.isBackendOllama) {
      // 主聊天仍走 /api/llm/chat，由服务端异步提取；避免客户端重复提取。
      return;
    }
    if (!await _isUserAuthenticated()) return;
    AiMemoryLearnResult result = const AiMemoryLearnResult();
    try {
      final user = await AuthService.getUserInfo();
      result = await _agent.extractAndUpsertServerMemories(
        userId: user.id,
        userMessage: userMessage,
        aiResponse: aiResponse,
        sessionId: sessionId,
        sourceMsgId: sourceMsgId ?? '',
        providerProfile: profile,
        chatModel: agent.modelName,
      );
    } catch (e) {
      result = AiMemoryLearnResult(
        errorMessage: e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      );
    }
    _turnStats = AiMemoryTurnStats(
      lastInjectedCount: _turnStats.lastInjectedCount,
      lastSavedCount: result.savedCount,
      lastLearnError: result.errorMessage,
      updatedAt: DateTime.now(),
    );
    onComplete?.call(result);
  }

  Future<bool> _isUserAuthenticated() async {
    final token = ApiService.token;
    return token != null && token.trim().isNotEmpty;
  }

  Future<List<UserMemory>> _loadUserFacingMemories() async {
    try {
      final user = await AuthService.getUserInfo();
      final display = await MemoryService.getUserMemoriesDisplay(user.id);
      return display.items
          .map(
            (item) => UserMemory(
              id: item.id,
              userId: user.id,
              key: item.key,
              value: item.content,
              memoryType: item.category,
              createdAt: item.updatedAt,
              updatedAt: item.updatedAt,
            ),
          )
          .toList();
    } catch (_) {
      try {
        final user = await AuthService.getUserInfo();
        final raw = await MemoryService.getUserMemories(user.id);
        return MemoryService.filterUserFacingMemories(raw);
      } catch (_) {
        return const [];
      }
    }
  }

  /// 默认路径：后端记忆文本库检索（1 次 HTTP，不增加聊天轮次）。
  Future<List<UserMemory>> _queryMemoriesForInject({
    required String query,
    required List<UserMemory> fallbackMemories,
  }) async {
    try {
      final user = await AuthService.getUserInfo();
      return await MemoryService.searchUserMemories(
        user.id,
        query: query,
        limit: 8,
      );
    } catch (_) {
      var injected = MemoryService.selectRelevantUserMemories(
        memories: fallbackMemories,
        queryText: query,
      );
      if (injected.isEmpty && fallbackMemories.isNotEmpty) {
        final recent = [...fallbackMemories]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        injected = recent.take(3).toList();
      }
      return injected;
    }
  }

  Future<String> _composeMemoryPrompt(
    String basePrompt, {
    UserMemoryDisplayData? display,
    required List<UserMemory> selectedMemories,
    bool memoryToolsAdvanced = false,
  }) async {
    final buffer = StringBuffer();
    buffer.write(
      basePrompt.isNotEmpty ? basePrompt : '你是一位友好、智能的 AI 助手。',
    );

    final profiles = display?.profiles ?? const [];
    final profileLines = profiles
        .where((p) => p.summary.trim().isNotEmpty)
        .take(6)
        .map((p) => '- ${p.title}：${p.summary.trim()}')
        .toList();
    if (profileLines.isNotEmpty) {
      buffer.write('\n\n=== 用户长期画像（精选层 / MEMORY）===\n');
      buffer.writeAll(profileLines, '\n');
      buffer.write('\n');
    }

    var hasDaily = false;
    try {
      final user = await AuthService.getUserInfo();
      final daily = await MemoryDailyNote.loadRecent(user.id);
      if (daily.isNotEmpty) {
        hasDaily = true;
        buffer.write('\n=== 近期日记（工作记忆，今日/昨日）===\n');
        for (final d in daily) {
          buffer.write('[${d.date}]\n${d.body}\n');
        }
      }
    } catch (_) {}

    if (selectedMemories.isNotEmpty) {
      buffer.write('\n=== 与本句相关的记忆检索 ===\n');
      for (final memory in selectedMemories) {
        buffer.write('- ${memory.value}\n');
      }
    }

    if (profileLines.isNotEmpty || hasDaily || selectedMemories.isNotEmpty) {
      buffer.write(
        '\n请把这些信息当作你已经了解的用户背景，在合适的时候自然参考，不要机械复述。',
      );
    }
    if (memoryToolsAdvanced) {
      buffer.write(
        '\n\n【高级】已开启模型多轮工具（仍以上方自动注入为准，不足时可调用）：'
        ' memory_search、memory_get、memory_save、memory_list、memory_read_daily、memory_delete。'
        ' 不要编造记忆库中不存在的内容；写入用户事实用 memory_save。',
      );
    }
    return buffer.toString();
  }

  Future<Map<String, dynamic>> _loadLlmConfig() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/config');
      ApiService.logDirectHttp('GET', uri);
      final response = await http
          .get(
            uri,
            headers: ApiService.mergeTunnelHeaders(uri, headers: {
              if (ApiService.token case final t?) 'Authorization': 'Bearer $t',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const {};
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! Map) return const {};
      return Map<String, dynamic>.from(decoded['data'] as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<
      ({
        List<UserMemory> memories,
        List<UserMemoryProfile> profiles,
        UserMemoryDisplayData? display,
      })> _loadAccountMemoryState() async {
    try {
      final user = await AuthService.getUserInfo();
      final display = await MemoryService.getUserMemoriesDisplay(user.id);
      final memories = display.items
          .map(
            (item) => UserMemory(
              id: item.id,
              userId: user.id,
              key: item.key,
              value: item.content,
              memoryType: item.category,
              createdAt: item.updatedAt,
              updatedAt: item.updatedAt,
            ),
          )
          .toList();
      final profiles = display.profiles
          .map(
            (p) => UserMemoryProfile(
              memoryType: p.title,
              summary: p.summary,
              itemCount: p.itemCount,
              confidence: 0,
            ),
          )
          .toList();
      return (memories: memories, profiles: profiles, display: display);
    } catch (_) {
      return (
        memories: <UserMemory>[],
        profiles: <UserMemoryProfile>[],
        display: null,
      );
    }
  }

  bool _isErrorLikeResponse(String text) {
    return text.startsWith('Ollama 错误') ||
        text.startsWith('请求失败') ||
        text.startsWith('请求出错') ||
        text.startsWith('响应格式异常') ||
        text.startsWith('Provider 请求失败') ||
        text.startsWith('生成失败');
  }
}
