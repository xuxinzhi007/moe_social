import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../services/memory_service.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_session.dart';
import '../../models/ai_chat_message.dart';
import '../../models/ai_memory.dart';
import 'memory_manager_page.dart';

class ChatPage extends StatefulWidget {
  final AiAgent agent;

  const ChatPage({super.key, required this.agent});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  List<AiChatMessage> _messages = [];
  List<AiMemory> _memories = [];

  bool _isSending = false;
  bool _isLoadingHistory = true;
  bool _wasManuallyStopped = false;

  // 上次新增记忆数量（用于提示气泡）
  int _lastNewMemoryCount = 0;

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String? _speakingMessageId;

  @override
  void initState() {
    super.initState();
    _initVoice();
    _loadSessions();
    _loadMemories();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
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

  Future<void> _loadMemories() async {
    final memories = await AiDbService().getMemories(widget.agent.id);
    if (mounted) setState(() => _memories = memories);
  }

  Future<void> _createNewSession() async {
    final session = AiChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      agentId: widget.agent.id,
      title: '新对话',
      updatedAt: DateTime.now(),
    );
    await AiDbService().insertSession(session);
    if (mounted) {
      setState(() => _sessions.insert(0, session));
      _loadSession(session);
    }
  }

  Future<void> _loadSession(AiChatSession session) async {
    setState(() {
      _currentSession = session;
      _isLoadingHistory = true;
    });
    final messages = await AiDbService().getMessages(session.id);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _deleteSession(String id) async {
    await AiDbService().deleteSession(id);
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
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_currentSession == null) await _createNewSession();

    final now = DateTime.now();
    final userMsg = AiChatMessage(
      id: now.millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'user',
      content: text,
      createdAt: now,
    );

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _isSending = true;
      _wasManuallyStopped = false;
      _lastNewMemoryCount = 0;
    });
    _scrollToBottom();
    await AiDbService().insertMessage(userMsg);

    try {
      final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();

      // ── 构建对话历史（排除 system 角色，避免重复） ──────────────────
      final history = _messages
          .where((m) => m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // ── 始终注入 System Prompt + 长期记忆（已修复：不再受 terminalMode 影响）──
      final enrichedSystemPrompt = MemoryService.buildPromptWithMemories(
        widget.agent.systemPrompt,
        _memories,
      );
      history.insert(0, {'role': 'system', 'content': enrichedSystemPrompt});

      final uri = await LlmEndpointConfig.chatUri();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (ApiService.token != null) {
        headers['Authorization'] = 'Bearer ${ApiService.token}';
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': widget.agent.modelName,
              'messages': history,
              if (terminalMode) 'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 180));

      if (_wasManuallyStopped) return;

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        String rawContent = '';

        if (terminalMode) {
          final msg = (data is Map) ? data['message'] : null;
          if (msg is Map && msg['content'] is String) {
            rawContent = msg['content'] as String;
          } else if (data is Map && data['error'] is String) {
            rawContent = 'Ollama 错误: ${data['error']}';
          } else {
            rawContent = '响应格式异常（直连 Ollama）';
          }
        } else {
          if (data is Map && data['content'] is String) {
            rawContent = data['content'] as String;
          } else {
            rawContent = '响应格式异常（后端）';
          }
        }

        // ── 提取并保存新记忆 ─────────────────────────────────────────
        final extractedTexts = MemoryService.extractMemories(rawContent);
        if (extractedTexts.isNotEmpty) {
          final newMemories = <AiMemory>[];
          for (final text in extractedTexts) {
            final mem = AiMemory(
              id: '${DateTime.now().millisecondsSinceEpoch}_${newMemories.length}',
              agentId: widget.agent.id,
              content: text,
              category: MemoryService.inferCategory(text),
              importance: MemoryService.inferImportance(text),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await AiDbService().insertMemory(mem);
            newMemories.add(mem);
          }
          if (mounted) {
            setState(() {
              _memories = [..._memories, ...newMemories];
              _lastNewMemoryCount = newMemories.length;
            });
          }
        }

        // ── 清理展示内容（移除记忆标签） ─────────────────────────────
        final displayContent = MemoryService.cleanResponse(rawContent);

        final assistantMsg = AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: _currentSession!.id,
          role: 'assistant',
          content: displayContent,
          createdAt: DateTime.now(),
        );

        await AiDbService().insertMessage(assistantMsg);

        if (mounted) {
          setState(() => _messages.add(assistantMsg));

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
            await AiDbService().updateSession(updatedSession);
            setState(() {
              _currentSession = updatedSession;
              final idx =
                  _sessions.indexWhere((s) => s.id == updatedSession.id);
              if (idx != -1) _sessions[idx] = updatedSession;
            });
          }
        }
      } else {
        if (_wasManuallyStopped) return;
        await _appendError('请求失败 (${response.statusCode})');
      }
    } catch (e) {
      if (_wasManuallyStopped) return;
      await _appendError('请求出错: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
        // 显示记忆提示气泡
        if (_lastNewMemoryCount > 0) {
          _showMemorySnackBar(_lastNewMemoryCount);
        }
      }
    }
  }

  Future<void> _appendError(String text) async {
    final errorMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      role: 'assistant',
      content: text,
      createdAt: DateTime.now(),
    );
    await AiDbService().insertMessage(errorMsg);
    if (mounted) setState(() => _messages.add(errorMsg));
  }

  void _showMemorySnackBar(int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Text('🧠', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('已记住 $count 条新信息'),
          ],
        ),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => _openMemoryManager(),
        ),
      ),
    );
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

  Future<void> _playTts(String text, String msgId) async {
    if (_isSpeaking && _speakingMessageId == msgId) {
      await _tts.stop();
      setState(() {
        _isSpeaking = false;
        _speakingMessageId = null;
      });
      return;
    }
    await _tts.stop();
    setState(() {
      _isSpeaking = true;
      _speakingMessageId = msgId;
    });
    await _tts.speak(text);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      _initVoice();
      if (!_speechAvailable) return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _isListening = false);
          _sendMessage();
        }
      },
      localeId: 'zh_CN',
    );
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
    AiDbService().insertMessage(msg);
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
    ).then((_) => _loadMemories());
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
                          if (agent.systemPrompt.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label:
                                  const Text('复制', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: agent.systemPrompt));
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('提示词已复制')),
                                );
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
                        child: agent.systemPrompt.isEmpty
                            ? Text('未设置系统提示词',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic))
                            : SelectableText(
                                agent.systemPrompt,
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
                          Text(
                            '长期记忆（${_memories.length} 条）',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openMemoryManager();
                            },
                            child: const Text('管理', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      if (_memories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '暂无记忆。和 AI 多聊几句，它会自动记住重要信息。',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                                fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...(_memories.take(3).map((m) {
                          final (_, emoji) = AiMemory.categoryMeta(m.category);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    m.content,
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
                      if (_memories.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openMemoryManager();
                            },
                            child: Text('查看全部 ${_memories.length} 条记忆'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.agent.name, style: const TextStyle(fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<bool>(
                  future: LlmEndpointConfig.isTerminalModeEnabled(),
                  builder: (context, snapshot) {
                    final terminal = snapshot.data == true;
                    final sessionTitle = _currentSession?.title ?? '加载中...';
                    final suffix = terminal ? ' · 终端同款' : '';
                    return Text(
                      '$sessionTitle$suffix',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  },
                ),
                if (_memories.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🧠${_memories.length}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.purple.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '查看智能体信息',
            onPressed: _showAgentInfo,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration:
                  BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: Text(widget.agent.name),
              accountEmail: Text(widget.agent.modelName),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy_rounded,
                    color: Theme.of(context).primaryColor),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_rounded),
              title: const Text('新对话'),
              onTap: () {
                Navigator.pop(context);
                _createNewSession();
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_rounded),
              title: Text('记忆库（${_memories.length} 条）'),
              onTap: () {
                Navigator.pop(context);
                _openMemoryManager();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isCurrent = session.id == _currentSession?.id;
                  return ListTile(
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    selected: isCurrent,
                    onTap: () {
                      Navigator.pop(context);
                      _loadSession(session);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _deleteSession(session.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending && index == _messages.length) {
                        return _buildTypingBubble();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message) {
    final isUser = message.role == 'user';
    final color = isUser ? const Color(0xFF7F7FD5) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(Icons.smart_toy_rounded,
                  size: 18, color: Colors.black54),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () async {
                      final text = message.content.trim();
                      if (text.isEmpty) return;
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                    child: SelectableText(
                      message.content,
                      style: TextStyle(
                          color: textColor, fontSize: 15, height: 1.5),
                    ),
                  ),
                  if (!isUser)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          _isSpeaking && _speakingMessageId == message.id
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            _playTts(message.content, message.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF7F7FD5),
              child:
                  Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE0E0E0),
            child: Icon(Icons.smart_toy_rounded,
                size: 18, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: _TypingDotsIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            color: _isListening ? Colors.red : const Color(0xFF7F7FD5),
            onPressed: _toggleListening,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                _isSending ? Icons.stop_rounded : Icons.send_rounded),
            color: _isSending ? Colors.red : const Color(0xFF7F7FD5),
            onPressed: _isSending ? _stopGeneration : _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _TypingDotsIndicator extends StatefulWidget {
  const _TypingDotsIndicator();

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i / 3.0) % 1.0;
            final y = phase < 0.5
                ? -6.0 * math.sin(phase * math.pi * 2)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
