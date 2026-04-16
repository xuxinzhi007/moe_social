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
import '../../services/memory_agent_service.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_session.dart';
import '../../models/ai_chat_message.dart';
import '../../models/ai_memory.dart';
import '../../models/ai_memory_profile.dart';
import '../../models/ai_memory_settings.dart';
import '../../widgets/fade_in_up.dart';
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
  List<AiMemoryProfile> _profiles = [];
  AiMemorySettings? _memorySettings;

  bool _isSending = false;
  bool _isLoadingHistory = true;
  bool _wasManuallyStopped = false;


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

  @override
  void initState() {
    super.initState();
    _initVoice();
    _loadSessions();
    _loadMemoryState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
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

  Future<void> _loadMemoryState() async {
    final db = AiDbService();
    final agentService = MemoryAgentService();
    final memories = await db.getMemories(widget.agent.id);
    final profiles = await db.getMemoryProfiles(widget.agent.id);
    final settings = await agentService.getOrCreateSettings(widget.agent);
    if (mounted) {
      setState(() {
        _memories = memories;
        _profiles = profiles;
        _memorySettings = settings;
      });
    }
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

      // 使用本地记忆智能体构建注入上下文：画像 + 高优先级原始记忆
      final enrichedSystemPrompt =
          await MemoryAgentService().buildInjectedPrompt(widget.agent);
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
        String content = '';

        if (terminalMode) {
          final msg = (data is Map) ? data['message'] : null;
          if (msg is Map && msg['content'] is String) {
            content = msg['content'] as String;
          } else if (data is Map && data['error'] is String) {
            final errorMessage = data['error'] as String;
            if (errorMessage.contains('model not found')) {
              content = '模型不存在，请选择一个真实存在的模型。\n\n建议：\n1. 检查Ollama是否已安装该模型\n2. 尝试使用常见模型如 llama3:8b\n3. 确保模型名称拼写正确';
            } else {
              content = 'Ollama 错误: $errorMessage';
            }
          } else {
            content = '响应格式异常（直连 Ollama）';
          }
        } else {
          if (data is Map && data['content'] is String) {
            content = data['content'] as String;
          } else if (data is Map && data['error'] is String) {
            final errorMessage = data['error'] as String;
            if (errorMessage.contains('model not found')) {
              content = '模型不存在，请选择一个真实存在的模型。\n\n建议：\n1. 检查Ollama是否已安装该模型\n2. 尝试使用常见模型如 llama3:8b\n3. 确保模型名称拼写正确';
            } else {
              content = '后端错误: $errorMessage';
            }
          } else {
            content = '响应格式异常（后端）';
          }
        }

        final assistantMsg = AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: _currentSession!.id,
          role: 'assistant',
          content: content,
          createdAt: DateTime.now(),
        );

        await AiDbService().insertMessage(assistantMsg);

        // ── 后台静默交给记忆智能体：提取 + 必要时整理画像 ──────────────
        _processMemoryTurnInBackground(text, content);

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
      }
    }
  }

  /// 后台本地记忆智能体：提取新记忆，并在阈值满足时整理画像。
  Future<void> _processMemoryTurnInBackground(
    String userMessage,
    String aiResponse,
  ) async {
    try {
      final result = await MemoryAgentService().processConversationTurn(
        agent: widget.agent,
        sessionId: _currentSession!.id,
        userMessage: userMessage,
        aiResponse: aiResponse,
      );
      await _loadMemoryState();
      if (!mounted || result.newMemoryCount <= 0) return;
      _showMemorySnackBar(result.newMemoryCount);
    } catch (_) {
      // 记忆是增强功能，失败时不影响主对话
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音播放失败：${e.toString()}')),
        );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('语音识别不可用')),
            );
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
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('语音识别失败：${error.errorMsg}')),
            );
          }
        },
        localeId: 'zh_CN',
        partialResults: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败：${e.toString()}')),
        );
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
                    child: const Icon(Icons.reply_rounded, color: Color(0xFF7F7FD5)),
                  ),
                  title: const Text('回复消息', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  title: const Text('复制内容', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: message.content));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
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
                    child: const Icon(Icons.edit_rounded, color: Colors.orange),
                  ),
                  title: const Text('编辑消息', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: const Icon(Icons.quote_rounded, color: Colors.green),
                  ),
                  title: const Text('引用消息', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _quoteMessage(message);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _markedMessages.contains(message.id) ? Colors.yellow.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _markedMessages.contains(message.id) ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _markedMessages.contains(message.id) ? Colors.yellow : Colors.blue,
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
                      child: const Icon(Icons.delete_rounded, color: Colors.red),
                    ),
                    title: const Text('撤回消息', style: TextStyle(fontWeight: FontWeight.bold)),
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
      _controller.text = "@AI " + message.content.substring(0, message.content.length > 50 ? 50 : message.content.length) + "...\n";
      _focusNode.requestFocus();
    });
  }

  void _editMessage(AiChatMessage message) {
    setState(() {
      _controller.text = message.content;
      _focusNode.requestFocus();
      // 从消息列表中移除原消息
      _messages.removeWhere((msg) => msg.id == message.id);
      _saveMessages();
    });
  }

  void _quoteMessage(AiChatMessage message) {
    setState(() {
      _controller.text = "> ${message.content.substring(0, message.content.length > 100 ? 100 : message.content.length)}${message.content.length > 100 ? '...' : ''}\n\n";
      _focusNode.requestFocus();
    });
  }

  void _toggleMessageMark(AiChatMessage message) {
    setState(() {
      if (_markedMessages.contains(message.id)) {
        _markedMessages.remove(message.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消标记')),
        );
      } else {
        _markedMessages.add(message.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记消息')),
        );
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.removeWhere((msg) => msg.id == message.id);
                _saveMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('消息已撤回')),
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? '输入关键词开始搜索'
                    : '未找到匹配的消息',
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
            // 这里可以添加滚动到对应消息的逻辑
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
                        message.role == 'user' ? Icons.person_rounded : Icons.smart_toy_rounded,
                        size: 14,
                        color: message.role == 'user' ? Colors.white : Theme.of(context).primaryColor,
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
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
          borderTop: Border.all(color: Colors.grey.shade200),
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
                return GestureDetector(
                  onTap: () => _selectQuickReply(reply),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      reply,
                      style: const TextStyle(fontSize: 13),
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
    if (_isSearching) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _toggleSearch,
          ),
          title: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '搜索消息...',
              border: InputBorder.none,
            ),
            onChanged: _performSearch,
          ),
          elevation: 0,
        ),
        body: _buildSearchResults(),
      );
    }

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
    final textColor = isUser ? Colors.white : Colors.black87;
    final timeStr = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    return FadeInUp(
      key: ValueKey(message.id),
      duration: const Duration(milliseconds: 200),
      delay: const Duration(milliseconds: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(Icons.smart_toy_rounded, size: 18, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser ? const Color(0xFFE94057) : Colors.black).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onLongPress: () async {
                                    final text = message.content.trim();
                                    if (text.isEmpty) return;
                                    _showMessageActions(message);
                                  },
                                  child: SelectableText(
                                    message.content,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              if (_markedMessages.contains(message.id))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: isUser ? Colors.white : Colors.yellow,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                        if (!isUser) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
                        ]
                      ],
                    ),
                  ),
                  if (isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE94057),
                child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Icon(Icons.smart_toy_rounded, size: 18, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const _TypingDotsIndicator(),
          ),
        ],
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
                  icon: Icon(_showQuickReplies ? Icons.keyboard_rounded : Icons.chat_bubble_outline_rounded),
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
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _isListening ? '请说话...' : '输入消息...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          gradient: LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
