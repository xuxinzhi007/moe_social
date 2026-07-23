import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/companion_service.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_brand_tokens.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    CompanionService().cancelStream();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final snapshot = await CompanionService().getSnapshot();
      if (!mounted) return;
      setState(() {
        _profile = snapshot.profile;
        _state = snapshot.state;
        _isLoading = false;
        _loadError = null;
      });
      if (snapshot.state.greeting.isNotEmpty) {
        setState(() {
          _items.add(_ChatItem(
            role: 'assistant',
            content: snapshot.state.greeting,
          ));
        });
      }
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
        _items.add(_ChatItem(role: 'assistant', content: ''));
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
            final finalText = event.text.isNotEmpty ? event.text : fullText;
            setState(() {
              _items.last = _ChatItem(
                role: 'assistant',
                content: finalText,
                isStreaming: false,
              );
            });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        Text(_profile.emoji, style: const TextStyle(fontSize: 20)),
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AiMessageBubble(
            content: item.content,
            contentType: MessageContentType.text,
            isUser: item.role == 'user',
            isLoading: item.isStreaming,
            agentLabel: item.role == 'assistant' ? _profile.name : null,
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
