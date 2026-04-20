import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';

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
  String? _modelsError;
  // bool _memoryEnabled = true; // Always true now
  bool _ollamaOnline = false; // Ollama 在线状态（通过模型列表判断）
  bool _wasManuallyStopped = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  int? _speakingIndex;
  double _ttsRate = 0.4;
  double _ttsPitch = 1.0;
  
  // 模型配置参数
  double _temperature = 0.7;
  double _topP = 0.9;
  int _maxTokens = 1024;
  double _repeatPenalty = 1.1;

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
    _initVoice();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _modelController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _promptController.dispose();
    if (_isListening) {
      _speech.stop();
    }
    _tts.stop();
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

  Future<void> _initVoice() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {},
        onError: (error) {},
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (_) {}
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(_ttsRate);
      await _tts.setPitch(_ttsPitch);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      });
      _tts.setErrorHandler((msg) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      });
    } catch (_) {}
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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    if (!_speechAvailable) {
      bool available = false;
      try {
        available = await _speech.initialize(
          onStatus: (status) {},
          onError: (error) {},
        );
      } catch (_) {
        available = false;
      }
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前设备不支持语音识别'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      if (mounted) {
        setState(() {
          _speechAvailable = true;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (!mounted) return;
        if (text.isEmpty) return;
        setState(() {
          _controller.text = text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
        if (result.finalResult) {
          _speech.stop();
          setState(() {
            _isListening = false;
          });
          _sendMessage();
        }
      },
      localeId: 'zh_CN',
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _loadModels() async {
    setState(() {
      _modelsError = null;
    });

    try {
      final uri = await LlmEndpointConfig.modelsUri();
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
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
      // no-op: _modelsError/_models 会触发需要的 UI 更新
    }
  }

  // 解析模型信息
  String _parseModelInfo(String modelName) {
    // 从模型名称中提取信息
    // 例如：llama3:8b-instruct -> 8B 参数，指令微调
    // 例如：qwen2.5:0.5b-instruct -> 0.5B 参数，指令微调
    
    List<String> parts = modelName.split(':');
    if (parts.length < 2) return '';
    
    String modelType = parts[1];
    
    // 提取模型大小
    RegExp sizeRegex = RegExp(r'(\d+\.?\d*)([bB])');
    Match? sizeMatch = sizeRegex.firstMatch(modelType);
    String size = '';
    if (sizeMatch != null) {
      size = '${sizeMatch.group(1)}${sizeMatch.group(2)?.toUpperCase()}';
    }
    
    // 提取模型类型
    String type = '';
    if (modelType.contains('instruct')) {
      type = '指令微调';
    } else if (modelType.contains('chat')) {
      type = '对话模型';
    } else if (modelType.contains('base')) {
      type = '基础模型';
    }
    
    List<String> infoParts = [];
    if (size.isNotEmpty) infoParts.add(size);
    if (type.isNotEmpty) infoParts.add(type);
    
    return infoParts.join(' · ');
  }

  // 打开模型选择对话框
  Future<void> _openModelSelector() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController searchController = TextEditingController();
        List<String> filteredModels = _models;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.width > 600 ? 0.7 : 0.9),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    // 头部
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        color: const Color(0xFFF5F7FA),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '选择模型',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    
                    // 搜索框
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: '搜索模型...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredModels = _models;
                            } else {
                              filteredModels = _models.where((model) => 
                                model.toLowerCase().contains(value.toLowerCase())
                              ).toList();
                            }
                          });
                        },
                      ),
                    ),
                    
                    // 模型列表
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final model = filteredModels[index];
                          final isSelected = model == _modelName;
                          
                          // 解析模型信息
                          final modelInfo = _parseModelInfo(model);
                          
                          return ListTile(
                            title: Text(
                              model,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF7F7FD5) : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              modelInfo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            leading: Radio(
                              value: model,
                              groupValue: _modelName,
                              onChanged: (value) {
                                Navigator.pop(context, model);
                              },
                              activeColor: const Color(0xFF7F7FD5),
                            ),
                            onTap: () {
                              Navigator.pop(context, model);
                            },
                            onLongPress: () {
                              _showDeleteModelDialog(context, model);
                            },
                            trailing: isSelected
                                ? IconButton(
                                    icon: const Icon(Icons.settings),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showModelConfigDialog();
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    
                    // 底部操作
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _loadModels();
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showDownloadModelDialog(context),
                            icon: const Icon(Icons.download),
                            label: const Text('下载模型'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7F7FD5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _modelName = result;
        _modelController.text = result;
      });
      _showModelChanged(result);
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
      _currentSession.messages.add(_ChatMessage(role: 'assistant', content: '正在生成...', time: DateTime.now()));
      _currentSession.updatedAt = DateTime.now();
    });
    _saveState();
    _scrollToBottom();

    try {
      final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();
      final uri = await LlmEndpointConfig.chatUri();
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
              'temperature': _temperature,
              'top_p': _topP,
              'max_tokens': _maxTokens,
              'repeat_penalty': _repeatPenalty,
              'stream': true,
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

      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      String content = '';
      double remainingRatio = 1.0;
      bool summarized = false;
      if (terminalMode) {
        final msg = (data is Map) ? data['message'] : null;
        if (msg is Map && msg['content'] is String) {
          content = msg['content'] as String;
        } else if (data is Map && data['error'] is String) {
          content = 'Ollama 错误: ${data['error']}';
        } else {
          content = '响应格式异常（直连 Ollama）';
        }
      } else {
        content = data is Map && data['content'] is String ? data['content'] as String : '';
        remainingRatio = data is Map && data['remaining_ratio'] is num
            ? (data['remaining_ratio'] as num).toDouble()
            : 1.0;
        summarized = data is Map && data['summarized'] == true;
      }
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

  Future<void> _playMessageTts(String text, int index) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (_isSpeaking && _speakingIndex == index) {
      try {
        await _tts.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _speakingIndex = null;
        });
      }
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _speakingIndex = index;
    });
    try {
      await _tts.setSpeechRate(_ttsRate);
      await _tts.setPitch(_ttsPitch);
      await _tts.speak(t);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _speakingIndex = null;
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
                      onTap: () {
                        Navigator.pop(context);
                        _openModelSelector();
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
                          '语音设置',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              '语速',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _ttsRate,
                                min: 0.2,
                                max: 1.0,
                                divisions: 8,
                                label: _ttsRate.toStringAsFixed(2),
                                onChanged: (v) {
                                  setModalState(() {
                                    _ttsRate = v;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text(
                              '音调',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _ttsPitch,
                                min: 0.5,
                                max: 1.8,
                                divisions: 13,
                                label: _ttsPitch.toStringAsFixed(2),
                                onChanged: (v) {
                                  setModalState(() {
                                    _ttsPitch = v;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '预设配置',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildPresetButton('创意模式', 0.9, 0.95, 2048, 1.0),
                                  _buildPresetButton('精确模式', 0.2, 0.7, 1024, 1.2),
                                  _buildPresetButton('平衡模式', 0.7, 0.9, 1536, 1.1),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '模型参数',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // 温度
                        Row(
                          children: [
                            const Text(
                              '温度',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _temperature,
                                min: 0.1,
                                max: 2.0,
                                divisions: 19,
                                label: _temperature.toStringAsFixed(1),
                                onChanged: (v) {
                                  setModalState(() {
                                    _temperature = v;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(
                              _temperature.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        
                        // Top P
                        Row(
                          children: [
                            const Text(
                              'Top P',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _topP,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                label: _topP.toStringAsFixed(1),
                                onChanged: (v) {
                                  setModalState(() {
                                    _topP = v;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(
                              _topP.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        
                        // Max Tokens
                        Row(
                          children: [
                            const Text(
                              '最大 token',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _maxTokens.toDouble(),
                                min: 256,
                                max: 4096,
                                divisions: 15,
                                label: _maxTokens.toString(),
                                onChanged: (v) {
                                  setModalState(() {
                                    _maxTokens = v.toInt();
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(
                              _maxTokens.toString(),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        
                        // Repeat Penalty
                        Row(
                          children: [
                            const Text(
                              '重复惩罚',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _repeatPenalty,
                                min: 0.8,
                                max: 2.0,
                                divisions: 12,
                                label: _repeatPenalty.toStringAsFixed(1),
                                onChanged: (v) {
                                  setModalState(() {
                                    _repeatPenalty = v;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                            Text(
                              _repeatPenalty.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
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

  void _showMessageActions(_ChatMessage message) {
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
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessage(message.content);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.format_quote_rounded, color: Colors.green),
                  ),
                  title: const Text('引用消息', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _quoteMessage(message);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replyToMessage(_ChatMessage message) {
    setState(() {
      _controller.text = "@AI " + message.content.substring(0, message.content.length > 50 ? 50 : message.content.length) + "...\n";
      _focusNode.requestFocus();
    });
  }

  void _quoteMessage(_ChatMessage message) {
    setState(() {
      _controller.text = "> ${message.content.substring(0, message.content.length > 100 ? 100 : message.content.length)}${message.content.length > 100 ? '...' : ''}\n\n";
      _focusNode.requestFocus();
    });
  }

  // 构建预设配置按钮
  Widget _buildPresetButton(String name, double temp, double topP, int maxTokens, double repeatPenalty) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _temperature = temp;
          _topP = topP;
          _maxTokens = maxTokens;
          _repeatPenalty = repeatPenalty;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF5F7FA),
        foregroundColor: const Color(0xFF7F7FD5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(name),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, int index) {
    if (message.role == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            message.content,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0E0E0),
                child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.black54),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.width > 600 ? 0.65 : 0.75),
              ),
              child: GestureDetector(
                onLongPress: () => _showMessageActions(message),
                onTap: () {
                  // 点击消息可以进行回复
                  _replyToMessage(message);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        message.content.isEmpty ? '...' : message.content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (!isUser && message.content.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  _isSpeaking && _speakingIndex == index
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: textColor.withOpacity(0.8),
                                ),
                                onPressed: () => _playMessageTts(message.content, index),
                              ),
                              Text(
                                _formatTime(message.time),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isUser)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatTime(message.time),
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF7F7FD5),
                child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
              ),
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
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening ? Colors.redAccent : const Color(0xFF7F7FD5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.redAccent : const Color(0xFF7F7FD5)).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          onTap: _models.isNotEmpty ? _openModelSelector : null,
          child: Column(
            children: [
              const Text(
                'Ollama 聊天',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_models.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _modelName,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: Colors.black54,
                    ),
                  ],
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
                    _buildMessageBubble(message, index),
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

  // 显示下载模型对话框
  Future<void> _showDownloadModelDialog(BuildContext context) async {
    TextEditingController modelController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '下载模型',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modelController,
                      decoration: InputDecoration(
                        hintText: '输入模型名称，例如：llama3:8b-instruct',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final model = modelController.text.trim();
                                  if (model.isEmpty) {
                                    setState(() {
                                      errorMessage = '请输入模型名称';
                                    });
                                    return;
                                  }

                                  setState(() {
                                    isLoading = true;
                                    errorMessage = null;
                                  });

                                  try {
                                    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/models/download');
                                    final response = await http.post(
                                      uri,
                                      headers: {
                                        'Content-Type': 'application/json',
                                        if (ApiService.token != null)
                                          'Authorization': 'Bearer ${ApiService.token}',
                                      },
                                      body: jsonEncode({'model': model}),
                                    ).timeout(const Duration(minutes: 5));

                                    if (response.statusCode == 200) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('模型下载成功')),
                                      );
                                      // 重新加载模型列表
                                      _loadModels();
                                    } else {
                                      final data = jsonDecode(response.body);
                                      setState(() {
                                        errorMessage = data['message'] ?? '下载失败';
                                      });
                                    }
                                  } catch (e) {
                                    setState(() {
                                      errorMessage = '下载出错: $e';
                                    });
                                  } finally {
                                    setState(() {
                                      isLoading = false;
                                    });
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('下载'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F7FD5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 显示删除模型对话框
  Future<void> _showDeleteModelDialog(BuildContext context, String model) async {
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '删除模型',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('确定要删除模型 "$model" 吗？'),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('取消'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setState(() {
                                    isLoading = true;
                                  });

                                  try {
                                    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/models/delete');
                                    final response = await http.post(
                                      uri,
                                      headers: {
                                        'Content-Type': 'application/json',
                                        if (ApiService.token != null)
                                          'Authorization': 'Bearer ${ApiService.token}',
                                      },
                                      body: jsonEncode({'model': model}),
                                    );

                                    if (response.statusCode == 200) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('模型删除成功')),
                                      );
                                      // 重新加载模型列表
                                      _loadModels();
                                    } else {
                                      final data = jsonDecode(response.body);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(data['message'] ?? '删除失败')),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('删除出错: $e')),
                                    );
                                  } finally {
                                    setState(() {
                                      isLoading = false;
                                    });
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('删除'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 显示模型配置对话框
  Future<void> _showModelConfigDialog() async {
    double temperature = _temperature;
    double topP = _topP;
    int maxTokens = _maxTokens;
    double repeatPenalty = _repeatPenalty;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '模型配置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 温度
                    Row(
                      children: [
                        const Text('温度:'),
                        const Spacer(),
                        Text(temperature.toStringAsFixed(2)),
                      ],
                    ),
                    Slider(
                      value: temperature,
                      min: 0.0,
                      max: 2.0,
                      step: 0.1,
                      onChanged: (value) {
                        setState(() {
                          temperature = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Top P
                    Row(
                      children: [
                        const Text('Top P:'),
                        const Spacer(),
                        Text(topP.toStringAsFixed(2)),
                      ],
                    ),
                    Slider(
                      value: topP,
                      min: 0.0,
                      max: 1.0,
                      step: 0.05,
                      onChanged: (value) {
                        setState(() {
                          topP = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Max Tokens
                    Row(
                      children: [
                        const Text('最大 tokens:'),
                        const Spacer(),
                        Text(maxTokens.toString()),
                      ],
                    ),
                    Slider(
                      value: maxTokens.toDouble(),
                      min: 128,
                      max: 4096,
                      step: 128,
                      onChanged: (value) {
                        setState(() {
                          maxTokens = value.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Repeat Penalty
                    Row(
                      children: [
                        const Text('重复惩罚:'),
                        const Spacer(),
                        Text(repeatPenalty.toStringAsFixed(2)),
                      ],
                    ),
                    Slider(
                      value: repeatPenalty,
                      min: 0.5,
                      max: 2.0,
                      step: 0.1,
                      onChanged: (value) {
                        setState(() {
                          repeatPenalty = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _temperature = temperature;
                              _topP = topP;
                              _maxTokens = maxTokens;
                              _repeatPenalty = repeatPenalty;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('模型配置已更新')),
                            );
                          },
                          child: const Text('保存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F7FD5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
