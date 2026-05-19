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
import 'ai_provider_service.dart';
import 'api_service.dart';
import 'llm_endpoint_config.dart';
import 'memory_agent_service.dart';
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
    final mode = await resolveMode(agent);
    if (mode == AiMemoryMode.disabled) return basePrompt;

    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );
    if (mode == AiMemoryMode.server && profile.isBackendOllama) {
      return basePrompt;
    }

    if (mode == AiMemoryMode.server) {
      return _injectServerMemories(basePrompt, latestUserMessage);
    }

    return _agent.buildInjectedPrompt(agent);
  }

  void learnFromTurnInBackground({
    required AiAgent agent,
    required String sessionId,
    required String userMessage,
    required String aiResponse,
    String? sourceMsgId,
  }) {
    unawaited(
      _learnFromTurn(
        agent: agent,
        sessionId: sessionId,
        userMessage: userMessage,
        aiResponse: aiResponse,
        sourceMsgId: sourceMsgId,
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
  }) async {
    if (userMessage.trim().isEmpty || aiResponse.trim().isEmpty) return;
    if (_isErrorLikeResponse(aiResponse)) return;

    final mode = await resolveMode(agent);
    if (mode == AiMemoryMode.disabled) return;

    final profile = await AiProviderService().resolveProfile(
      agent.providerProfileId,
    );

    if (profile.isBackendOllama) return;
    try {
      final user = await AuthService.getUserInfo();
      await _agent.extractAndUpsertServerMemories(
        userId: user.id,
        userMessage: userMessage,
        aiResponse: aiResponse,
        sessionId: sessionId,
        sourceMsgId: sourceMsgId ?? '',
        model: agent.modelName,
      );
    } catch (_) {}
  }

  Future<String> _injectServerMemories(
    String basePrompt,
    String latestUserMessage, {
    List<UserMemory>? preloadedMemories,
  }) async {
    try {
      final filtered = preloadedMemories == null
          ? () async {
              final user = await AuthService.getUserInfo();
              final raw = await MemoryService.getUserMemories(user.id);
              return MemoryService.filterUserFacingMemories(raw);
            }()
          : Future.value(
              MemoryService.filterUserFacingMemories(preloadedMemories),
            );
      final resolved = await filtered;
      if (resolved.isEmpty) return basePrompt;
      final selected = MemoryService.selectRelevantUserMemories(
        memories: resolved,
        queryText: latestUserMessage,
      );
      if (selected.isEmpty) return basePrompt;

      final buffer = StringBuffer();
      buffer.write(
        basePrompt.isNotEmpty ? basePrompt : '你是一位友好、智能的 AI 助手。',
      );
      buffer.write('\n\n用户的长期背景与偏好信息如下，请在回答时适当参考：\n');
      for (final memory in selected) {
        buffer.write('- ${memory.value}\n');
      }
      buffer.write(
        '\n请把这些信息当作你已经了解的用户背景，在合适的时候自然参考，不要机械复述。',
      );
      return buffer.toString();
    } catch (_) {
      return basePrompt;
    }
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
