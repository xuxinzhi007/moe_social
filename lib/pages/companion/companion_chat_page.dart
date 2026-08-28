import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../constants/feature_flags.dart';
import '../../models/ai_provider_profile.dart';
import '../../pages/ai/ai_provider_profiles_page.dart';
import '../../providers/companion_presence_provider.dart';
import '../../services/ai_provider_connectivity_cache.dart';
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

  @override
  void initState() {
    super.initState();
    _ttsHelper = AiTtsHelper();
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
      final selectedId = await providerService.readLastSelectedProfileId();
      final profiles = await providerService.listProfiles();
      final customProfiles = profiles.where((item) => !item.isBuiltin).toList();
      if (selectedId == null || selectedId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _providerStatus = customProfiles.isEmpty
              ? _ChatProviderStatus.notConfigured
              : _ChatProviderStatus.notSelected;
          _providerLabel = customProfiles.isEmpty ? '未配置模型' : '请选择模型';
        });
        return;
      }
      final provider = await providerService.resolveProfile(selectedId);
      if (provider.isBuiltinBackend) {
        if (!mounted) return;
        setState(() {
          _providerStatus = _ChatProviderStatus.backendDefault;
          _providerLabel = '使用系统模型';
        });
        return;
      }
      final connectivity = await AiProviderConnectivityCache.read(provider.id);
      final apiKey = await providerService.readApiKey(provider.id);
      final usage = await AiProviderUsageService().fetchTokenUsage(
        provider,
        apiKey,
      );
      if (!mounted) return;
      setState(() {
        _activeProvider = provider;
        _providerUsage = usage;
        _providerStatus = connectivity?.isSuccess == true
            ? _ChatProviderStatus.connected
            : connectivity?.isSuccess == false
                ? _ChatProviderStatus.failed
                : _ChatProviderStatus.untested;
        _providerLabel = '${provider.name} · ${_providerStatus.label}';
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
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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
      _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final wasVoiceInput = _voiceInputPending;
    _voiceInputPending = false;

    _controller.clear();
    final quotaBefore = _providerUsage?.totalAvailable;
    int replyIndex = -1;
    setState(() {
      _items.add(_ChatItem(role: 'user', content: text));
      _isSending = true;
    });
    _scrollToBottom();

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
            final finalText = event.text.trim().isNotEmpty
                ? event.text.trim()
                : fullText.trim();
            final spoken =
                finalText.isNotEmpty ? finalText : '我在呢～刚才走神了一下，再说一次好吗？';
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: spoken,
                isStreaming: false,
              );
            });
            unawaited(
                CompanionPresenceProvider.instance.markCompanionChatSeen());
            unawaited(_refreshPresenceState());
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
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
          _ProviderStatusButton(
            status: _providerStatus,
            label: _providerLabel,
            onTap: () => unawaited(_openProviderSettings()),
          ),
          IconButton(
            tooltip: '聊天工具',
            onPressed: _openChatTools,
            icon: Badge(
              isLabelVisible: _voiceEnabled && _autoSpeak,
              smallSize: 8,
              backgroundColor: AiBrandTokens.primary,
              child: const Icon(Icons.more_horiz_rounded),
            ),
          ),
        ],
      ),
      body: AiChatBackground(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isLoading) {
      return const Text('加载中...');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: AiBrandTokens.heroGradient,
            borderRadius: BorderRadius.circular(15),
          ),
          child: CompanionAvatar(
            emoji: _profile.emoji,
            avatarUrl: _profile.avatarUrl,
            size: 40,
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile.name.isNotEmpty ? _profile.name : '我的伙伴',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (_state.activityLabel.isNotEmpty)
              Text(
                _state.activityLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              )
            else if (_voiceEnabled && _autoSpeak)
              const Text(
                '自动朗读已开',
                style: TextStyle(
                  fontSize: 11,
                  color: AiBrandTokens.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isAssistant = item.role == 'assistant';
        final itemIndex = index;
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
              if (_providerStatus.needsConfiguration) ...[
                _ModelSetupHint(
                  label: _providerLabel,
                  onConfigure: _openProviderSettings,
                ),
                const SizedBox(height: 8),
              ],
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
                        color: _listening
                            ? MoeTokens.primary
                            : MoeTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: MoeTokens.softLavenderBg,
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusXl),
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
                          hintStyle:
                              const TextStyle(color: MoeTokens.hintText),
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
                    icon: Icons.psychology_alt_rounded,
                    title: 'TA 记得的事',
                    subtitle: '查看和管理共同记忆',
                    onTap: () => Navigator.pop(sheetContext, 'memories')),
                _ChatToolTile(
                    icon: Icons.edit_note_rounded,
                    title: '编辑伙伴资料',
                    subtitle: '调整名字、表情和陪伴方式',
                    onTap: () => Navigator.pop(sheetContext, 'profile')),
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
      case 'memories':
        await Navigator.of(context).pushNamed('/ai-memories');
      case 'profile':
        await _showProfileEditor();
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

  Future<void> _showProfileEditor() async {
    final nameController = TextEditingController(text: _profile.name);
    final emojiController = TextEditingController(text: _profile.emoji);
    final personaController = TextEditingController(text: _profile.persona);
    final saved = await showDialog<CompanionProfileData>(
      context: context,
      builder: (dialogContext) {
        InputDecoration fieldDecoration(String hint) => InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: MoeTokens.hintText),
              filled: true,
              fillColor: MoeTokens.softLavenderBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceMd,
                vertical: MoeTokens.spaceSm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                borderSide: const BorderSide(color: MoeTokens.lineSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                borderSide: const BorderSide(color: MoeTokens.lineSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                borderSide: const BorderSide(color: AiBrandTokens.primary),
              ),
            );

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: MoeTokens.spaceXl),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
            ),
            child: Material(
              color: MoeTokens.surface2,
              borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MoeTokens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '伙伴资料',
                      style: TextStyle(
                        color: AiBrandTokens.titleColor,
                        fontSize: MoeTokens.textXl,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                    const SizedBox(height: MoeTokens.spaceXs),
                    const Text(
                      '改成你习惯叫 TA 的样子。',
                      style: TextStyle(
                        color: AiBrandTokens.companionInkMuted,
                        fontSize: MoeTokens.textSm,
                      ),
                    ),
                    const SizedBox(height: MoeTokens.spaceXl),
                    const Text('名字',
                        style: TextStyle(fontSize: MoeTokens.textSm)),
                    const SizedBox(height: MoeTokens.spaceXs),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDecoration('例如：啾啾'),
                    ),
                    const SizedBox(height: MoeTokens.spaceMd),
                    const Text('表情',
                        style: TextStyle(fontSize: MoeTokens.textSm)),
                    const SizedBox(height: MoeTokens.spaceXs),
                    TextField(
                      controller: emojiController,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDecoration('例如：🐤'),
                    ),
                    const SizedBox(height: MoeTokens.spaceMd),
                    const Text('陪伴方式',
                        style: TextStyle(fontSize: MoeTokens.textSm)),
                    const SizedBox(height: MoeTokens.spaceXs),
                    TextField(
                      controller: personaController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: fieldDecoration('例如：温暖、简短地陪我聊天'),
                    ),
                    const SizedBox(height: MoeTokens.spaceXl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: MoeTokens.spaceSm),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _profile.copyWith(
                              name: nameController.text.trim(),
                              emoji: emojiController.text.trim(),
                              persona: personaController.text.trim(),
                            ),
                          ),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    nameController.dispose();
    emojiController.dispose();
    personaController.dispose();
    if (saved == null || !mounted) return;
    try {
      final profile = await CompanionService().updateProfile(saved);
      if (!mounted) return;
      setState(() => _profile = profile);
      MoeToast.success(context, '伙伴资料已更新');
    } catch (error) {
      if (mounted) {
        MoeToast.error(
            context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
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

class _ProviderStatusButton extends StatelessWidget {
  const _ProviderStatusButton({
    required this.status,
    required this.label,
    required this.onTap,
  });

  final _ChatProviderStatus status;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _ChatProviderStatus.connected => const Color(0xFF28A56A),
      _ChatProviderStatus.failed ||
      _ChatProviderStatus.notConfigured =>
        const Color(0xFFE36B6B),
      _ => const Color(0xFFE4A13C),
    };
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(Icons.cloud_outlined, color: color, size: 23),
    );
  }
}

class _ModelSetupHint extends StatelessWidget {
  const _ModelSetupHint({required this.label, required this.onConfigure});

  final String label;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4E8),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFFC07A28), size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text('模型服务$label，配置后即可开始稳定对话。',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            TextButton(onPressed: onConfigure, child: const Text('去配置')),
          ],
        ),
      ),
    );
  }
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
