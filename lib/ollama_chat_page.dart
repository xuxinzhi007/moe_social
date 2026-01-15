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

class _OllamaChatPageState extends State<OllamaChatPage> {
  static List<_ChatMessage> _savedMessages = [];
  static bool _savedMemoryEnabled = true;

  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String _modelName = 'qwen2.5:0.5b-instruct';
  List<String> _models = [];
  bool _isLoadingModels = false;
  String? _modelsError;
  bool _memoryEnabled = true;

  @override
  void initState() {
    super.initState();
    _modelController.text = _modelName;
    _messages.addAll(_savedMessages);
    _memoryEnabled = _savedMemoryEnabled;
    if (_messages.isNotEmpty) {
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
    super.dispose();
  }

  void _saveState() {
    _savedMessages = List<_ChatMessage>.from(_messages);
    _savedMemoryEnabled = _memoryEnabled;
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text, time: now));
      _controller.clear();
    });
    _saveState();
    _scrollToBottom();

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
            if (!_models.contains(_modelName)) {
              _modelName = _models.first;
              _modelController.text = _modelName;
            }
          });
        }
      } else {
        setState(() {
          _modelsError = '获取模型列表失败 (${response.statusCode})';
        });
      }
    } on TimeoutException {
      setState(() {
        _modelsError = '获取模型列表超时';
      });
    } catch (e) {
      setState(() {
        _modelsError = '获取模型列表出错: $e';
      });
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _callOllama() async {
    if (_messages.isEmpty) return;
    setState(() {
      _isSending = true;
    });

    List<_ChatMessage> sourceMessages;
    if (_memoryEnabled) {
      sourceMessages = List<_ChatMessage>.from(_messages);
    } else {
      final lastUser = _messages.lastWhere(
        (m) => m.role == 'user',
        orElse: () => _messages.last,
      );
      sourceMessages = [lastUser];
    }

    final apiMessages = sourceMessages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final assistantIndex = _messages.length;
    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', content: '', time: DateTime.now()));
    });
    _saveState();
    _scrollToBottom();

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/chat');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _modelName,
              'messages': apiMessages,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final body = response.body;
        final errorText =
            '请求失败 (${response.statusCode})${body.isNotEmpty ? '\n$body' : ''}';
        setState(() {
          _messages[assistantIndex] = _ChatMessage(
            role: 'assistant',
            content: errorText,
            time: DateTime.now(),
          );
        });
        _saveState();
        _scrollToBottom();
        return;
      }

      final data = jsonDecode(response.body);
      final content = data is Map && data['content'] is String ? data['content'] as String : '';
      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: content,
          time: DateTime.now(),
        );
      });
      _saveState();
      _scrollToBottom();
    } on TimeoutException {
      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: '请求超时，请检查 Ollama 服务是否运行',
          time: DateTime.now(),
        );
      });
      _saveState();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: '请求出错: $e',
          time: DateTime.now(),
        );
      });
      _saveState();
      _scrollToBottom();
    } finally {
      setState(() {
        _isSending = false;
      });
    }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                    setState(() {
                      _memoryEnabled = value;
                      _saveState();
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
                    _messages.clear();
                    _saveState();
                  });
                },
              ),
            ],
          ),
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
        title: const Text(
          'Ollama 聊天',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
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
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
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
