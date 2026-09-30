// Hallmark · layout: bottom-sheet-stack · tone: kawaii-soft · scroll: list-view

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../constants/feature_flags.dart';
import '../../models/ai_provider_profile.dart';
import '../../pages/ai/ai_provider_profiles_page.dart';
import '../../providers/companion_presence_provider.dart';
import '../../services/ai_provider_service.dart';
import '../../services/ai_provider_usage_service.dart';
import '../../services/ai_tts_helper.dart';
import '../../services/companion_service.dart';
import '../../services/companion_interaction_coordinator.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/moe_toast.dart';

String _formatContextTokens(int tokens) {
  if (tokens >= 1000) {
    final value = tokens / 1000;
    final digits = value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(digits)}k';
  }
  return '$tokens';
}

/// 伙伴聊天页 —— 接入后端 SSE 流式聊天，所有 Prompt/LLM 逻辑由后端处理。
class CompanionChatPage extends StatefulWidget {
  const CompanionChatPage({super.key, this.initialDraft});

  /// 从关系首页继续未完成话题时预填的用户草稿，不自动发送。
  final String? initialDraft;

  @override
  State<CompanionChatPage> createState() => _CompanionChatPageState();
}

class _CompanionChatPageState extends State<CompanionChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  final List<_ChatItem> _items = [];
  bool _isSending = false;
  bool _isLoading = true;

  CompanionProfileData _profile = const CompanionProfileData();
  CompanionStateData _state = const CompanionStateData();

  /// 'not_ready' | 'network' | null
  String? _loadError;
  _ChatProviderStatus _providerStatus = _ChatProviderStatus.checking;
  String _providerLabel = '检查模型服务中';
  AiProviderProfile? _activeProvider;
  ProviderTokenUsage? _providerUsage;
  CompanionContextUsage? _contextUsage;

  // AIRI 向轻量语音：STT 本机；TTS 走 Edge 神经音色 + just_audio
  final stt.SpeechToText _speech = stt.SpeechToText();
  late final AiTtsHelper _ttsHelper;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _autoSpeak = false;
  bool _voiceInputPending = false;
  bool _isSpeaking = false;
  bool _ttsBusy = false;
  int? _speakingIndex;

  bool get _voiceEnabled => FeatureFlags.companionVoicePresence;

  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _ttsHelper = AiTtsHelper();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onComposerFocusChanged);
    if (_voiceEnabled) {
      unawaited(_initVoice());
    }
    _loadInitialData();
    unawaited(_loadProviderStatus());
  }

  void _onComposerFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProviderStatus() async {
    try {
      final providerService = AiProviderService();
      final profiles = await providerService.listProfiles();
      final selection =
          await providerService.resolveActiveProvider(profiles: profiles);
      final provider = selection.profile;
      if (!mounted) return;
      if (provider.isBuiltinBackend) {
        setState(() {
          _activeProvider = null;
          _providerUsage = null;
          _providerStatus = _ChatProviderStatus.backendDefault;
          _providerLabel = '使用系统模型';
        });
        return;
      }
      setState(() {
        _activeProvider = null;
        _providerUsage = null;
        _providerStatus = _ChatProviderStatus.backendDefault;
        _providerLabel = '使用 ${provider.name}';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _providerStatus = _ChatProviderStatus.unknown;
          _providerLabel = '模型状态未知';
        });
      }
    }
  }

  Future<void> _initVoice() async {
    try {
      _speechAvailable = await _speech.initialize();
    } catch (_) {
      _speechAvailable = false;
    }
    await _ttsHelper.initialize();
    _ttsHelper.bindHandlers(
      onStart: () {
        if (!mounted) return;
        setState(() => _isSpeaking = true);
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      },
      onCancel: () {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CompanionService().cancelStream();
    if (_voiceEnabled) {
      unawaited(_speech.stop());
    }
    unawaited(_ttsHelper.dispose());
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadChatContext() async {
    try {
      final usage = await CompanionService().getChatContext();
      if (!mounted) return;
      setState(() => _contextUsage = usage);
    } catch (_) {}
  }

  CompanionContextUsage _shownContextUsage() {
    final server = _contextUsage;
    final local = CompanionContextUsage.estimate(
      persona:
          '${_profile.name}\n${_profile.persona}\n${_profile.personalityTraits.join('、')}',
      recentContents: [
        for (final item in _items)
          if (item.content.trim().isNotEmpty) item.content,
      ],
      contextLimit: (server?.contextLimit ?? 0) > 0
          ? server!.contextLimit
          : CompanionContextUsage.defaultContextLimit,
      outputReserve: (server?.outputReserve ?? 0) > 0
          ? server!.outputReserve
          : CompanionContextUsage.defaultOutputReserve,
    );
    if (server == null || server.historyMessages != local.historyMessages) {
      return local;
    }
    return server;
  }

  void _showContextUsage() {
    final usage = _shownContextUsage();
    if (!mounted) return;
    final historyLimit = usage.historyLimit;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('这一轮会带上多少'),
        content: Text(
          '人设、记忆和最近对话会每次重新拼进请求。窗口变小，不会从这边把人设删掉。\n\n'
          '更早的聊天还在记录里，实际只带最近 $historyLimit 条。'
          '现在人设大约 ${_formatContextTokens(usage.personaTokens)}，'
          '最近对话大约 ${_formatContextTokens(usage.historyTokens)}，'
          '合计 ${_formatContextTokens(usage.promptTokens)}，'
          '上下文上限 ${_formatContextTokens(usage.contextLimit)}，'
          '回复再预留 ${_formatContextTokens(usage.outputReserve)}。\n\n'
          '合计加上预留如果超过窗口，模型可能会从开头裁掉，人设就可能没了。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPresenceState() async {
    try {
      final snapshot = await CompanionService().getSnapshot();
      if (!mounted) return;
      setState(() => _state = snapshot.state);
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    try {
      final snapshot = await CompanionService().getSnapshot();
      List<CompanionChatLogData> history = const [];
      try {
        history = await CompanionService().listChatHistory(limit: 40);
      } catch (_) {}
      unawaited(_loadChatContext());
      if (!mounted) return;
      final initialItems = history
          .map(
            (log) => _ChatItem(
              role: log.role,
              content: log.content,
            ),
          )
          .toList(growable: true);
      if (initialItems.isEmpty && snapshot.state.greeting.isNotEmpty) {
        initialItems.add(
          _ChatItem(
            role: 'assistant',
            content: snapshot.state.greeting,
          ),
        );
      }
      setState(() {
        _profile = snapshot.profile;
        _state = snapshot.state;
        _items
          ..clear()
          ..addAll(initialItems);
        _isLoading = false;
        _loadError = null;
      });
      _applyInitialDraft();
      unawaited(CompanionPresenceProvider.instance.markCompanionChatSeen());
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      // 区分错误类型：表不存在 / 网络问题 / 其他
      if (msg.contains("doesn't exist") ||
          msg.contains('no such table') ||
          msg.contains('1146')) {
        setState(() {
          _isLoading = false;
          _loadError = 'not_ready';
        });
      } else if (msg.contains('timeout') ||
          msg.contains('connection') ||
          msg.contains('network') ||
          msg.contains('socket')) {
        setState(() {
          _isLoading = false;
          _loadError = 'network';
        });
      } else {
        // 未知错误，也走友好降级
        setState(() {
          _isLoading = false;
          _loadError = 'not_ready';
        });
      }
    }
  }

  void _applyInitialDraft() {
    final draft = widget.initialDraft?.trim();
    if (draft == null || draft.isEmpty || _controller.text.isNotEmpty) return;
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _sendMessage({
    String? textOverride,
    bool appendUserMessage = true,
  }) async {
    final text = (textOverride ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    final wasVoiceInput = appendUserMessage && _voiceInputPending;
    _voiceInputPending = false;

    _controller.clear();
    final quotaBefore = _providerUsage?.totalAvailable;
    int replyIndex = -1;
    setState(() {
      if (appendUserMessage) {
        _items.add(_ChatItem(role: 'user', content: text));
      }
      _isSending = true;
    });
    _scrollToBottom(force: true);

    var receivedTerminalEvent = false;
    try {
      var fullText = '';
      setState(() {
        _items.add(
          const _ChatItem(role: 'assistant', content: '', isStreaming: true),
        );
        replyIndex = _items.length - 1;
      });

      await for (final event in CompanionService().chatStream(
        text,
        scene: null,
        inputMode: wasVoiceInput ? 'voice' : 'text',
      )) {
        if (!mounted) return;
        switch (event.type) {
          case 'start':
            break;
          case 'delta':
            fullText += event.text;
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: fullText,
                isStreaming: true,
              );
            });
            _scrollToBottom();
            break;
          case 'done':
            receivedTerminalEvent = true;
            final streamedText = fullText.trim();
            final terminalText = event.text.trim();
            final finalText = terminalText.length >= streamedText.length
                ? terminalText
                : streamedText;
            final spoken =
                finalText.isNotEmpty ? finalText : '我在呢～刚才走神了一下，再说一次好吗？';
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: spoken,
                isStreaming: false,
              );
            });
            final warning = event.payload?['warning']?.toString().trim() ?? '';
            if (warning.isNotEmpty) {
              MoeToast.warning(context, warning);
            }
            unawaited(
                CompanionPresenceProvider.instance.markCompanionChatSeen());
            unawaited(_refreshPresenceState());
            unawaited(_loadChatContext());
            CompanionInteractionCoordinator.instance.publishChatCompleted(
              scene: null,
            );
            if (wasVoiceInput) {
              CompanionInteractionCoordinator.instance
                  .publishVoiceTurnCompleted(scene: null);
            }
            if (_voiceEnabled && _autoSpeak) {
              unawaited(_speakAt(_items.length - 1, spoken));
            }
            break;
          case 'error':
            receivedTerminalEvent = true;
            final errorMessage = event.text.trim();
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: errorMessage.isEmpty
                    ? '这次对话没有顺利完成，请检查模型服务后重试。'
                    : errorMessage,
                isError: true,
              );
            });
            break;
        }
      }
      if (!receivedTerminalEvent && mounted) {
        final last = _items.isNotEmpty ? _items.last : null;
        if (last != null && last.role == 'assistant' && last.isStreaming) {
          setState(() {
            _items.last = last.content.trim().isEmpty
                ? const _ChatItem(
                    role: 'assistant',
                    content: '这次回复没有完整返回，请再试一次。',
                    isError: true,
                  )
                : _ChatItem(
                    role: 'assistant',
                    content: last.content,
                    isStreaming: false,
                  );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_items.isNotEmpty &&
            _items.last.role == 'assistant' &&
            _items.last.content.isEmpty) {
          _items.removeLast();
        }
        _items.add(_ChatItem(
          role: 'assistant',
          content: '网络好像断开了，检查一下连接再找我聊天吧~',
          isError: true,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
      if (replyIndex >= 0) {
        unawaited(_refreshReplyUsage(replyIndex, quotaBefore));
      }
    }
  }

  Future<void> _retryFailedMessage(int failedIndex) async {
    if (_isSending ||
        failedIndex < 0 ||
        failedIndex >= _items.length ||
        !_items[failedIndex].isError) {
      return;
    }

    var userIndex = failedIndex - 1;
    while (userIndex >= 0 && _items[userIndex].role != 'user') {
      userIndex--;
    }
    if (userIndex < 0) {
      MoeToast.error(context, '找不到上一条消息，暂时无法重试');
      return;
    }

    final text = _items[userIndex].content.trim();
    if (text.isEmpty) return;
    setState(() => _items.removeAt(failedIndex));
    await _sendMessage(textOverride: text, appendUserMessage: false);
  }

  Future<void> _refreshReplyUsage(int replyIndex, double? quotaBefore) async {
    final provider = _activeProvider;
    if (provider == null) return;
    final apiKey = await AiProviderService().readApiKey(provider.id);
    final usageService = AiProviderUsageService();
    final startedAt =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 120;
    final log = await usageService.fetchLatestTokenLog(
      provider,
      apiKey,
      notBeforeUnix: startedAt,
    );
    final usage = await usageService.fetchTokenUsage(provider, apiKey);
    if (!mounted || replyIndex >= _items.length) return;
    final reply = _items[replyIndex];
    if (reply.role != 'assistant') return;

    // Prefer Key 日志里的真实 quota；无日志时才回退额度差。
    // 不把 quota 点换算成人民币，也不伪造 prompt/completion。
    double? spent = log?.quota;
    if ((spent == null || spent <= 0) && quotaBefore != null && usage != null) {
      spent = (quotaBefore - usage.totalAvailable)
          .clamp(0, double.infinity)
          .toDouble();
    }
    if (spent == null) return;

    final detail = <String>[];
    if (log?.promptTokens != null || log?.completionTokens != null) {
      detail.add(
        'token ${(log?.promptTokens ?? 0)}+${(log?.completionTokens ?? 0)}',
      );
    }
    final remain =
        usage == null ? null : '剩余 ${_quotaLabel(usage.totalAvailable)}';
    final meta = [
      '本次消耗 ${_quotaLabel(spent)}',
      ...detail,
      if (remain != null) remain,
    ].join(' · ');

    setState(() {
      if (usage != null) _providerUsage = usage;
      _items[replyIndex] = _ChatItem(
        role: reply.role,
        content: reply.content,
        isStreaming: reply.isStreaming,
        isError: reply.isError,
        meta: meta,
      );
    });
  }

  String _quotaLabel(double quota) {
    if (quota >= 1000000) return '${(quota / 1000000).toStringAsFixed(2)}M';
    if (quota >= 1000) return '${(quota / 1000).toStringAsFixed(1)}K';
    return quota.toStringAsFixed(0);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels <= 80;
    if (_stickToBottom != atBottom) {
      _stickToBottom = atBottom;
    }
  }

  /// reverse 列表的 offset 0 就是最新一条，历史在上方。
  void _scrollToBottom({bool force = false}) {
    if (force) _stickToBottom = true;
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels <= 1) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _toggleListen() async {
    if (!_voiceEnabled || _isSending) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechAvailable) {
      await _initVoice();
      if (!_speechAvailable) {
        if (mounted) {
          MoeToast.error(
            context,
            '语音输入不可用：请确认已授予麦克风权限，或设备支持系统听写',
          );
        }
        return;
      }
    }
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          if (result.finalResult) {
            _voiceInputPending = true;
            setState(() => _listening = false);
          }
        },
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') ||
          msg.contains('denied') ||
          msg.contains('not authorized')) {
        MoeToast.error(context, '需要麦克风权限才能语音输入，请到系统设置开启');
      } else {
        MoeToast.error(
          context,
          '语音听写失败，可改用键盘输入：${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _ttsHelper.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _ttsBusy = false;
      _speakingIndex = null;
    });
  }

  Future<void> _speakAt(int index, String text) async {
    if (!_voiceEnabled || text.trim().isEmpty) return;
    if ((_isSpeaking || _ttsBusy) && _speakingIndex == index) {
      await _stopSpeaking();
      return;
    }
    try {
      setState(() {
        _ttsBusy = true;
        _isSpeaking = true;
        _speakingIndex = index;
      });
      final started = await _ttsHelper.speak(text);
      if (!mounted) return;
      if (!started) {
        setState(() {
          _isSpeaking = false;
          _ttsBusy = false;
          _speakingIndex = null;
        });
        return;
      }
      setState(() => _ttsBusy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _ttsBusy = false;
          _speakingIndex = null;
        });
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: _buildAppBarTitle(),
        backgroundColor: AiBrandTokens.chatBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 56,
        leading: Center(
          child: _ComposerCircleButton(
            size: 40,
            tooltip: '返回',
            onTap: () => Navigator.of(context).maybePop(),
            background: MoeTokens.cardBackground,
            borderColor: AiBrandTokens.companionBorder,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: MoeTokens.titleText,
            ),
          ),
        ),
        actions: [
          _ComposerCircleButton(
            size: 36,
            tooltip: '记忆',
            onTap: () => Navigator.of(context).pushNamed('/ai-memories'),
            background: MoeTokens.cardBackground,
            borderColor: AiBrandTokens.companionBorder,
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 18,
              color: MoeTokens.titleText,
            ),
          ),
          const SizedBox(width: 6),
          _ComposerCircleButton(
            size: 36,
            tooltip: '聊天工具',
            onTap: _openChatTools,
            background: MoeTokens.cardBackground,
            borderColor: AiBrandTokens.companionBorder,
            child: Badge(
              isLabelVisible: _voiceEnabled && _autoSpeak,
              smallSize: 7,
              backgroundColor: AiBrandTokens.primary,
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: MoeTokens.titleText,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AiChatBackground(
        child: Column(
          children: [
            if (_state.memoryNotice.trim().isNotEmpty) _buildMemoryNotice(),
            Expanded(child: _buildContent()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryNotice() {
    final text = _state.memoryNotice.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          height: 1.3,
          color: Color(0xFF8A4B3A),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isLoading) {
      return const Text('加载中...');
    }
    final name = _profile.name.isNotEmpty ? _profile.name : '我的伙伴';
    final status = _state.activityLabel.isNotEmpty
        ? _state.activityLabel
        : (_voiceEnabled && _autoSpeak ? '自动朗读已开' : _providerLabel);
    final statusColor = switch (_providerStatus) {
      _ChatProviderStatus.failed ||
      _ChatProviderStatus.notConfigured ||
      _ChatProviderStatus.unknown =>
        MoeTokens.danger,
      _ => MoeTokens.caption,
    };
    return Row(
      children: [
        CompanionAvatar(
          emoji: _profile.emoji,
          avatarUrl: _profile.avatarUrl,
          size: 36,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MoeTokens.titleText,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => unawaited(_openProviderSettings()),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MoeTokens.hintText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _buildFallbackCard();
    }

    if (_items.isEmpty) {
      return _buildWelcomeCard();
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final chronoIndex = _items.length - 1 - index;
        final item = _items[chronoIndex];
        final isAssistant = item.role == 'assistant';
        final itemIndex = chronoIndex;
        final canSpeak = _voiceEnabled &&
            isAssistant &&
            !item.isStreaming &&
            !item.isError &&
            item.content.trim().isNotEmpty;
        final speakingThis =
            (_isSpeaking || _ttsBusy) && _speakingIndex == itemIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment:
                isAssistant ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              AiMessageBubble(
                content: item.content,
                contentType: MessageContentType.text,
                isUser: item.role == 'user',
                isLoading: item.isStreaming,
                isError: item.isError,
                onErrorAction: item.isError && !_isSending
                    ? () => unawaited(_retryFailedMessage(itemIndex))
                    : null,
                airyCompanion: true,
                agentLabel: isAssistant ? _profile.name : null,
                assistantAvatar: isAssistant
                    ? CompanionAvatar(
                        emoji: _profile.emoji,
                        avatarUrl: _profile.avatarUrl,
                        size: 32,
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
              ),
              if (canSpeak)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 2),
                  child: _SpeakChip(
                    speaking: speakingThis,
                    busy: _ttsBusy && _speakingIndex == itemIndex,
                    onTap: () => unawaited(
                      _speakAt(itemIndex, item.content),
                    ),
                  ),
                ),
              if (isAssistant && item.isStreaming && item.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 1),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${_profile.name.isEmpty ? 'TA' : _profile.name} 正在继续回应',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              if (isAssistant && item.meta != null)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 2),
                  child: Text(
                    item.meta!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 友好错误降级卡片 ─────────────────────────────────────────────
  Widget _buildFallbackCard() {
    final isNotReady = _loadError == 'not_ready';
    final emoji = isNotReady ? '🐾' : '📡';
    final title = isNotReady ? '伙伴正在准备中' : '网络好像断开了';
    final subtitle =
        isNotReady ? '后台正在部署伙伴的记忆系统\n马上就能聊天啦~' : '检查一下网络连接\n然后再来找我吧';
    final buttonText = isNotReady ? '稍后再试' : '重新连接';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEDE7F6),
                Color(0xFFF3E5F5),
                Color(0xFFFCE4EC),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0x128A2387),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AiBrandTokens.titleColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadInitialData();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(buttonText),
                style: FilledButton.styleFrom(
                  backgroundColor: AiBrandTokens.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 首次进入欢迎卡片 ─────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEDE7F6),
                Color(0xFFF3E5F5),
                Color(0xFFFCE4EC),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0x128A2387),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _profile.emoji.isNotEmpty ? _profile.emoji : '🐾',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _profile.name.isNotEmpty ? _profile.name : '我的伙伴',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AiBrandTokens.titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _profile.persona.isNotEmpty
                    ? _profile.persona
                    : '你的 AI 好朋友，随时陪你聊天\n说点什么开始吧~',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AiBrandTokens.titleColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextMeter() {
    final usage = _shownContextUsage();
    final color = usage.overflow ? MoeTokens.danger : MoeTokens.primary;
    final label = usage.overflow ? '上下文快满了' : '上下文';
    return GestureDetector(
      onTap: _showContextUsage,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(Icons.donut_small_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label ${_formatContextTokens(usage.promptTokens)}/${_formatContextTokens(usage.contextLimit)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: usage.usedFraction,
                backgroundColor: color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '最近 ${usage.historyMessages}/${usage.historyLimit}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MoeTokens.hintText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final hasError = _loadError != null;
    const btnSize = 40.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: MoeTokens.primary.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContextMeter(),
              const SizedBox(height: 8),
              if (_listening || _isSending) ...[
                _ComposerStatus(
                  label: _listening ? '正在听你说…' : 'TA 正在组织回应…',
                  listening: _listening,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_voiceEnabled) ...[
                    _ComposerCircleButton(
                      size: btnSize,
                      tooltip: _listening ? '停止听写' : '语音输入',
                      onTap: (_isSending || hasError)
                          ? null
                          : () => unawaited(_toggleListen()),
                      background: _listening
                          ? MoeTokens.primary.withValues(alpha: 0.12)
                          : MoeTokens.softChipBg,
                      borderColor: _listening
                          ? MoeTokens.primary.withValues(alpha: 0.35)
                          : AiBrandTokens.companionBorder,
                      child: Icon(
                        _listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_none_rounded,
                        size: 20,
                        color:
                            _listening ? MoeTokens.primary : MoeTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: MoeTokens.softLavenderBg,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? MoeTokens.primary.withValues(alpha: 0.28)
                              : AiBrandTokens.companionBorder,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: hasError
                              ? '暂时无法发送消息'
                              : _listening
                                  ? '正在听…'
                                  : _isSending
                                      ? 'TA 正在回应…'
                                      : '说点什么吧…',
                          hintStyle: const TextStyle(color: MoeTokens.hintText),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: MoeTokens.textMd,
                          color: MoeTokens.titleText,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isSending && !hasError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ComposerCircleButton(
                    size: btnSize,
                    tooltip: '发送',
                    onTap: (_isSending || hasError) ? null : _sendMessage,
                    background: (_isSending || hasError)
                        ? MoeTokens.softChipBg
                        : MoeTokens.primary,
                    borderColor: (_isSending || hasError)
                        ? AiBrandTokens.companionBorder
                        : Colors.transparent,
                    child: Icon(
                      _isSending
                          ? Icons.more_horiz_rounded
                          : Icons.arrow_upward_rounded,
                      size: 20,
                      color: (_isSending || hasError)
                          ? MoeTokens.hintText
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AiProviderProfilesPage()),
    );
    if (mounted) unawaited(_loadProviderStatus());
  }

  Future<void> _openChatTools() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AiBrandTokens.pageBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('聊天工具',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _ChatToolTile(
                    icon: Icons.tune_rounded,
                    title: '模型设置',
                    subtitle: _providerLabel,
                    onTap: () => Navigator.pop(sheetContext, 'provider')),
                if (_voiceEnabled)
                  _ChatToolTile(
                    icon: _autoSpeak
                        ? Icons.record_voice_over_rounded
                        : Icons.volume_up_outlined,
                    title: _autoSpeak ? '自动朗读 · 开' : '自动朗读 · 关',
                    subtitle:
                        _autoSpeak ? 'TA 说完会自动朗读，点此关闭' : '开启后，TA 说完会朗读给你听',
                    onTap: () => Navigator.pop(sheetContext, 'auto_speak'),
                  ),
                if (_voiceEnabled)
                  _ChatToolTile(
                    icon: Icons.record_voice_over_outlined,
                    title: '朗读音色',
                    subtitle: AiTtsHelper.chineseVoices
                        .firstWhere(
                          (v) => v.id == _ttsHelper.voice,
                          orElse: () => AiTtsHelper.chineseVoices.first,
                        )
                        .label,
                    onTap: () => Navigator.pop(sheetContext, 'tts_voice'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'provider':
        await _openProviderSettings();
      case 'auto_speak':
        setState(() => _autoSpeak = !_autoSpeak);
        if (!mounted) return;
        MoeToast.success(
          context,
          _autoSpeak ? '已开启：TA 说完会朗读' : '已关闭自动朗读',
        );
      case 'tts_voice':
        await _pickTtsVoice();
    }
  }

  Future<void> _pickTtsVoice() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AiBrandTokens.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择朗读音色',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Edge 神经语音 · 可换声线',
                style: TextStyle(fontSize: 12, color: MoeTokens.inkMuted),
              ),
              const SizedBox(height: 10),
              for (final voice in AiTtsHelper.chineseVoices)
                ListTile(
                  title: Text(voice.label),
                  trailing: voice.id == _ttsHelper.voice
                      ? const Icon(Icons.check_rounded,
                          color: AiBrandTokens.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, voice.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _ttsHelper.setVoice(selected);
    if (!mounted) return;
    setState(() {});
    MoeToast.success(context, '已切换音色');
  }
}

enum _ChatProviderStatus {
  checking,
  notConfigured,
  notSelected,
  backendDefault,
  connected,
  failed,
  untested,
  unknown;

  String get label => switch (this) {
        connected => '已连通',
        failed => '连接失败',
        untested => '待验证',
        backendDefault => '系统模型',
        notConfigured => '未配置',
        notSelected => '待选择',
        checking => '检查中',
        unknown => '状态未知',
      };

  bool get needsConfiguration =>
      this == notConfigured || this == notSelected || this == failed;
}

class _ChatToolTile extends StatelessWidget {
  const _ChatToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: AiBrandTokens.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ComposerCircleButton extends StatelessWidget {
  const _ComposerCircleButton({
    required this.size,
    required this.child,
    required this.background,
    required this.borderColor,
    this.onTap,
    this.tooltip,
  });

  final double size;
  final Widget child;
  final Color background;
  final Color borderColor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SpeakChip extends StatelessWidget {
  const _SpeakChip({
    required this.speaking,
    required this.onTap,
    this.busy = false,
  });

  final bool speaking;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = speaking || busy;
    final label = busy ? '合成中 · 停止' : (speaking ? '停止' : '朗读');
    return AnimatedContainer(
      duration: MoeTokens.motionFast,
      curve: Curves.easeInOut,
      child: Material(
        color: active
            ? MoeTokens.primary.withValues(alpha: 0.12)
            : MoeTokens.softChipBg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.stop_rounded : Icons.volume_up_outlined,
                  size: 14,
                  color: active ? MoeTokens.primary : MoeTokens.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? MoeTokens.primary : MoeTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerStatus extends StatelessWidget {
  const _ComposerStatus({required this.label, required this.listening});

  final String label;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            listening ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded,
            size: 14,
            color: AiBrandTokens.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AiBrandTokens.companionInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem {
  final String role;
  final String content;
  final bool isStreaming;
  final bool isError;
  final String? meta;

  const _ChatItem({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError = false,
    this.meta,
  });
}
