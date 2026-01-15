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
  static bool _savedStreamEnabled = true;
  static bool _savedDirectOllama = true; // 流式输出默认开启直连
  static String _savedOllamaDirectUrl = 'http://127.0.0.1:11434';

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
  bool _streamEnabled = true;
  bool _directOllama = true; // 流式输出默认开启直连（更稳定）
  String _ollamaDirectUrl = 'http://127.0.0.1:11434'; // Ollama 直连地址（可配置）
  bool _ollamaOnline = false; // Ollama 在线状态
  Timer? _statusCheckTimer; // 状态检测定时器

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
    _messages.addAll(_savedMessages);
    _memoryEnabled = _savedMemoryEnabled;
    _streamEnabled = _savedStreamEnabled;
    _directOllama = _savedDirectOllama;
    _ollamaDirectUrl = _savedOllamaDirectUrl;
    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _loadModels();
    _startOllamaStatusCheck();
  }
  
  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _controller.dispose();
    _modelController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 检查 Ollama 在线状态（通过获取模型列表）
  Future<void> _checkOllamaStatus() async {
    try {
      String url;
      if (_directOllama) {
        // 直连模式：直接访问 Ollama 的 /api/tags 接口
        final baseUrl = _ollamaDirectUrl.endsWith('/') 
            ? _ollamaDirectUrl.substring(0, _ollamaDirectUrl.length - 1)
            : _ollamaDirectUrl;
        url = '$baseUrl/api/tags';
      } else {
        // 后端模式：通过后端接口获取模型列表
        url = '${ApiService.baseUrl}/api/llm/models';
      }
      
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      
      setState(() {
        _ollamaOnline = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        _ollamaOnline = false;
      });
    }
  }
  
  // 启动状态检测定时器（每5秒检测一次）
  void _startOllamaStatusCheck() {
    _checkOllamaStatus(); // 立即检测一次
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkOllamaStatus();
    });
  }


  void _saveState() {
    _savedMessages = List<_ChatMessage>.from(_messages);
    _savedMemoryEnabled = _memoryEnabled;
    _savedStreamEnabled = _streamEnabled;
    _savedDirectOllama = _directOllama;
    _savedOllamaDirectUrl = _ollamaDirectUrl;
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

    // 流式输出默认使用直连（更稳定），非流式使用后端接口
    if (_streamEnabled) {
      // 流式输出优先使用直连，如果直连关闭则尝试后端流式接口
      if (_directOllama) {
        await _callOllamaDirect();
      } else {
        await _callOllamaStream();
      }
    } else {
      await _callOllama();
    }
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
            // 成功获取模型列表，更新在线状态
            _ollamaOnline = true;
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

  Future<void> _callOllamaStream() async {
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
        .where((m) => !_isLocalErrorAssistantMessage(m))
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final assistantIndex = _messages.length;
    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', content: '', time: DateTime.now()));
    });
    _saveState();
    _scrollToBottom();

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/chat/stream');
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _modelName,
        'messages': apiMessages,
      });

      final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
      
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        final errorText = '请求失败 (${streamedResponse.statusCode})${body.isNotEmpty ? '\n$body' : ''}';
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

      String accumulatedContent = '';
      String buffer = '';
      Timer? updateTimer;
      String pendingContent = '';
      
      // 使用定时器批量更新，避免频繁 setState
      void scheduleUpdate() {
        if (updateTimer?.isActive ?? false) return;
        updateTimer = Timer(const Duration(milliseconds: 50), () {
          if (pendingContent.isNotEmpty) {
            setState(() {
              _messages[assistantIndex] = _ChatMessage(
                role: 'assistant',
                content: accumulatedContent,
                time: DateTime.now(),
              );
            });
            _scrollToBottom();
            pendingContent = '';
          }
        });
      }
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          
          if (trimmed.startsWith('data: ')) {
            final jsonStr = trimmed.substring(6).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
            
            try {
              final data = jsonDecode(jsonStr);
              if (data is Map) {
                // 后端返回格式: {"delta": "文本内容", "done": false}
                if (data['delta'] is String) {
                  final delta = data['delta'] as String;
                  if (delta.isNotEmpty) {
                    accumulatedContent += delta;
                    pendingContent += delta;
                    scheduleUpdate(); // 触发定时更新
                  }
                }
                // 如果 done=true，流式结束
                if (data['done'] == true) {
                  updateTimer?.cancel();
                  // 立即更新最终内容
                  setState(() {
                    _messages[assistantIndex] = _ChatMessage(
                      role: 'assistant',
                      content: accumulatedContent,
                      time: DateTime.now(),
                    );
                  });
                  _scrollToBottom();
                  break;
                }
              }
            } catch (e) {
              // 忽略解析错误，继续处理下一行
            }
          }
        }
      }
      
      updateTimer?.cancel();
      // 确保最终内容被更新
      if (accumulatedContent.isNotEmpty) {
        setState(() {
          _messages[assistantIndex] = _ChatMessage(
            role: 'assistant',
            content: accumulatedContent,
            time: DateTime.now(),
          );
        });
        _scrollToBottom();
      }

      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: accumulatedContent.isEmpty ? '无响应内容' : accumulatedContent,
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
      // 后端流式失败，尝试回退到直连流式
      print('后端流式接口失败: $e，尝试直连');
      setState(() {
        _messages.removeAt(assistantIndex);
      });
      // 如果直连未开启，尝试直连
      if (!_directOllama) {
        _directOllama = true;
        await _callOllamaDirect();
      } else {
        // 如果直连也失败，回退到非流式
        await _callOllama();
      }
      return;
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // 前端直接连接 Ollama（需要 Ollama 配置 CORS 或使用代理）
  Future<void> _callOllamaDirect() async {
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
        .where((m) => !_isLocalErrorAssistantMessage(m))
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final assistantIndex = _messages.length;
    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', content: '', time: DateTime.now()));
    });
    _saveState();
    _scrollToBottom();

    try {
      // 直接连接 Ollama（地址可配置，支持本地和远程）
      // 注意：远程使用时需要 Ollama 配置 CORS 或使用代理
      final ollamaBaseUrl = _ollamaDirectUrl.endsWith('/') 
          ? _ollamaDirectUrl.substring(0, _ollamaDirectUrl.length - 1)
          : _ollamaDirectUrl;
      final ollamaUrl = '$ollamaBaseUrl/api/chat';
      final request = http.Request('POST', Uri.parse(ollamaUrl));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _modelName,
        'messages': apiMessages,
        'stream': true,
      });

      final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
      
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        final errorText = '请求失败 (${streamedResponse.statusCode})${body.isNotEmpty ? '\n$body' : ''}';
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

      String accumulatedContent = '';
      String buffer = '';
      Timer? updateTimer;
      String pendingContent = '';
      
      // 使用定时器批量更新，避免频繁 setState
      void scheduleUpdate() {
        if (updateTimer?.isActive ?? false) return;
        updateTimer = Timer(const Duration(milliseconds: 50), () {
          if (pendingContent.isNotEmpty) {
            setState(() {
              _messages[assistantIndex] = _ChatMessage(
                role: 'assistant',
                content: accumulatedContent,
                time: DateTime.now(),
              );
            });
            _scrollToBottom();
            pendingContent = '';
          }
        });
      }
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          
          try {
            final data = jsonDecode(trimmed);
            if (data is Map) {
              // Ollama 流式格式: {"message": {"role": "assistant", "content": "..."}, "done": false}
              if (data['message'] is Map) {
                final message = data['message'] as Map;
                if (message['content'] is String) {
                  final content = message['content'] as String;
                  if (content.isNotEmpty) {
                    accumulatedContent += content;
                    pendingContent += content;
                    scheduleUpdate(); // 触发定时更新
                  }
                }
              }
              if (data['done'] == true) {
                updateTimer?.cancel();
                // 立即更新最终内容
                setState(() {
                  _messages[assistantIndex] = _ChatMessage(
                    role: 'assistant',
                    content: accumulatedContent,
                    time: DateTime.now(),
                  );
                });
                _scrollToBottom();
                break;
              }
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
      
      updateTimer?.cancel();
      // 确保最终内容被更新
      if (accumulatedContent.isNotEmpty) {
        setState(() {
          _messages[assistantIndex] = _ChatMessage(
            role: 'assistant',
            content: accumulatedContent,
            time: DateTime.now(),
          );
        });
        _scrollToBottom();
      }

      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: accumulatedContent.isEmpty ? '无响应内容' : accumulatedContent,
          time: DateTime.now(),
        );
      });
      _saveState();
      _scrollToBottom();
    } catch (e) {
      // 直连失败，回退到后端接口
      setState(() {
        _messages.removeAt(assistantIndex);
      });
      if (_streamEnabled) {
        await _callOllamaStream();
      } else {
        await _callOllama();
      }
      return;
    } finally {
      setState(() {
        _isSending = false;
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
        // 过滤掉本地生成的“错误气泡”，避免把错误文本当作对话上下文发给模型
        .where((m) => !_isLocalErrorAssistantMessage(m))
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
          // LLM 生成首包可能较慢（尤其是首次加载模型时），这里给更宽裕的超时
          .timeout(const Duration(seconds: 180));

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

  void _showOllamaUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: _ollamaDirectUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置 Ollama 直连地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入 Ollama 服务器地址：'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:11434',
                labelText: 'Ollama 地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '示例：\n• 本地: http://127.0.0.1:11434\n• 远程: http://192.168.1.100:11434\n• 域名: http://ollama.example.com:11434',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  _ollamaDirectUrl = url;
                  _saveState();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ollama 地址已更新: $url')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
                leading: const Icon(Icons.auto_awesome),
                title: const Text('流式输出'),
                subtitle: const Text('开启后可以看到模型逐字生成回复（默认使用直连）'),
                trailing: Switch(
                  value: _streamEnabled,
                  onChanged: (value) {
                    setModalState(() {
                      setState(() {
                        _streamEnabled = value;
                        // 开启流式输出时，默认开启直连（更稳定）
                        if (value && !_directOllama) {
                          _directOllama = true;
                        }
                        _saveState();
                      });
                    });
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('直接连接 Ollama'),
                subtitle: Text('流式输出时推荐开启\n当前地址: $_ollamaDirectUrl'),
                trailing: Switch(
                  value: _directOllama,
                  onChanged: (value) {
                    setModalState(() {
                      setState(() {
                        _directOllama = value;
                        _saveState();
                        // 切换模式后立即检测状态
                        _checkOllamaStatus();
                      });
                    });
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Ollama 直连地址'),
                subtitle: const Text('点击修改 Ollama 服务器地址'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  _showOllamaUrlDialog(context);
                },
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
            // Ollama 在线状态指示器（绿点）
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
