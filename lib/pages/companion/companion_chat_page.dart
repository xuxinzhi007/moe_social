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
  String? _error; // 最近一次错误

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
      final profile = await CompanionService().getProfile();
      final state = await CompanionService().getState();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _state = state;
        _isLoading = false;
      });
      // 如果有问候语，作为第一条消息展示
      if (state.greeting.isNotEmpty) {
        setState(() {
          _items.add(_ChatItem(
            role: 'assistant',
            content: state.greeting,
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _items.add(_ChatItem(role: 'user', content: text));
      _isSending = true;
      _error = null;
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
            // 最终文本可能通过 done 事件的 text 字段获取
            final finalText =
                event.text.isNotEmpty ? event.text : fullText;
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
                content: '抱歉，出了点问题，请重试。',
                isError: true,
              );
              _error = event.text;
            });
            break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // 移除空的助手消息
        if (_items.isNotEmpty &&
            _items.last.role == 'assistant' &&
            _items.last.content.isEmpty) {
          _items.removeLast();
        }
        _items.add(_ChatItem(
          role: 'assistant',
          content: '网络错误，请检查连接后重试。',
          isError: true,
        ));
        _error = e.toString();
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AiChatBackground(
        child: Column(
          children: [
            Expanded(child: _buildMessageList(theme)),
            _buildComposer(theme),
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

  Widget _buildMessageList(ThemeData theme) {
    return Column(
      children: [
        if (_error != null && !_isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.red.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => setState(() => _error = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                            agentLabel: item.role == 'assistant'
                                ? _profile.name
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_profile.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              _profile.name.isNotEmpty ? _profile.name : '我的伙伴',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _profile.persona.isNotEmpty
                  ? _profile.persona
                  : '你的 AI 好朋友，随时陪你聊天',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
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
                hintText: _isSending ? '思考中...' : '说点什么...',
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
              enabled: !_isSending,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isSending
                  ? Colors.grey.shade300
                  : AiBrandTokens.gradientPink,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
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
  final String role; // user / assistant
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
