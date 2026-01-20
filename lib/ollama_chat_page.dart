import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double remainingRatio;
  String customPrompt;

  _ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
    this.remainingRatio = 1.0,
    this.customPrompt = '',
  });
}

class _OllamaChatPageState extends State<OllamaChatPage> {
  static List<_ChatSession> _savedSessions = [];
  static String? _savedActiveSessionId;
  // memoryEnabled logic removed - always enable context
  final http.Client _httpClient = http.Client();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _promptController = TextEditingController();
  final List<_ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isSending = false;
  String _modelName = 'qwen2.5:0.5b-instruct';
  List<String> _models = [];
  bool _isLoadingModels = false;
  String? _modelsError;
  // bool _memoryEnabled = true; // Always true now
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
          remainingRatio: 1.0,
        ),
      ];
      _savedActiveSessionId = _savedSessions.first.id;
    }
    _sessions.addAll(_savedSessions);
    _activeSessionId = _savedActiveSessionId ?? _sessions.first.id;
    _promptController.text = _currentSession.customPrompt;
    // _memoryEnabled = _savedMemoryEnabled;
    if (_currentSession.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _loadModels();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _modelController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _promptController.dispose();
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
    // _savedMemoryEnabled = _memoryEnabled;
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
      remainingRatio: 1.0,
      customPrompt: '',
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
      _promptController.text = _currentSession.customPrompt;
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
    // 保持输入框焦点
    _focusNode.requestFocus();

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

    List<_ChatMessage> sourceMessages = List<_ChatMessage>.from(_currentSession.messages);

    final List<Map<String, String>> apiMessages = [];

    final customPrompt = _currentSession.customPrompt.trim();
    if (customPrompt.isNotEmpty) {
      apiMessages.add({'role': 'system', 'content': customPrompt});
    }

    apiMessages.addAll(
      sourceMessages
          .where((m) => !_isLocalErrorAssistantMessage(m) && m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content}),
    );

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
      final remainingRatio = data is Map && data['remaining_ratio'] is num
          ? (data['remaining_ratio'] as num).toDouble()
          : 1.0;
      final summarized = data is Map && data['summarized'] == true;
      setState(() {
        _currentSession.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: content,
          time: DateTime.now(),
        );
        _currentSession.updatedAt = DateTime.now();
        _currentSession.remainingRatio = remainingRatio.clamp(0.0, 1.0);
        if (summarized) {
          _currentSession.messages.insert(
            assistantIndex,
            _ChatMessage(
              role: 'assistant',
              content: '我已经整理了部分较早的聊天内容，并记住了其中的重要信息。',
              time: DateTime.now(),
            ),
          );
        }
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
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (_models.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.psychology_rounded),
                      title: const Text('选择模型'),
                      subtitle: Text(_modelName),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) {
                            return SimpleDialog(
                              title: const Text('选择模型'),
                              children: _models.map((m) {
                                return SimpleDialogOption(
                                  onPressed: () {
                                    Navigator.pop(context, m);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      m,
                                      style: TextStyle(
                                        color: m == _modelName
                                            ? const Color(0xFF7F7FD5)
                                            : Colors.black87,
                                        fontWeight: m == _modelName
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                        if (result != null) {
                          setModalState(() {
                            setState(() {
                              _modelName = result;
                              _modelController.text = result;
                            });
                            _showModelChanged(result);
                          });
                        }
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('刷新模型列表'),
                      subtitle: Text(_modelsError ?? '暂无模型'),
                      onTap: () {
                         _loadModels();
                         Navigator.pop(context);
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '自定义提示词',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: TextField(
                            controller: _promptController,
                            maxLines: 5,
                            minLines: 2,
                            onChanged: (value) {
                              setModalState(() {});
                              setState(() {
                                _currentSession.customPrompt = value;
                                _saveState();
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: '例如：你是一位擅长写代码和解释技术细节的中文助手，回答要简洁、有条理。',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text('清空当前聊天记录', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _currentSession.messages.clear();
                        _currentSession.updatedAt = DateTime.now();
                        _currentSession.remainingRatio = 1.0;
                        _saveState();
                      });
                    },
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday = now.year == time.year && now.month == time.month && now.day == time.day;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (isToday) {
      return '$hour:$minute';
    } else {
      final month = time.month.toString().padLeft(2, '0');
      final day = time.day.toString().padLeft(2, '0');
      return '$month-$day $hour:$minute';
    }
  }

  Widget _buildTimeDivider(DateTime time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Text(
        _formatTime(time),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showModelChanged(String name) {
    if (name.isEmpty) return;
    setState(() {
      _currentSession.messages.add(_ChatMessage(
        role: 'system',
        content: '已切换到模型 $name',
        time: DateTime.now(),
      ));
      _currentSession.updatedAt = DateTime.now();
    });
    _saveState();
    _scrollToBottom();
  }

  void _copyMessage(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    if (message.role == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: SelectableText(
          message.content,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      );
    }

    final isUser = message.role == 'user';
    final color = isUser ? const Color(0xFF7F7FD5) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: GestureDetector(
                onLongPress: () => _copyMessage(message.content),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.content.isEmpty ? '...' : message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
             onTap: _isSending ? _stopGeneration : _sendMessage,
             child: Container(
               width: 48,
               height: 48,
               decoration: BoxDecoration(
                 color: _isSending ? Colors.redAccent : const Color(0xFF7F7FD5),
                 shape: BoxShape.circle,
                 boxShadow: [
                   BoxShadow(
                     color: (_isSending ? Colors.redAccent : const Color(0xFF7F7FD5)).withOpacity(0.4),
                     blurRadius: 8,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: Icon(
                 _isSending ? Icons.stop_rounded : Icons.send_rounded,
                 color: Colors.white,
                 size: 24,
               ),
             ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: _models.isNotEmpty ? _openSettings : null,
          child: Column(
            children: [
              const Text(
                'Ollama 聊天',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_models.isNotEmpty)
                Text(
                  _modelName,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettings,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _currentSession.remainingRatio.clamp(0.0, 1.0),
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              _currentSession.remainingRatio > 0.5
                  ? const Color(0xFF4CAF50)
                  : _currentSession.remainingRatio > 0.2
                      ? const Color(0xFFFFC107)
                      : const Color(0xFFF44336),
            ),
            minHeight: 2,
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF7F7FD5)),
              accountName: const Text('Ollama AI'),
              accountEmail: Text(_ollamaOnline ? '服务在线' : '服务离线'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy_rounded, size: 36, color: Color(0xFF7F7FD5)),
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
                padding: EdgeInsets.zero,
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isActive = session.id == _activeSessionId;
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    title: Text(
                      _sessionTitle(session, index),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? const Color(0xFF7F7FD5) : null,
                      ),
                    ),
                    selected: isActive,
                    selectedTileColor: const Color(0xFF7F7FD5).withOpacity(0.1),
                    onTap: () {
                      Navigator.pop(context);
                      _switchSession(session.id);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _deleteSession(session.id),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('模型设置'),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _currentSession.messages.length,
              itemBuilder: (context, index) {
                final message = _currentSession.messages[index];
                bool showTime = false;
                if (index == 0) {
                  showTime = true;
                } else {
                  final prevMessage = _currentSession.messages[index - 1];
                  final diff = message.time.difference(prevMessage.time).inMinutes.abs();
                  if (diff > 5) {
                    showTime = true;
                  }
                }

                return Column(
                  children: [
                    if (showTime) _buildTimeDivider(message.time),
                    _buildMessageBubble(message),
                  ],
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }
}
