import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/llm_endpoint_config.dart';
import '../../services/ai_db_service.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_message.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/moe_toast.dart';

enum ContentType {
  text,
  image,
  video,
  code,
  article,
  story,
  poem,
}

class ContentGenerationPage extends StatefulWidget {
  final AiAgent agent;

  const ContentGenerationPage({super.key, required this.agent});

  @override
  State<ContentGenerationPage> createState() => _ContentGenerationPageState();
}

class _ContentGenerationPageState extends State<ContentGenerationPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<AiChatMessage> _messages = [];
  ContentType _selectedContentType = ContentType.text;
  bool _isGenerating = false;
  double _generationProgress = 0.0;
  String _generationStatus = '';

  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  Future<void> _generateContent() async {
    if (_isGenerating) return;
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generationProgress = 0.0;
      _generationStatus = '正在生成内容...';
    });

    // 添加用户消息
    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: 'content_generation',
      role: 'user',
      content: prompt,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
    });
    _scrollToBottom();

    try {
      // 构建内容生成请求
      final content = await _callContentGenerationAPI(prompt, _selectedContentType);

      // 添加AI回复
      final aiMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: 'content_generation',
        role: 'assistant',
        content: content,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMsg);
      });
    } catch (e) {
      // 添加错误消息
      final errorMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: 'content_generation',
        role: 'assistant',
        content: '生成失败: $e',
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMsg);
      });
    } finally {
      setState(() {
        _isGenerating = false;
        _generationProgress = 0.0;
        _generationStatus = '';
      });
      _scrollToBottom();
    }
  }

  Future<String> _callContentGenerationAPI(String prompt, ContentType contentType) async {
    final uri = await LlmEndpointConfig.chatUri();
    ApiService.logDirectHttp('POST', uri);
    final token = ApiService.token;
    final headers = ApiService.mergeTunnelHeaders(uri, headers: {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    // 构建系统提示词
    String systemPrompt = '';
    switch (contentType) {
      case ContentType.text:
        systemPrompt = '你是一个专业的内容生成助手，能够根据用户的需求生成高质量的文本内容。';
        break;
      case ContentType.image:
        systemPrompt = '你是一个专业的图像描述助手，能够根据用户的需求生成详细的图像描述，以便用于图像生成。';
        break;
      case ContentType.video:
        systemPrompt = '你是一个专业的视频脚本助手，能够根据用户的需求生成详细的视频脚本。';
        break;
      case ContentType.code:
        systemPrompt = '你是一个专业的代码助手，能够根据用户的需求生成高质量的代码。';
        break;
      case ContentType.article:
        systemPrompt = '你是一个专业的文章撰写助手，能够根据用户的需求生成高质量的文章。';
        break;
      case ContentType.story:
        systemPrompt = '你是一个专业的故事创作助手，能够根据用户的需求生成引人入胜的故事。';
        break;
      case ContentType.poem:
        systemPrompt = '你是一个专业的诗歌创作助手，能够根据用户的需求生成优美的诗歌。';
        break;
    }

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'model': widget.agent.modelName,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      if (data is Map && data['content'] is String) {
        return data['content'] as String;
      } else {
        throw Exception('响应格式异常');
      }
    } else {
      throw Exception('请求失败 (${response.statusCode})');
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Widget _buildContentTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ContentType.values.map((type) {
            final isSelected = _selectedContentType == type;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedContentType = type;
                  _selectedImage = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7F7FD5) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getContentTypeLabel(type),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.text:
        return '文本';
      case ContentType.image:
        return '图像';
      case ContentType.video:
        return '视频';
      case ContentType.code:
        return '代码';
      case ContentType.article:
        return '文章';
      case ContentType.story:
        return '故事';
      case ContentType.poem:
        return '诗歌';
      default:
        return '文本';
    }
  }

  Widget _buildInputArea() {
    return Container(
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
      child: Column(
        children: [
          if (_selectedContentType == ContentType.image && _selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 100,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_selectedImage!.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_selectedContentType == ContentType.image)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton(
                    icon: const Icon(Icons.image_rounded),
                    color: Colors.grey.shade600,
                    onPressed: _pickImage,
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
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _getInputHint(),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _generateContent(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _isGenerating
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
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
                          onPressed: _generateContent,
                        ),
                      ),
              ),
            ],
          ),
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _generationProgress,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF7F7FD5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _generationStatus,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getInputHint() {
    switch (_selectedContentType) {
      case ContentType.text:
        return '输入文本生成需求...';
      case ContentType.image:
        return '输入图像描述...';
      case ContentType.video:
        return '输入视频脚本需求...';
      case ContentType.code:
        return '输入代码需求...';
      case ContentType.article:
        return '输入文章主题...';
      case ContentType.story:
        return '输入故事主题...';
      case ContentType.poem:
        return '输入诗歌主题...';
      default:
        return '输入内容需求...';
    }
  }

  Widget _buildMessageBubble(AiChatMessage message) {
    final isUser = message.role == 'user';
    final timeStr = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    // 检测内容类型
    MessageContentType contentType = MessageContentType.text;
    String? language;

    // 简单的内容类型检测逻辑
    if (message.content.startsWith('```')) {
      // 代码块
      contentType = MessageContentType.code;
      // 提取语言
      final lines = message.content.split('\n');
      if (lines.length > 1) {
        final firstLine = lines[0].trim();
        if (firstLine.length > 3) {
          language = firstLine.substring(3).trim();
        }
      }
    }

    return FadeInUp(
      key: ValueKey(message.id),
      duration: const Duration(milliseconds: 200),
      delay: const Duration(milliseconds: 50),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          AiMessageBubble(
            content: message.content,
            contentType: contentType,
            language: language,
            isUser: isUser,
            onContentExpanded: _scrollToBottom,
          ),
          Padding(
            padding: isUser
                ? const EdgeInsets.only(top: 4, right: 4)
                : const EdgeInsets.only(top: 4, left: 48),
            child: Text(
              timeStr,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '内容生成',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.agent.name,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '查看智能体信息',
            onPressed: () {
              // 显示智能体信息
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Theme.of(ctx).primaryColor.withOpacity(0.12),
                                  child: Icon(Icons.smart_toy_rounded, color: Theme.of(ctx).primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.agent.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                      if (widget.agent.description.isNotEmpty)
                                        Text(widget.agent.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      Text('模型：${widget.agent.modelName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                                    const Icon(Icons.subject_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    const Text('系统提示词', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                                  child: widget.agent.systemPrompt.isEmpty
                                      ? Text('未设置系统提示词', style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontStyle: FontStyle.italic))
                                      : SelectableText(
                                          widget.agent.systemPrompt,
                                          style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildContentTypeSelector(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isGenerating && index == _messages.length) {
                  return _buildTypingBubble();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          // flex:0 仅占内容高度；键盘收起时由 Expanded 占满余量。键盘弹出且余量不足时在此区域内滚动，避免底部溢出。
          Flexible(
            flex: 0,
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _buildInputArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return AiMessageBubble(
      content: 'AI is thinking...',
      contentType: MessageContentType.thinking,
      isUser: false,
    );
  }
}
