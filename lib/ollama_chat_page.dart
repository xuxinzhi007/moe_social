import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';

class OllamaChatPage extends StatefulWidget {
  const OllamaChatPage({super.key});

  @override
  State<OllamaChatPage> createState() => _OllamaChatPageState();
}

class _ChatMessage {
  final String role;
  final String content;
  final DateTime time;

  _ChatMessage({
    required this.role,
    required this.content,
    required this.time,
  });
}

class _ChatSession {
  final String id;
  String title;
  final List<_ChatMessage> messages;
  DateTime updatedAt;

  _ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });
}

class _OllamaChatPageState extends State<OllamaChatPage> {
  static List<_ChatSession> _savedSessions = [];
  static String? _savedActiveSessionId;
  static bool _savedMemoryEnabled = true;

  final http.Client _httpClient = http.Client();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isSending = false;
  String _modelName = 'qwen2.5:0.5b-instruct';
  List<String> _models = [];
  bool _isLoadingModels = false;
  String? _modelsError;
  bool _memoryEnabled = true;
  bool _ollamaOnline = false; // Ollama 在线状态（通过模型列表判断）
  bool _wasManuallyStopped = false;

  bool _isLocalErrorAssistantMessage(_ChatMessage m) {
    if (m.role != 'assistant') return false;
    final c = m.content.trim();
    if (c.isEmpty) return false;
    return c.startsWith('请求失败') || c.startsWith('请求超时') || c.startsWith('请求出错');
  }

  @override
  void initState() {
    super.initState();
    _modelController.text = _modelName;
    if (_savedSessions.isEmpty) {
      final now = DateTime.now();
      _savedSessions = [
        _ChatSession(
          id: now.millisecondsSinceEpoch.toString(),
          title: '',
          messages: [],
          updatedAt: now,
        ),
      ];
      _savedActiveSessionId = _savedSessions.first.id;
    }
    _sessions.addAll(_savedSessions);
    _activeSessionId = _savedActiveSessionId ?? _sessions.first.id;
    _memoryEnabled = _savedMemoryEnabled;
    if (_currentSession.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _loadModels();
  }
  
  @override
  void dispose() {
    _httpClient.close();
    _controller.dispose();
    _modelController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ChatSession get _currentSession {
    final id = _activeSessionId;
    if (id != null) {
      final index = _sessions.indexWhere((s) => s.id == id);
      if (index != -1) {
        return _sessions[index];
      }
    }
    return _sessions.first;
  }

  void _saveState() {
    _savedSessions = List<_ChatSession>.from(_sessions);
    _savedActiveSessionId = _activeSessionId;
    _savedMemoryEnabled = _memoryEnabled;
  }

  void _createNewSession() {
    if (_sessions.isNotEmpty && _currentSession.messages.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final session = _ChatSession(
      id: now.millisecondsSinceEpoch.toString(),
      title: '',
      messages: [],
      updatedAt: now,
    );
    setState(() {
      _sessions.insert(0, session);
      _activeSessionId = session.id;
    });
    _saveState();
  }

  String _sessionTitle(_ChatSession session, int index) {
    var title = session.title.trim();
    final userMessages = session.messages.where((m) => m.role == 'user');
    if (userMessages.isNotEmpty) {
      if (title.isEmpty || title == '新的对话' || title.startsWith('会话 ')) {
        var t = userMessages.first.content.trim();
        if (t.length > 12) {
          t = '${t.substring(0, 12)}...';
        }
        session.title = t;
        return t;
      }
      return title;
    }
    if (title.isEmpty || title == '新的对话') {
      return '会话 ${index + 1}';
    }
    return title;
  }

  void _switchSession(String id) {
    if (_activeSessionId == id) return;
    setState(() {
      _activeSessionId = id;
    });
    _saveState();
    _scrollToBottom();
  }

  void _deleteSession(String id) {
    if (_sessions.length <= 1) return;
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index == -1) return;
    setState(() {
      _sessions.removeAt(index);
      if (_activeSessionId == id) {
        _activeSessionId = _sessions.first.id;
      }
    });
    _saveState();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    setState(() {
      _currentSession.messages.add(_ChatMessage(role: 'user', content: text, time: now));
      _currentSession.updatedAt = now;
      final currentTitle = _currentSession.title.trim();
      if (currentTitle.isEmpty || currentTitle == '新的对话' || currentTitle.startsWith('会话 ')) {
        var title = text;
        if (title.length > 12) {
          title = '${title.substring(0, 12)}...';
        }
        _currentSession.title = title;
      }
      _controller.clear();
    });
    _saveState();
    _scrollToBottom();

    // 调用后端 API
    await _callOllama();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
      _modelsError = null;
    });

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/models');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<String> list = <String>[];
        if (data is Map && data['models'] is List) {
          final raw = data['models'] as List;
          if (raw.whereType<String>().isNotEmpty) {
            list = raw.whereType<String>().toList();
          } else {
            list = raw
                .whereType<Map>()
                .map((m) => m['name'])
                .whereType<String>()
                .toList();
          }
        }
        if (list.isNotEmpty) {
          setState(() {
            _models = list;
            _ollamaOnline = true; // 成功获取模型列表，Ollama 在线
            if (!_models.contains(_modelName)) {
              _modelName = _models.first;
              _modelController.text = _modelName;
            }
          });
        }
      } else {
        setState(() {
          _modelsError = '获取模型列表失败 (${response.statusCode})';
          _ollamaOnline = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _modelsError = '获取模型列表超时';
        _ollamaOnline = false;
      });
    } catch (e) {
      setState(() {
        _modelsError = '获取模型列表出错: $e';
        _ollamaOnline = false;
      });
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _callOllama() async {
    if (_currentSession.messages.isEmpty) return;
    setState(() {
      _isSending = true;
    });
    _wasManuallyStopped = false;

    List<_ChatMessage> sourceMessages;
    if (_memoryEnabled) {
      sourceMessages = List<_ChatMessage>.from(_currentSession.messages);
    } else {
      final lastUser = _currentSession.messages.lastWhere(
        (m) => m.role == 'user',
        orElse: () => _currentSession.messages.last,
      );
      sourceMessages = [lastUser];
    }

    final apiMessages = sourceMessages
        // 过滤掉本地生成的“错误气泡”，避免把错误文本当作对话上下文发给模型
        .where((m) => !_isLocalErrorAssistantMessage(m))
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final assistantIndex = _currentSession.messages.length;
    setState(() {
      _currentSession.messages.add(_ChatMessage(role: 'assistant', content: '', time: DateTime.now()));
      _currentSession.updatedAt = DateTime.now();
    });
    _saveState();
    _scrollToBottom();

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/chat');
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = ApiService.token;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': _modelName,
              'messages': apiMessages,
            }),
          )
          // LLM 生成首包可能较慢（尤其是首次加载模型时），这里给更宽裕的超时
          .timeout(const Duration(seconds: 180));

      if (response.statusCode != 200) {
        if (_wasManuallyStopped) {
          return;
        }
        final body = response.body;
        final errorText =
            '请求失败 (${response.statusCode})${body.isNotEmpty ? '\n$body' : ''}';
        setState(() {
          _currentSession.messages[assistantIndex] = _ChatMessage(
            role: 'assistant',
            content: errorText,
            time: DateTime.now(),
          );
          _currentSession.updatedAt = DateTime.now();
        });
        _saveState();
        _scrollToBottom();
        return;
      }

      final data = jsonDecode(response.body);
      final content = data is Map && data['content'] is String ? data['content'] as String : '';
      setState(() {
        _currentSession.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: content,
          time: DateTime.now(),
        );
        _currentSession.updatedAt = DateTime.now();
      });
      _saveState();
      _scrollToBottom();
    } on TimeoutException {
      if (_wasManuallyStopped) {
        return;
      }
      setState(() {
        _currentSession.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: '请求超时，请检查 Ollama 服务是否运行',
          time: DateTime.now(),
        );
        _currentSession.updatedAt = DateTime.now();
      });
      _saveState();
      _scrollToBottom();
    } catch (e) {
      if (_wasManuallyStopped) {
        return;
      }
      setState(() {
        _currentSession.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: '请求出错: $e',
          time: DateTime.now(),
        );
        _currentSession.updatedAt = DateTime.now();
      });
      _saveState();
      _scrollToBottom();
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _stopGeneration() {
    if (!_isSending) return;
    _wasManuallyStopped = true;
    _httpClient.close();
    final now = DateTime.now();
    setState(() {
      if (_currentSession.messages.isNotEmpty) {
        final last = _currentSession.messages.last;
        if (last.role == 'assistant' && last.content.isEmpty) {
          _currentSession.messages[_currentSession.messages.length - 1] =
              _ChatMessage(role: 'assistant', content: '已手动停止生成', time: now);
        }
      }
      _currentSession.updatedAt = now;
      _isSending = false;
    });
    _saveState();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.memory_rounded),
                    title: const Text('记忆功能'),
                    subtitle: const Text('开启后会携带历史对话作为上下文'),
                    trailing: Switch(
                      value: _memoryEnabled,
                      onChanged: (value) {
                        setModalState(() {
                          setState(() {
                            _memoryEnabled = value;
                            _saveState();
                          });
                        });
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('清空当前聊天记录'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _currentSession.messages.clear();
                        _currentSession.updatedAt = DateTime.now();
                        _saveState();
                      });
                    },
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? const Color(0xFF7F7FD5) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.content.isEmpty ? '...' : message.content,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ollama 聊天',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            // Ollama 在线状态指示器
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _ollamaOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isActive = session.id == _activeSessionId;
                      final title = _sessionTitle(session, index);
                      return GestureDetector(
                        onTap: () => _switchSession(session.id),
                        onLongPress: () => _deleteSession(session.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF7F7FD5) : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_comment_rounded, size: 20),
                  color: const Color(0xFF7F7FD5),
                  onPressed: _createNewSession,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.memory_rounded, size: 20, color: Color(0xFF7F7FD5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_models.isNotEmpty)
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _modelName,
                            isExpanded: true,
                            items: _models
                                .map(
                                  (name) => DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _modelName = value;
                                _modelController.text = value;
                              });
                            },
                          ),
                        )
                      else
                        TextField(
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            labelText: '模型名称',
                          ),
                          controller: _modelController,
                          onSubmitted: (value) {
                            final name = value.trim();
                            if (name.isNotEmpty) {
                              setState(() {
                                _modelName = name;
                                _modelController.text = name;
                              });
                            }
                          },
                        ),
                      if (_modelsError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _modelsError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isLoadingModels
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  color: const Color(0xFF7F7FD5),
                  onPressed: _isLoadingModels ? null : _loadModels,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _currentSession.messages.length,
              itemBuilder: (context, index) {
                final message = _currentSession.messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: '输入消息，按回车或右侧按钮发送',
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isSending ? _stopGeneration : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(_isSending ? Icons.stop_rounded : Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
