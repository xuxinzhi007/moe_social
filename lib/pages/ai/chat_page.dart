import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/api_service.dart';
import '../../services/ai_db_service.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_session.dart';
import '../../models/ai_chat_message.dart';

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
  
  bool _isSending = false;
  bool _isLoadingHistory = true;
  
  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String? _speakingMessageId;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initVoice();
    _loadSessions();
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
      setState(() {
        _sessions = sessions;
      });
      if (_sessions.isNotEmpty) {
        _loadSession(_sessions.first);
      } else {
        _createNewSession();
      }
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
      setState(() {
        _sessions.insert(0, session);
      });
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

    if (_currentSession == null) {
      await _createNewSession();
    }

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
    });
    _scrollToBottom();
    
    await AiDbService().insertMessage(userMsg);

    // Call API
    try {
      final history = _messages
          .where((m) => m.role != 'system') 
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
          
      // Prepend system prompt
      if (widget.agent.systemPrompt.isNotEmpty) {
        history.insert(0, {'role': 'system', 'content': widget.agent.systemPrompt});
      }

      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/chat');
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (ApiService.token != null) {
        headers['Authorization'] = 'Bearer ${ApiService.token}';
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'model': widget.agent.modelName,
          'messages': history,
        }),
      ).timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as String;
        
        final assistantMsg = AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: _currentSession!.id,
          role: 'assistant',
          content: content,
          createdAt: DateTime.now(),
        );
        
        if (mounted) {
          setState(() {
            _messages.add(assistantMsg);
          });
          await AiDbService().insertMessage(assistantMsg);
          
          // Update title if it's new
          if (_messages.length <= 2 && _currentSession!.title == '新对话') {
            final newTitle = text.length > 10 ? '${text.substring(0, 10)}...' : text;
            final updatedSession = AiChatSession(
              id: _currentSession!.id,
              agentId: widget.agent.id,
              title: newTitle,
              updatedAt: DateTime.now(),
            );
            await AiDbService().updateSession(updatedSession);
            setState(() {
              _currentSession = updatedSession;
              final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
              if (index != -1) _sessions[index] = updatedSession;
            });
          }
        }
      } else {
        final errorMsg = AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: _currentSession!.id,
          role: 'assistant',
          content: '请求失败 (${response.statusCode})',
          createdAt: DateTime.now(),
        );
        if (mounted) {
          setState(() => _messages.add(errorMsg));
          await AiDbService().insertMessage(errorMsg);
        }
      }
    } catch (e) {
      final errorMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: _currentSession!.id,
        role: 'assistant',
        content: '请求出错: $e',
        createdAt: DateTime.now(),
      );
      if (mounted) {
        setState(() => _messages.add(errorMsg));
        await AiDbService().insertMessage(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
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
       _initVoice(); // Try init again
       if (!_speechAvailable) return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
        if (result.finalResult) {
          setState(() => _isListening = false);
          _sendMessage();
        }
      },
      localeId: 'zh_CN',
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
            Text(
              _currentSession?.title ?? '加载中...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
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
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: Text(widget.agent.name),
              accountEmail: Text(widget.agent.modelName),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy_rounded, color: Theme.of(context).primaryColor),
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
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? Theme.of(context).primaryColor : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
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
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
             const CircleAvatar(
               radius: 16,
               backgroundColor: Color(0xFFE0E0E0),
               child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.black54),
             ),
             const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  SelectableText(
                    message.content,
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
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
                        onPressed: () => _playTts(message.content, message.id),
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
              child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ],
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
            icon: _isSending 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded),
            color: const Color(0xFF7F7FD5),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
