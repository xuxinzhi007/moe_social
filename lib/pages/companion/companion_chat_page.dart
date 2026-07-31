import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../constants/feature_flags.dart';
import '../../providers/companion_presence_provider.dart';
import '../../services/ai_tts_helper.dart';
import '../../services/companion_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/moe_toast.dart';

/// 伙伴聊天页 —— 接入后端 SSE 流式聊天，所有 Prompt/LLM 逻辑由后端处理。
class CompanionChatPage extends StatefulWidget {
  const CompanionChatPage({super.key});

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

  // AIRI 向轻量语音（本机 STT/TTS；非 Live2D）
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late final AiTtsHelper _ttsHelper;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _autoSpeak = false;
  bool _isSpeaking = false;
  int? _speakingIndex;

  bool get _voiceEnabled => FeatureFlags.companionVoicePresence;

  @override
  void initState() {
    super.initState();
    _ttsHelper = AiTtsHelper(_tts);
    if (_voiceEnabled) {
      unawaited(_initVoice());
    }
    _loadInitialData();
  }

  Future<void> _initVoice() async {
    try {
      _speechAvailable = await _speech.initialize();
    } catch (_) {
      _speechAvailable = false;
    }
    await _ttsHelper.initialize();
    _ttsHelper.bindHandlers(
      onComplete: () {
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
      unawaited(_tts.stop());
    }
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _items.add(_ChatItem(role: 'user', content: text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      var fullText = '';
      setState(() {
        _items.add(
          const _ChatItem(role: 'assistant', content: '', isStreaming: true),
        );
      });

      await for (final event in CompanionService().chatStream(text)) {
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
            final finalText = event.text.trim().isNotEmpty
                ? event.text.trim()
                : fullText.trim();
            final spoken = finalText.isNotEmpty
                ? finalText
                : '我在呢～刚才走神了一下，再说一次好吗？';
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
            if (_voiceEnabled && _autoSpeak) {
              unawaited(_speakAt(_items.length - 1, spoken));
            }
            break;
          case 'error':
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: '抱歉，我走神了一下，再跟我说一次？',
                isError: true,
              );
            });
            break;
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
    }
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
          MoeToast.error(context, '当前设备不支持语音输入');
        }
        return;
      }
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        if (result.finalResult) {
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
  }

  Future<void> _speakAt(int index, String text) async {
    if (!_voiceEnabled || text.trim().isEmpty) return;
    if (_isSpeaking && _speakingIndex == index) {
      await _ttsHelper.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      }
      return;
    }
    try {
      setState(() {
        _isSpeaking = true;
        _speakingIndex = index;
      });
      await _ttsHelper.speak(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
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
        title: _buildAppBarTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_voiceEnabled)
            IconButton(
              tooltip: _autoSpeak ? '关闭自动朗读' : '开启自动朗读',
              onPressed: () {
                setState(() => _autoSpeak = !_autoSpeak);
                MoeToast.success(
                  context,
                  _autoSpeak ? '已开启：TA 说完会朗读' : '已关闭自动朗读',
                );
              },
              icon: Icon(
                _autoSpeak
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_over_off_rounded,
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
        CompanionAvatar(
          emoji: _profile.emoji,
          avatarUrl: _profile.avatarUrl,
          size: 28,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile.name.isNotEmpty ? _profile.name : '我的伙伴',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_state.activityLabel.isNotEmpty)
              Text(
                _state.activityLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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

    // ── 错误降级：友好提示卡片 ──
    if (_loadError != null) {
      return _buildFallbackCard();
    }

    // ── 空态：首次进入欢迎卡 ──
    if (_items.isEmpty) {
      return _buildWelcomeCard();
    }

    // ── 消息列表 ──
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isAssistant = item.role == 'assistant';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: isAssistant
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              AiMessageBubble(
                content: item.content,
                contentType: MessageContentType.text,
                isUser: item.role == 'user',
                isLoading: item.isStreaming,
                agentLabel: isAssistant ? _profile.name : null,
              ),
              if (_voiceEnabled &&
                  isAssistant &&
                  !item.isStreaming &&
                  !item.isError &&
                  item.content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _isSpeaking && _speakingIndex == index
                        ? '停止朗读'
                        : '朗读',
                    onPressed: () => unawaited(
                      _speakAt(index, item.content),
                    ),
                    icon: Icon(
                      _isSpeaking && _speakingIndex == index
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_rounded,
                      size: 18,
                      color: _isSpeaking && _speakingIndex == index
                          ? AiBrandTokens.primary
                          : Colors.grey.shade500,
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
    final theme = Theme.of(context);
    final hasError = _loadError != null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (_voiceEnabled) ...[
            IconButton(
              tooltip: _listening ? '停止听写' : '语音输入',
              onPressed: (_isSending || hasError)
                  ? null
                  : () => unawaited(_toggleListen()),
              icon: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _listening
                    ? AiBrandTokens.primary
                    : Colors.grey.shade600,
              ),
            ),
          ],
          Expanded(
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
                            ? '思考中...'
                            : '说点什么...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isSending && !hasError,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: (_isSending || hasError)
                  ? Colors.grey.shade300
                  : AiBrandTokens.gradientPink,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: (_isSending || hasError) ? null : _sendMessage,
              icon: Icon(
                _isSending ? Icons.hourglass_empty : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
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

  const _ChatItem({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError = false,
  });
}
