import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_prompt_defaults.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/llm_api_service.dart';
import '../../services/ai_db_service.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_chat_context_builder.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../services/ai_user_persona_service.dart';
import '../../services/ai_chat_session_prefs.dart';
import '../../services/ai_tts_helper.dart';
import '../../utils/ai_chat_message_utils.dart';
import '../../utils/ai_chat_quick_replies.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_session.dart';
import '../../models/ai_chat_message.dart';
import '../../models/ai_provider_profile.dart';
import '../../widgets/motion/moe_reveal_once.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/ai/ai_chat_empty_state.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/ai/ai_typing_indicator.dart';
import '../../widgets/ai/ai_chat_composer.dart';
import '../../widgets/ai/ai_chat_settings_sheet.dart';
import '../../widgets/ai/ai_chat_identity_hero.dart';
import '../../widgets/ai/ai_chat_session_drawer.dart';
import '../../widgets/ai/ai_chat_status_banners.dart';
import '../../widgets/moe_action_row.dart';
import '../../widgets/moe_input_field.dart';
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
  final Set<String> _revealedMessageIds = {};
  double _temperature = 0.85;
  final bool _terminalModeEnabled = false;
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
  late final AiTtsHelper _ttsHelper;
  bool _isSpeaking = false;
  String? _speakingMessageId;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<AiChatMessage> _searchResults = [];

  // Quick Replies
  bool _showQuickReplies = false;
  late List<String> _quickReplies;

  /// 用户上滑阅读时为 false，避免新消息强行滚底。
  bool _stickToBottom = true;
  static const double _scrollStickThreshold = 96;

  // Message Marking
  final Set<String> _markedMessages = {};

  // Edit Message
  String? _editingMessageId;

  String? _streamingMessageId;
  Timer? _typewriterTimer;

  bool get _isBackendProviderAgent =>
      widget.agent.providerProfileId == null ||
      widget.agent.providerProfileId == AiProviderProfile.builtinBackendId;

  String get _providerSourceLabel =>
      _isBackendProviderAgent ? '服务器模型' : '我的 API';

  @override
  void initState() {
    super.initState();
    _ttsHelper = AiTtsHelper(_tts);
    _quickReplies = buildAgentQuickReplies(widget.agent);
    _scrollController.addListener(_onScroll);
    _systemPrompt = widget.agent.systemPrompt.trim().isNotEmpty
        ? widget.agent.systemPrompt
        : AiPromptDefaults.defaultAgentSystemPrompt;
    _initVoice();
    _loadChatPrefs();
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
    _scrollController.removeListener(_onScroll);
    _cancelTypewriter();
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
            final sessionMessages =
                messages.where((m) => m.sessionId == current!.id).toList();
            setState(() {
              _sessions = sessions;
              _currentSession = current;
              _messages = sessionMessages;
              if (savedPrompt != null) {
                _systemPrompt = savedPrompt;
              }
              _isLoadingHistory = false;
            });
            _markLoadedMessagesSeen(sessionMessages);
            _scrollToBottom(force: true);
            if (_messages.isEmpty) {
              unawaited(_seedOpeningMessageIfNeeded(current));
            }
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
    } catch (_) {}
    try {
      await _ttsHelper.initialize();
      _ttsHelper.bindHandlers(
        onComplete: () {
          if (!mounted) return;
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _isSpeaking = false;
            _speakingMessageId = null;
          });
          MoeToast.error(context, '语音播放失败，请检查系统 TTS 是否可用');
        },
      );
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

  Future<void> _loadChatPrefs() async {
    final temp = await AiChatSessionPrefs.temperature(widget.agent.id);
    if (!mounted) return;
    setState(() => _temperature = temp);
  }

  Future<void> _openChatSettings() async {
    if (!mounted) return;
    await AiChatSettingsSheet.show(
      context: context,
      agent: widget.agent,
      temperature: _temperature,
      onTemperatureChanged: (v) {
        if (!mounted) return;
        setState(() => _temperature = v);
      },
    );
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
            MoeInputField(
              controller: controller,
              hintText:
                  '例如：我是一个偏理性但容易焦虑的产品经理，希望对方叫我阿栀，回答尽量直接一点。',
              minLines: 5,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
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

  void _markLoadedMessagesSeen(Iterable<AiChatMessage> messages) {
    _revealedMessageIds
      ..clear()
      ..addAll(messages.map((m) => m.id));
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
    _scrollToBottom(force: true);
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
        _stickToBottom = true;
      });
      _markLoadedMessagesSeen(messages);
      _scrollToBottom(force: true);
      unawaited(_persistWebCache());
      if (messages.isEmpty) {
        unawaited(_seedOpeningMessageIfNeeded(session));
      }
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
      _stickToBottom = true;
    });
    _scrollToBottom(force: true);
    if (_localPersistenceEnabled) {
      await AiDbService().insertMessage(userMsg);
    }

    await _fetchAssistantReply(userMsg, titleSeed: text);
  }

  void _cancelTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
  }

  void _updateMessageContent(String messageId, String content) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final old = _messages[index];
    _messages[index] = AiChatMessage(
      id: old.id,
      sessionId: old.sessionId,
      role: old.role,
      content: content,
      createdAt: old.createdAt,
    );
  }

  Future<void> _revealTypewriter(String messageId, String fullText) async {
    _cancelTypewriter();
    if (fullText.isEmpty) {
      _updateMessageContent(messageId, fullText);
      if (mounted) setState(() {});
      return;
    }
    final animate = fullText.length <= 1400;
    if (!animate) {
      _updateMessageContent(messageId, fullText);
      if (mounted) setState(() {});
      return;
    }

    var index = 0;
    final completer = Completer<void>();
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 14), (timer) {
      if (!mounted || _wasManuallyStopped) {
        timer.cancel();
        completer.complete();
        return;
      }
      index += 2;
      if (index >= fullText.length) {
        index = fullText.length;
        timer.cancel();
      }
      _updateMessageContent(messageId, fullText.substring(0, index));
      if (mounted) setState(() {});
      _scrollToBottom();
      if (index >= fullText.length) {
        completer.complete();
      }
    });
    return completer.future;
  }

  void _insertStreamingPlaceholder() {
    final id = 'stream_${DateTime.now().millisecondsSinceEpoch}';
    _streamingMessageId = id;
    _messages.add(
      AiChatMessage(
        id: id,
        sessionId: _currentSession!.id,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 发给模型 API 的对话历史：排除失败气泡、流式占位与 system 行。
  List<Map<String, String>> _buildChatApiHistory() {
    return _messages
        .where((m) => m.role != 'system')
        .where((m) => m.id != _streamingMessageId)
        .where((m) => !(m.role == 'assistant' && m.content.trim().isEmpty))
        .where(
          (m) => !(m.role == 'assistant' &&
              AiChatMessageUtils.looksLikeErrorContent(m.content)),
        )
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
  }

  Future<void> _fetchAssistantReply(
    AiChatMessage userMsg, {
    String? titleSeed,
  }) async {
    final text = userMsg.content;
    _cancelTypewriter();
    if (mounted) {
      setState(() {
        _insertStreamingPlaceholder();
      });
      _scrollToBottom(force: true);
    }
    final streamId = _streamingMessageId;
    try {
      final history = _buildChatApiHistory();

      final chatContext = await AiChatContextBuilder().build(
        agent: widget.agent,
        history: history,
        latestUserMessage: text,
        recentConversation: _messages
            .where((m) => m.role != 'system')
            .map((m) => m.content)
            .toList(),
        overrideSystemPrompt: _systemPrompt,
        userPersona: _userPersona,
      );

      if (_wasManuallyStopped) return;
      final content = await AiChatGatewayService().sendChat(
        agent: widget.agent,
        messages: chatContext.messages,
        sessionId: _currentSession?.id,
        sourceMsgId: userMsg.id,
        temperature: _temperature,
      );
      if (_wasManuallyStopped) return;

      if (streamId != null && _messages.any((m) => m.id == streamId)) {
        await _revealTypewriter(streamId, content);
        if (_wasManuallyStopped) return;
        final assistantMsg = _messages.firstWhere((m) => m.id == streamId);
        if (_localPersistenceEnabled) {
          await AiDbService().insertMessage(assistantMsg);
        }
      } else {
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
        if (!mounted) return;
        setState(() => _messages.add(assistantMsg));
      }
      _streamingMessageId = null;
      if (mounted) setState(() {});
      unawaited(_persistWebCache());

      final seed = titleSeed ?? text;
      if (_messages.length <= 2 && _currentSession!.title == '新对话') {
        final newTitle =
            seed.length > 10 ? '${seed.substring(0, 10)}...' : seed;
        final updatedSession = AiChatSession(
          id: _currentSession!.id,
          agentId: widget.agent.id,
          title: newTitle,
          updatedAt: DateTime.now(),
        );
        if (_localPersistenceEnabled) {
          await AiDbService().updateSession(updatedSession);
        }
        if (!mounted) return;
        setState(() {
          _currentSession = updatedSession;
          final idx = _sessions.indexWhere((s) => s.id == updatedSession.id);
          if (idx != -1) _sessions[idx] = updatedSession;
        });
        unawaited(_persistWebCache());
      }
    } catch (e) {
      if (_wasManuallyStopped) return;
      if (streamId != null) {
        _messages.removeWhere((m) => m.id == streamId);
        _streamingMessageId = null;
      }
      if (mounted) setState(() {});
      await _appendError(AiChatGatewayService.userFacingError(e));
    } finally {
      _cancelTypewriter();
      _streamingMessageId = null;
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _continueAssistantMessage(AiChatMessage message) async {
    if (_isSending || message.role != 'assistant') return;
    if (!_isLastAssistantMessage(message)) {
      MoeToast.error(context, '只能继续最后一条 AI 回复');
      return;
    }
    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'user',
      content: '请继续写下去',
      createdAt: DateTime.now(),
    );
    if (_localPersistenceEnabled) {
      await AiDbService().insertMessage(userMsg);
    }
    if (!mounted) return;
    setState(() {
      _messages.add(userMsg);
      _isSending = true;
      _wasManuallyStopped = false;
      _stickToBottom = true;
    });
    _scrollToBottom(force: true);
    await _fetchAssistantReply(userMsg);
  }

  Future<void> _regenerateAssistantMessage(AiChatMessage message) async {
    if (_isSending || message.role != 'assistant') return;
    if (!_isLastAssistantMessage(message)) {
      MoeToast.error(context, '只能重新生成最后一条 AI 回复');
      return;
    }
    final userMsg = _userMessageBefore(message.id);
    if (userMsg == null) {
      MoeToast.error(context, '找不到对应的用户消息');
      return;
    }

    if (_localPersistenceEnabled) {
      await AiDbService().deleteMessage(message.id);
    }
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
      _isSending = true;
      _wasManuallyStopped = false;
      _stickToBottom = true;
    });
    _scrollToBottom(force: true);
    await _fetchAssistantReply(userMsg);
  }

  Future<void> _retryAfterError(AiChatMessage errorMessage) async {
    if (_isSending ||
        !AiChatMessageUtils.looksLikeErrorContent(errorMessage.content)) {
      return;
    }
    final userMsg = _userMessageBefore(errorMessage.id);
    if (userMsg == null) {
      MoeToast.error(context, '找不到上一条用户消息，无法重试');
      return;
    }

    if (_localPersistenceEnabled) {
      await AiDbService().deleteMessage(errorMessage.id);
    }
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == errorMessage.id);
      _isSending = true;
      _wasManuallyStopped = false;
      _stickToBottom = true;
    });
    _scrollToBottom(force: true);
    await _fetchAssistantReply(userMsg);
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
        content: MoeInputField(
          controller: controller,
          hintText: '输入系统提示词（为空则使用默认）',
          maxLines: 8,
          textInputAction: TextInputAction.newline,
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
      await _syncPromptToServerModel(nextPrompt);
      await _createNewSession();
      if (!mounted) return;
      MoeToast.success(context, '系统提示词已更新并同步到服务器模型（已开启新对话）');
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '提示词已保存到角色卡，但同步服务器模型失败：$e');
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

  Future<void> _syncPromptToServerModel(String prompt) async {
    final baseModel = await _resolveBaseModelFromModel();
    await LlmApiService.upsertAgentPrompt(
      name: widget.agent.modelName,
      baseModel: baseModel,
      systemPrompt: prompt,
    );
  }

  Future<String> _resolveBaseModelFromModel() =>
      LlmApiService.resolveBaseModelFromShow(widget.agent.modelName);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.maxScrollExtent - pos.pixels <= _scrollStickThreshold;
    if (_stickToBottom != atBottom) {
      setState(() => _stickToBottom = atBottom);
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  AiChatMessage? get _lastAssistantMessage {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant') return _messages[i];
    }
    return null;
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _shouldShowDateHeader(int index) {
    if (index <= 0 || index >= _messages.length) return index == 0;
    return !_isSameCalendarDay(
      _messages[index].createdAt,
      _messages[index - 1].createdAt,
    );
  }

  String _dateLabelFor(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    if (dt.year == now.year) return '${dt.month}月${dt.day}日';
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AiTheme.caption.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  bool _isLastAssistantMessage(AiChatMessage message) {
    final last = _lastAssistantMessage;
    return last != null && last.id == message.id;
  }

  AiChatMessage? _userMessageBefore(String assistantId) {
    final idx = _messages.indexWhere((m) => m.id == assistantId);
    if (idx <= 0) return null;
    for (var i = idx - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') return _messages[i];
    }
    return null;
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
      await _ttsHelper.stop();
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _speakingMessageId = null;
      });
      return;
    }

    try {
      if (!mounted) return;
      setState(() {
        _isSpeaking = true;
        _speakingMessageId = msgId;
      });
      await _ttsHelper.speak(text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _speakingMessageId = null;
      });
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      MoeToast.error(context, msg.isEmpty ? '语音播放失败' : msg);
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
    _cancelTypewriter();
    final streamId = _streamingMessageId;
    if (mounted) {
      setState(() {
        if (streamId != null) {
          final idx = _messages.indexWhere((m) => m.id == streamId);
          if (idx >= 0) {
            final partial = _messages[idx].content.trim();
            if (partial.isEmpty) {
              _messages.removeAt(idx);
            }
          }
          _streamingMessageId = null;
        } else {
          final now = DateTime.now();
          _messages.add(
            AiChatMessage(
              id: now.millisecondsSinceEpoch.toString(),
              sessionId: _currentSession!.id,
              role: 'assistant',
              content: '已手动停止生成',
              createdAt: now,
            ),
          );
        }
        _isSending = false;
      });
      _scrollToBottom(force: true);
    }
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
                MoeActionRow(
                  icon: Icons.reply_rounded,
                  title: '回复消息',
                  iconColor: AiBrandTokens.primary,
                  showDefaultTrailing: false,
                  onTap: () {
                    Navigator.pop(context);
                    _replyToMessage(message);
                  },
                ),
                MoeActionRow(
                  icon: Icons.copy_rounded,
                  title: '复制内容',
                  iconColor: Colors.blue,
                  showDefaultTrailing: false,
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(
                        ClipboardData(text: message.content));
                    if (!mounted) return;
                    MoeToast.success(this.context, '已复制到剪贴板');
                  },
                ),
                if (message.role == 'assistant' &&
                    _isLastAssistantMessage(message) &&
                    !AiChatMessageUtils.looksLikeErrorContent(
                        message.content)) ...[
                  MoeActionRow(
                    icon: Icons.refresh_rounded,
                    title: '重新生成',
                    iconColor: AiBrandTokens.primary,
                    showDefaultTrailing: false,
                    onTap: () {
                      Navigator.pop(context);
                      _regenerateAssistantMessage(message);
                    },
                  ),
                  MoeActionRow(
                    icon: Icons.more_horiz_rounded,
                    title: '继续生成',
                    iconColor: AiBrandTokens.secondary,
                    showDefaultTrailing: false,
                    onTap: () {
                      Navigator.pop(context);
                      _continueAssistantMessage(message);
                    },
                  ),
                ],
                if (message.role == 'user') ...[
                  MoeActionRow(
                    icon: Icons.edit_rounded,
                    title: '编辑消息',
                    iconColor: Colors.orange,
                    showDefaultTrailing: false,
                    onTap: () {
                      Navigator.pop(context);
                      _editMessage(message);
                    },
                  ),
                  MoeActionRow(
                    icon: Icons.format_quote_rounded,
                    title: '引用消息',
                    iconColor: Colors.green,
                    showDefaultTrailing: false,
                    onTap: () {
                      Navigator.pop(context);
                      _quoteMessage(message);
                    },
                  ),
                  MoeActionRow(
                    icon: _markedMessages.contains(message.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    title:
                        _markedMessages.contains(message.id) ? '取消标记' : '标记消息',
                    iconColor: _markedMessages.contains(message.id)
                        ? Colors.yellow
                        : Colors.blue,
                    showDefaultTrailing: false,
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleMessageMark(message);
                    },
                  ),
                  MoeActionRow(
                    icon: Icons.delete_rounded,
                    title: '撤回消息',
                    iconColor: Colors.red,
                    showDefaultTrailing: false,
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold),
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
    final preview = message.content.substring(
        0, message.content.length > 50 ? 50 : message.content.length);
    setState(() {
      _controller.text = '@AI $preview...\n';
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
              MoeToast.success(this.context, '消息已撤回');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MoeTokens.primary,
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
                  color: Colors.black.withValues(alpha: 0.05),
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
                          ? AiBrandTokens.gradientCoral
                          : Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
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
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: BoxDecoration(
          color: AiBrandTokens.pageBackground.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: AiBrandTokens.primary.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快捷回复',
              style: AiTheme.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AiBrandTokens.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReplies.map((reply) {
                return ActionChip(
                  label: Text(
                    reply,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AiBrandTokens.primary.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _selectQuickReply(reply);
                  },
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
                            Theme.of(ctx).primaryColor.withValues(alpha: 0.12),
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
                                if (!ctx.mounted) return;
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
                          color: MoeTokens.pageBackground,
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
                  ],
                ),
              ],
            ),
      actions: searching
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: '对话设置',
                onPressed: _openChatSettings,
              ),
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
      itemCount: _messages.length +
          (_isSending && _streamingMessageId == null ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isSending && index == _messages.length) {
          return _buildTypingBubble();
        }
        final message = _messages[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_shouldShowDateHeader(index))
              _buildDateSeparator(_dateLabelFor(message.createdAt)),
            _buildMessageBubble(message, index: index),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AiBrandTokens.chatBackground,
      appBar: _buildChatAppBar(searching: _isSearching),
      endDrawer: _isSearching
          ? null
          : AiChatSessionDrawer(
              agentName: widget.agent.name,
              modelName: widget.agent.modelName,
              providerSourceLabel: _providerSourceLabel,
              userPersona: _userPersona,
              sessions: _sessions,
              currentSessionId: _currentSession?.id,
              onCreateSession: _createNewSession,
              onEditUserPersona: _editUserPersona,
              onLoadSession: _loadSession,
              onDeleteSession: _deleteSession,
            ),
      body: _isSearching
          ? _buildSearchResults()
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showIdentityHero
                      ? AiChatIdentityHero(
                          modelName: widget.agent.modelName,
                          promptReady: _systemPrompt.trim().isNotEmpty,
                          personaMounted: _userPersona.trim().isNotEmpty,
                          isSyncingModelPrompt: _isSyncingModelPrompt,
                        )
                      : const SizedBox.shrink(),
                ),
                if (_terminalModeEnabled) const AiTerminalModeBanner(),
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

  Widget _buildMessageBubble(AiChatMessage message, {required int index}) {
    final isUser = message.role == 'user';
    final isError =
        !isUser && AiChatMessageUtils.looksLikeErrorContent(message.content);
    final timeStr =
        "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    final sameRoleAbove =
        index > 0 && _messages[index - 1].role == message.role;
    final hideAvatar = sameRoleAbove;
    final compactTop = sameRoleAbove;

    MessageContentType contentType = MessageContentType.text;
    if (message.content == 'AI is thinking...' ||
        (message.id == _streamingMessageId && message.content.isEmpty)) {
      contentType = MessageContentType.thinking;
    }
    final useRichFormat = !isUser &&
        !isError &&
        contentType == MessageContentType.text &&
        message.content.trim().isNotEmpty;

    return MoeRevealOnce(
      key: ValueKey(message.id),
      revealKey: message.id,
      revealedKeys: _revealedMessageIds,
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
            if (isError)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AiTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AiTheme.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AiTheme.danger.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '发送失败',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AiTheme.danger.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message.content,
                        style: AiTheme.body.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: _isSending
                              ? null
                              : () => _retryAfterError(message),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重试'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                AiBrandTokens.primary.withValues(alpha: 0.12),
                            foregroundColor: AiBrandTokens.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              AiMessageBubble(
                content: message.content,
                contentType: contentType,
                isUser: isUser,
                richFormat: useRichFormat,
                hideAvatar: hideAvatar,
                compactTop: compactTop,
                agentLabel: isUser ? null : widget.agent.name,
                onContentExpanded: () => _scrollToBottom(force: true),
              ),
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            if (!isUser && !isError)
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
                    if (_isLastAssistantMessage(message)) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _isSending
                            ? null
                            : () => _regenerateAssistantMessage(message),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: _isSending
                                ? Colors.grey.shade400
                                : AiBrandTokens.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _playTts(message.content, message.id),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _isSpeaking && _speakingMessageId == message.id
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_rounded,
                            size: 18,
                            color:
                                _isSpeaking && _speakingMessageId == message.id
                                    ? AiBrandTokens.primary
                                    : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && isError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 48),
                child: Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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

  Widget _buildInputArea() {
    return AiChatComposer(
      controller: _controller,
      focusNode: _focusNode,
      agentName: widget.agent.name,
      isListening: _isListening,
      isSending: _isSending,
      showQuickReplies: _showQuickReplies,
      canSend: !_isSending,
      onToggleListening: _toggleListening,
      onToggleQuickReplies: _toggleQuickReplies,
      onSend: _sendMessage,
      onStop: _stopGeneration,
      stopControlInBanner: false,
      quickRepliesPanel: _buildQuickReplies(),
    );
  }
}
