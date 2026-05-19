import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_lorebook_service.dart';
import '../../services/ai_roleplay_prompt_builder.dart';
import '../../services/ai_user_persona_service.dart';
import '../../services/ai_memory_orchestrator.dart';
import 'memory_manager_page.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_session.dart';
import '../../models/ai_chat_message.dart';
import '../../models/ai_provider_profile.dart';
import '../../models/user_memory.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_typing_indicator.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_chat_empty_state.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class ChatPage extends StatefulWidget {
  final AiAgent agent;

  const ChatPage({super.key, required this.agent});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Web 端优先走后端与内存会话，避免本地 sqflite 导致页面长时间阻塞。
  final bool _localPersistenceEnabled = !kIsWeb;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  List<AiChatMessage> _messages = [];
  List<UserMemory> _memories = [];
  AiMemoryMode _memoryMode = AiMemoryMode.disabled;
  String _memoryHeadline = '关于你的记忆';
  String _systemPrompt = '';
  String _userPersona = '';

  bool _isSending = false;
  bool _isLoadingHistory = true;
  bool _wasManuallyStopped = false;
  bool _isSyncingModelPrompt = false;

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String? _speakingMessageId;

  // Search
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  List<AiChatMessage> _searchResults = [];

  // Quick Replies
  bool _showQuickReplies = false;
  List<String> _quickReplies = [
    '你好，今天过得怎么样？',
    '能帮我解释一下这个概念吗？',
    '有什么好的建议吗？',
    '如何提高学习效率？',
    '推荐一些好书给我吧',
    '帮我制定一个计划',
  ];

  // Message Marking
  Set<String> _markedMessages = {};

  // Edit Message
  String? _editingMessageId;

  bool get _isBackendProviderAgent =>
      widget.agent.providerProfileId == null ||
      widget.agent.providerProfileId == AiProviderProfile.builtinBackendId;

  String get _providerSourceLabel =>
      _isBackendProviderAgent ? '服务器 Ollama' : '我的 API';

  @override
  void initState() {
    super.initState();
    _systemPrompt = widget.agent.systemPrompt.trim().isNotEmpty
        ? widget.agent.systemPrompt
        : AiPromptDefaults.defaultAgentSystemPrompt;
    _initVoice();
    _loadMemoryState();
    _loadUserPersona();
    if (_localPersistenceEnabled) {
      _loadSessions();
    } else {
      _loadWebCachedSession();
    }
  }

  @override
  void dispose() {
    if (!_localPersistenceEnabled) {
      unawaited(_persistWebCache());
    }
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _speech.stop();
    _tts.stop();
    _tts.setCompletionHandler(() {}); // 解除业务回调（API 要求非 null 的 void Function()）
    super.dispose();
  }

  String get _webCacheKey => 'chat_web_cache_${widget.agent.id}';

  Future<void> _loadWebCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is Map) {
          final sessionsRaw = data['sessions'];
          final messagesRaw = data['messages'];
          final currentSessionId = data['current_session_id'] as String?;
          final savedPrompt = data['system_prompt'] as String?;
          final sessions = sessionsRaw is List
              ? sessionsRaw
                  .whereType<Map>()
                  .map((e) =>
                      AiChatSession.fromMap(Map<String, dynamic>.from(e)))
                  .toList()
              : <AiChatSession>[];
          final messages = messagesRaw is List
              ? messagesRaw
                  .whereType<Map>()
                  .map((e) =>
                      AiChatMessage.fromMap(Map<String, dynamic>.from(e)))
                  .toList()
              : <AiChatMessage>[];

          AiChatSession? current;
          if (sessions.isNotEmpty && currentSessionId != null) {
            final idx = sessions.indexWhere((s) => s.id == currentSessionId);
            if (idx != -1) current = sessions[idx];
          }
          current ??= sessions.isNotEmpty ? sessions.first : null;

          if (mounted && current != null) {
            setState(() {
              _sessions = sessions;
              _currentSession = current;
              _messages =
                  messages.where((m) => m.sessionId == current!.id).toList();
              if (savedPrompt != null) {
                _systemPrompt = savedPrompt;
              }
              _isLoadingHistory = false;
            });
            _scrollToBottom();
            return;
          }
        }
      }
    } catch (_) {}

    await _createNewSession();
    if (mounted) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _persistWebCache() async {
    if (_localPersistenceEnabled) return;
    if (_currentSession == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'sessions': _sessions.map((s) => s.toMap()).toList(),
        'messages': _messages.map((m) => m.toMap()).toList(),
        'current_session_id': _currentSession!.id,
        'system_prompt': _systemPrompt,
      };
      await prefs.setString(_webCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _initVoice() async {
    try {
      _speechAvailable = await _speech.initialize();
      await _tts.setLanguage('zh-CN');
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    if (!_localPersistenceEnabled) return;
    final sessions = await AiDbService().getSessions(widget.agent.id);
    if (mounted) {
      setState(() => _sessions = sessions);
      if (_sessions.isNotEmpty) {
        _loadSession(_sessions.first);
      } else {
        _createNewSession();
      }
    }
  }

  int get _memoryPreviewCount {
    if (_memoryMode == AiMemoryMode.disabled) return 0;
    return _memories.length;
  }

  Future<void> _loadMemoryState() async {
    try {
      final orchestrator = AiMemoryOrchestrator();
      final state = await orchestrator.loadManagerState(widget.agent);
      if (!mounted) return;
      setState(() {
        _memoryMode = state.activeMode;
        _memoryHeadline = state.display?.headline.isNotEmpty == true
            ? state.display!.headline
            : state.activeModeLabel;
        _memories = state.accountMemories;
      });
    } catch (_) {
      // 记忆预览失败不影响主聊天链路
    }
  }

  Future<void> _loadUserPersona() async {
    try {
      final persona = await AiUserPersonaService().loadPersona();
      if (!mounted) return;
      setState(() => _userPersona = persona);
    } catch (_) {}
  }

  Future<void> _editUserPersona() async {
    final controller = TextEditingController(text: _userPersona);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '用户 Persona',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '用于告诉角色“你是谁、偏好什么、和角色处于什么关系”。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '例如：我是一个偏理性但容易焦虑的产品经理，希望对方叫我阿栀，回答尽量直接一点。',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.clear();
                  },
                  child: const Text('清空'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      final next = controller.text.trim();
      await AiUserPersonaService().savePersona(next);
      if (!mounted) return;
      setState(() => _userPersona = next);
      MoeToast.success(context, '用户 Persona 已保存');
    }
    controller.dispose();
  }

  Future<void> _createNewSession() async {
    final session = AiChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      agentId: widget.agent.id,
      title: '新对话',
      updatedAt: DateTime.now(),
    );
    if (_localPersistenceEnabled) {
      await AiDbService().insertSession(session);
    }
    if (mounted) {
      setState(() => _sessions.insert(0, session));
      _loadSession(session);
      unawaited(_seedOpeningMessageIfNeeded(session));
      unawaited(_persistWebCache());
    }
  }

  Future<void> _seedOpeningMessageIfNeeded(AiChatSession session) async {
    final opening = widget.agent.openingMessage.trim();
    if (opening.isEmpty) return;
    final greeting = AiChatMessage(
      id: '${session.id}_opening',
      sessionId: session.id,
      role: 'assistant',
      content: opening,
      createdAt: DateTime.now(),
    );
    if (_localPersistenceEnabled) {
      final existing = await AiDbService().getMessages(session.id);
      if (existing.isNotEmpty) return;
      await AiDbService().insertMessage(greeting);
    }
    if (!mounted) return;
    if (_currentSession?.id != session.id) return;
    if (_messages.isNotEmpty) return;
    setState(() => _messages = [greeting]);
    unawaited(_persistWebCache());
    _scrollToBottom();
  }

  Future<void> _loadSession(AiChatSession session) async {
    setState(() {
      _currentSession = session;
      _isLoadingHistory = true;
    });
    final messages = _localPersistenceEnabled
        ? await AiDbService().getMessages(session.id)
        : <AiChatMessage>[];
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
      unawaited(_persistWebCache());
    }
  }

  Future<void> _deleteSession(String id) async {
    if (_localPersistenceEnabled) {
      await AiDbService().deleteSession(id);
    }
    if (mounted) {
      setState(() {
        _sessions.removeWhere((s) => s.id == id);
        if (_currentSession?.id == id) {
          if (_sessions.isNotEmpty) {
            _loadSession(_sessions.first);
          } else {
            _createNewSession();
          }
        }
      });
      unawaited(_persistWebCache());
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    if (_currentSession == null) await _createNewSession();

    final now = DateTime.now();
    final userMsg = AiChatMessage(
      id: _editingMessageId ?? now.millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'user',
      content: text,
      createdAt: now,
    );
    // 重置编辑消息ID
    _editingMessageId = null;

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _isSending = true;
      _wasManuallyStopped = false;
    });
    _scrollToBottom();
    if (_localPersistenceEnabled) {
      await AiDbService().insertMessage(userMsg);
    }

    try {
      // ── 构建对话历史（排除 system 角色，避免重复） ──────────────────
      final history = _messages
          .where((m) => m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final lorebookEntries = await AiLorebookService().resolveEntriesForAgent(
        agent: widget.agent,
        latestUserMessage: text,
        recentConversation: _messages
            .where((m) => m.role != 'system')
            .map((m) => m.content)
            .toList(),
      );

      // 后续可在 provider 层做更细粒度 prompt 组合；当前先完成角色卡基础层。
      var enrichedSystemPrompt = _withNoAiSelfDisclosureRule(
        AiRoleplayPromptBuilder.buildSystemPrompt(
          widget.agent,
          overrideSystemPrompt: _systemPrompt.trim().isNotEmpty
              ? _systemPrompt.trim()
              : AiPromptDefaults.defaultAgentSystemPrompt,
          userPersona: _userPersona,
          lorebookEntries: lorebookEntries,
        ),
      );
      enrichedSystemPrompt = await AiMemoryOrchestrator().enrichSystemPrompt(
        agent: widget.agent,
        basePrompt: enrichedSystemPrompt,
        latestUserMessage: text,
      );
      history.insert(0, {'role': 'system', 'content': enrichedSystemPrompt});

      if (_wasManuallyStopped) return;
      final content = await AiChatGatewayService().sendChat(
        agent: widget.agent,
        messages: history,
        sessionId: _currentSession?.id,
        sourceMsgId: userMsg.id,
      );
      if (_wasManuallyStopped) return;
      final assistantMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: _currentSession!.id,
        role: 'assistant',
        content: content,
        createdAt: DateTime.now(),
      );

      if (_localPersistenceEnabled) {
        await AiDbService().insertMessage(assistantMsg);
      }

      if (mounted) {
        setState(() => _messages.add(assistantMsg));
        unawaited(_persistWebCache());

        AiMemoryOrchestrator().learnFromTurnInBackground(
          agent: widget.agent,
          sessionId: _currentSession!.id,
          userMessage: text,
          aiResponse: content,
          sourceMsgId: userMsg.id,
        );
        unawaited(_loadMemoryState());

        // 自动更新会话标题
        if (_messages.length <= 2 && _currentSession!.title == '新对话') {
          final newTitle =
              text.length > 10 ? '${text.substring(0, 10)}...' : text;
          final updatedSession = AiChatSession(
            id: _currentSession!.id,
            agentId: widget.agent.id,
            title: newTitle,
            updatedAt: DateTime.now(),
          );
          if (_localPersistenceEnabled) {
            await AiDbService().updateSession(updatedSession);
          }
          setState(() {
            _currentSession = updatedSession;
            final idx = _sessions.indexWhere((s) => s.id == updatedSession.id);
            if (idx != -1) _sessions[idx] = updatedSession;
          });
          unawaited(_persistWebCache());
        }
      }
    } catch (e) {
      if (_wasManuallyStopped) return;
      await _appendError('请求出错: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  String _withNoAiSelfDisclosureRule(String prompt) {
    const rule = '''

补充硬性规则：
1) 不要说“作为AI”“我是AI助手”“我只是模型/程序”等自我限制话术。
2) 用户问“你是谁/你叫什么”时，直接以自然人格化口吻回答，不要暴露模型身份。
''';
    return '$prompt$rule';
  }

  Future<void> _appendError(String text) async {
    final errorMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'assistant',
      content: text,
      createdAt: DateTime.now(),
    );
    if (_localPersistenceEnabled) {
      await AiDbService().insertMessage(errorMsg);
    }
    if (mounted) {
      setState(() => _messages.add(errorMsg));
      unawaited(_persistWebCache());
    }
  }

  Future<void> _editSystemPrompt() async {
    final controller = TextEditingController(text: _systemPrompt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑系统提示词'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '输入系统提示词（为空则使用默认）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final nextPrompt = controller.text.trim();
    setState(() {
      _systemPrompt = nextPrompt;
    });
    unawaited(_persistWebCache());
    await _persistAgentSystemPrompt(nextPrompt);

    if (!_isBackendProviderAgent) {
      await _createNewSession();
      if (!mounted) return;
      MoeToast.success(context, '系统提示词已写入角色卡（已开启新对话）');
      return;
    }

    setState(() => _isSyncingModelPrompt = true);
    try {
      await _syncPromptToOllamaModel(nextPrompt);
      await _createNewSession();
      if (!mounted) return;
      MoeToast.success(context, '系统提示词已更新并同步到 Ollama 模型（已开启新对话）');
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '提示词已保存到角色卡，但同步 Ollama 失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingModelPrompt = false);
      }
    }
  }

  Future<void> _persistAgentSystemPrompt(String prompt) async {
    final updated = AiAgent(
      id: widget.agent.id,
      name: widget.agent.name,
      description: widget.agent.description,
      systemPrompt: prompt,
      modelName: widget.agent.modelName,
      avatarPath: widget.agent.avatarPath,
      providerProfileId: widget.agent.providerProfileId,
      lorebookId: widget.agent.lorebookId,
      persona: widget.agent.persona,
      scenario: widget.agent.scenario,
      openingMessage: widget.agent.openingMessage,
      exampleDialogues: widget.agent.exampleDialogues,
      createdAt: widget.agent.createdAt,
    );
    try {
      await AiAgentCloudService().updateAgent(updated);
    } catch (_) {}
  }

  Future<void> _syncPromptToOllamaModel(String prompt) async {
    final baseModel = await _resolveBaseModelFromModel();
    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/agents');
    final token = ApiService.token;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'name': widget.agent.modelName,
      'base_model': baseModel,
      'system_prompt': prompt,
    });
    final resp = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 45));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final success = data is Map && data['success'] == true;
    if (!success) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : '未知错误';
      throw Exception(msg);
    }
  }

  Future<String> _resolveBaseModelFromModel() async {
    try {
      final uri = LlmEndpointConfig.showUri();
      final token = ApiService.token;
      final headers = ApiService.mergeTunnelHeaders(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'name': widget.agent.modelName}),
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return widget.agent.modelName;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map) return widget.agent.modelName;
      final modelfile = data['modelfile'];
      if (modelfile is! String || modelfile.trim().isEmpty) {
        return widget.agent.modelName;
      }
      final fromMatch = RegExp(r'^\s*FROM\s+([^\s#]+)', multiLine: true)
          .firstMatch(modelfile);
      final fromModel = fromMatch?.group(1)?.trim();
      if (fromModel != null && fromModel.isNotEmpty) {
        return fromModel;
      }
      return widget.agent.modelName;
    } catch (_) {
      return widget.agent.modelName;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(String messageId) {
    // 找到消息在列表中的索引
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      // 计算滚动位置并滚动到该消息
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // 估算每个消息的高度，实际应用中可能需要更精确的计算
          const double estimatedMessageHeight = 100.0;
          final double scrollPosition = index * estimatedMessageHeight;

          _scrollController.animateTo(
            scrollPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _playTts(String text, String msgId) async {
    if (_isSpeaking && _speakingMessageId == msgId) {
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _speakingMessageId = null;
      });
      return;
    }

    try {
      await _tts.stop();
      setState(() {
        _isSpeaking = true;
        _speakingMessageId = msgId;
      });

      await _tts.speak(text);

      // 监听播放完成
      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _speakingMessageId = null;
        });
        MoeToast.error(context, '语音播放失败：${e.toString()}');
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    try {
      if (!_speechAvailable) {
        _initVoice();
        if (!_speechAvailable) {
          if (mounted) {
            MoeToast.error(context, '语音识别不可用');
          }
          return;
        }
      }

      setState(() => _isListening = true);

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _controller.text = result.recognizedWords);
            if (result.finalResult) {
              setState(() => _isListening = false);
              _sendMessage();
            }
          }
        },
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        MoeToast.error(context, '语音识别失败：${e.toString()}');
      }
    }
  }

  void _stopGeneration() {
    if (!_isSending) return;
    _wasManuallyStopped = true;
    final now = DateTime.now();
    final msg = AiChatMessage(
      id: now.millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'assistant',
      content: '已手动停止生成',
      createdAt: now,
    );
    if (_localPersistenceEnabled) {
      AiDbService().insertMessage(msg);
    }
    if (mounted) {
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _openMemoryManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryManagerPage(agent: widget.agent),
      ),
    ).then((_) => _loadMemoryState());
  }

  void _showMessageActions(AiChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F7FD5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.reply_rounded,
                        color: Color(0xFF7F7FD5)),
                  ),
                  title: const Text('回复消息',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _replyToMessage(message);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.copy_rounded, color: Colors.blue),
                  ),
                  title: const Text('复制内容',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(
                        ClipboardData(text: message.content));
                    if (!mounted) return;
                    MoeToast.success(context, '已复制到剪贴板');
                  },
                ),
                if (message.role == 'user') ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.edit_rounded, color: Colors.orange),
                    ),
                    title: const Text('编辑消息',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _editMessage(message);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.format_quote_rounded,
                          color: Colors.green),
                    ),
                    title: const Text('引用消息',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _quoteMessage(message);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _markedMessages.contains(message.id)
                            ? Colors.yellow.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _markedMessages.contains(message.id)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _markedMessages.contains(message.id)
                            ? Colors.yellow
                            : Colors.blue,
                      ),
                    ),
                    title: Text(
                      _markedMessages.contains(message.id) ? '取消标记' : '标记消息',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleMessageMark(message);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.delete_rounded, color: Colors.red),
                    ),
                    title: const Text('撤回消息',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _recallMessage(message);
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replyToMessage(AiChatMessage message) {
    setState(() {
      _controller.text = "@AI " +
          message.content.substring(
              0, message.content.length > 50 ? 50 : message.content.length) +
          "...\n";
      _focusNode.requestFocus();
    });
  }

  Future<void> _editMessage(AiChatMessage message) async {
    if (_localPersistenceEnabled) {
      await AiDbService().deleteMessage(message.id);
    }
    if (!mounted) return;
    setState(() {
      _controller.text = message.content;
      _focusNode.requestFocus();
      _editingMessageId = message.id;
      _messages.removeWhere((msg) => msg.id == message.id);
    });
  }

  void _quoteMessage(AiChatMessage message) {
    setState(() {
      _controller.text =
          "> ${message.content.substring(0, message.content.length > 100 ? 100 : message.content.length)}${message.content.length > 100 ? '...' : ''}\n\n";
      _focusNode.requestFocus();
    });
  }

  void _toggleMessageMark(AiChatMessage message) {
    setState(() {
      if (_markedMessages.contains(message.id)) {
        _markedMessages.remove(message.id);
        MoeToast.info(context, '已取消标记');
      } else {
        _markedMessages.add(message.id);
        MoeToast.success(context, '已标记消息');
      }
    });
  }

  void _recallMessage(AiChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认撤回'),
        content: const Text('确定要撤回这条消息吗？撤回后消息将从聊天记录中删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_localPersistenceEnabled) {
                await AiDbService().deleteMessage(message.id);
              }
              if (!mounted) return;
              setState(() {
                _messages.removeWhere((msg) => msg.id == message.id);
              });
              if (!mounted) return;
              MoeToast.success(context, '消息已撤回');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _searchResults = _messages.where((message) {
        return message.content.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? '输入关键词开始搜索' : '未找到匹配的消息',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final message = _searchResults[index];
        return GestureDetector(
          onTap: () {
            // 点击搜索结果，滚动到对应消息
            _toggleSearch();
            // 滚动到对应消息
            _scrollToMessage(message.id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: message.role == 'user'
                          ? const Color(0xFFE94057)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(
                        message.role == 'user'
                            ? Icons.person_rounded
                            : Icons.smart_toy_rounded,
                        size: 14,
                        color: message.role == 'user'
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message.role == 'user' ? '我' : 'AI',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleQuickReplies() {
    setState(() {
      _showQuickReplies = !_showQuickReplies;
    });
  }

  void _selectQuickReply(String reply) {
    setState(() {
      _controller.text = reply;
      _showQuickReplies = false;
      _focusNode.requestFocus();
    });
  }

  Widget _buildQuickReplies() {
    return Visibility(
      visible: _showQuickReplies,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷回复',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReplies.map((reply) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _selectQuickReply(reply);
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AiBrandTokens.pageBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AiBrandTokens.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          reply,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AiBrandTokens.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentInfo() {
    final agent = widget.agent;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            Theme.of(ctx).primaryColor.withOpacity(0.12),
                        child: Icon(Icons.smart_toy_rounded,
                            color: Theme.of(ctx).primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agent.name,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            if (agent.description.isNotEmpty)
                              Text(agent.description,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                            Text('模型：${agent.modelName}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.subject_rounded,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          const Text('系统提示词',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          const Spacer(),
                          if (_systemPrompt.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text('复制',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: _systemPrompt));
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                MoeToast.success(context, '提示词已复制');
                              },
                            ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text('编辑',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _editSystemPrompt();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: _systemPrompt.isEmpty
                            ? Text('未设置系统提示词',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic))
                            : SelectableText(
                                _systemPrompt,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.black87),
                              ),
                      ),
                      const SizedBox(height: 20),
                      // 记忆预览
                      Row(
                        children: [
                          const Text('🧠', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _memoryPreviewCount > 0
                                  ? '$_memoryHeadline（$_memoryPreviewCount 条）'
                                  : _memoryHeadline,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openMemoryManager();
                            },
                            child: const Text('管理',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      if (_memoryPreviewCount == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _memoryMode == AiMemoryMode.disabled
                                ? '记忆功能已暂停。'
                                : '继续聊天后，AI 会自动记住你的偏好与重要信息。',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                                fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...(_memories.take(3).map((m) {
                          final label = (m.memoryType?.isNotEmpty == true)
                              ? m.memoryType!
                              : '了解';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•', style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$label · ${m.value}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })),
                      if (_memoryPreviewCount > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openMemoryManager();
                            },
                            child: Text('查看全部 $_memoryPreviewCount 条记忆'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool get _showIdentityHero => !_isLoadingHistory && _messages.length <= 1;

  List<String> get _emptySuggestions {
    final opening = widget.agent.openingMessage.trim();
    if (opening.isNotEmpty) {
      return [opening, ..._quickReplies.take(3)];
    }
    return _quickReplies.take(4).toList();
  }

  PreferredSizeWidget _buildChatAppBar({required bool searching}) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AiBrandTokens.titleColor,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: searching
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _toggleSearch,
            )
          : null,
      title: searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索消息...',
                border: InputBorder.none,
              ),
              onChanged: _performSearch,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agent.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AiBrandTokens.titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<bool>(
                        future: LlmEndpointConfig.isTerminalModeEnabled(),
                        builder: (context, snapshot) {
                          final terminal = snapshot.data == true;
                          final sessionTitle =
                              _currentSession?.title ?? '加载中...';
                          final suffix = terminal ? ' · 终端同款' : '';
                          return Text(
                            '$_providerSourceLabel · $sessionTitle$suffix',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    if (_memories.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AiBrandTokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🧠$_memoryPreviewCount',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AiBrandTokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
      actions: searching
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: '搜索消息',
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: '查看智能体信息',
                onPressed: _showAgentInfo,
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.history_rounded),
                  tooltip: '会话历史',
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
    );
  }

  Widget _buildSessionDrawer() {
    return Drawer(
      backgroundColor: AiBrandTokens.pageBackground,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: AiBrandTokens.heroGradient,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.agent.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_providerSourceLabel · ${widget.agent.modelName}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _drawerActionTile(
            icon: Icons.add_comment_rounded,
            label: '新对话',
            color: AiBrandTokens.primary,
            onTap: () {
              Navigator.pop(context);
              _createNewSession();
            },
          ),
          _drawerActionTile(
            icon: Icons.psychology_rounded,
            label: '记忆库（$_memoryPreviewCount 条）',
            color: const Color(0xFF5B8DEF),
            onTap: () {
              Navigator.pop(context);
              _openMemoryManager();
            },
          ),
          _drawerActionTile(
            icon: Icons.person_outline_rounded,
            label: '用户 Persona',
            subtitle: _userPersona.isEmpty ? '未设置' : '已设置',
            color: const Color(0xFF00A86B),
            onTap: () {
              Navigator.pop(context);
              _editUserPersona();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '历史会话',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Text(
                      '暂无历史会话',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isCurrent = session.id == _currentSession?.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AiBrandTokens.primary.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? AiBrandTokens.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? AiBrandTokens.primary
                                  : AiBrandTokens.titleColor,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadSession(session);
                          },
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () => _deleteSession(session.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _drawerActionTile({
    required IconData icon,
    required String label,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingHistory) {
      return const Center(child: MoeLoading());
    }
    if (_messages.isEmpty && !_isSending) {
      return AiChatEmptyState(
        title: '和 ${widget.agent.name} 打个招呼吧',
        subtitle: widget.agent.description.trim().isNotEmpty
            ? widget.agent.description
            : '输入消息开始对话，或点选下方建议快速开场。',
        icon: Icons.nightlife_rounded,
        suggestions: _emptySuggestions,
        onSuggestionTap: (text) {
          setState(() => _controller.text = text);
          _focusNode.requestFocus();
        },
      );
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isSending && index == _messages.length) {
          return _buildTypingBubble();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AiBrandTokens.chatBackground,
      appBar: _buildChatAppBar(searching: _isSearching),
      endDrawer: _isSearching ? null : _buildSessionDrawer(),
      body: _isSearching
          ? _buildSearchResults()
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showIdentityHero
                      ? _buildIdentityHero()
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: AiChatBackground(child: _buildMessageList()),
                ),
                Flexible(
                  flex: 0,
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: _buildInputArea(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message) {
    final isUser = message.role == 'user';
    final timeStr =
        "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    // 检测内容类型
    MessageContentType contentType = MessageContentType.text;
    String? language;

    // 简单的内容类型检测逻辑
    if (message.content.startsWith('```')) {
      // 代码块
      contentType = MessageContentType.code;
      // 提取语言
      final lines = message.content.split('\n');
      if (lines.length > 1) {
        final firstLine = lines[0].trim();
        if (firstLine.length > 3) {
          language = firstLine.substring(3).trim();
        }
      }
    } else if (message.content == 'AI is thinking...') {
      // 思考状态
      contentType = MessageContentType.thinking;
    }

    return FadeInUp(
      key: ValueKey(message.id),
      duration: const Duration(milliseconds: 200),
      delay: const Duration(milliseconds: 50),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showMessageActions(message);
        },
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            AiMessageBubble(
              content: message.content,
              contentType: contentType,
              language: language,
              isUser: isUser,
              agentLabel: isUser ? null : widget.agent.name,
              onContentExpanded: _scrollToBottom,
            ),
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _playTts(message.content, message.id),
                      child: Icon(
                        _isSpeaking && _speakingMessageId == message.id
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: AiTypingIndicator(),
    );
  }

  Widget _buildIdentityHero() {
    final promptReady = _systemPrompt.trim().isNotEmpty;
    final memoryCount = _memoryPreviewCount;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AiBrandTokens.identityGradient,
        border: Border.all(
          color: AiBrandTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AiBrandTokens.userBubbleGradient,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildIdentityChip('模型', widget.agent.modelName),
                _buildIdentityChip('人设', promptReady ? '已启用' : '未设置'),
                if (_userPersona.trim().isNotEmpty)
                  _buildIdentityChip('Persona', '已挂载'),
                _buildIdentityChip('记忆', '$memoryCount 条'),
                if (_isSyncingModelPrompt) _buildIdentityChip('状态', '同步中'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AiBrandTokens.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AiBrandTokens.primary,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      children: [
        _buildQuickReplies(),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              )
            ],
          ),
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic_rounded),
                  color: _isListening ? Colors.red : Colors.grey.shade600,
                  onPressed: _toggleListening,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton(
                  icon: Icon(_showQuickReplies
                      ? Icons.keyboard_rounded
                      : Icons.chat_bubble_outline_rounded),
                  color: Colors.grey.shade600,
                  onPressed: _toggleQuickReplies,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _isListening ? '请说话...' : '输入消息...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _isSending
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle_rounded),
                        color: Colors.redAccent,
                        onPressed: _stopGeneration,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AiBrandTokens.userBubbleGradient,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, size: 20),
                          color: Colors.white,
                          onPressed: _sendMessage,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
