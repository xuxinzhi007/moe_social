import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ai_chat_gateway_service.dart';
import '../../models/ai_agent.dart';
import '../../models/ai_chat_message.dart';
import '../../models/ai_provider_profile.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_chat_empty_state.dart';
import '../../widgets/ai/message_bubble.dart';
import '../../widgets/moe_loading.dart';

enum ContentType {
  text,
  image,
  video,
  code,
  article,
  story,
  poem,
}

class _ContentTypeMeta {
  const _ContentTypeMeta({
    required this.label,
    required this.icon,
    required this.hint,
    required this.emptyHint,
    required this.suggestions,
  });

  final String label;
  final IconData icon;
  final String hint;
  final String emptyHint;
  final List<String> suggestions;
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
  String _generationStatus = '';

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  static const _typeMeta = <ContentType, _ContentTypeMeta>{
    ContentType.text: _ContentTypeMeta(
      label: '文本',
      icon: Icons.notes_rounded,
      hint: '描述你想生成的文本…',
      emptyHint: '写一段简介、文案或说明，AI 会按你的要求扩写。',
      suggestions: ['写一段产品简介', '帮我润色这段话', '生成三条朋友圈文案'],
    ),
    ContentType.image: _ContentTypeMeta(
      label: '图像',
      icon: Icons.image_rounded,
      hint: '描述画面、风格与构图…',
      emptyHint: '用文字描绘画面，便于后续图像生成或分镜设计。',
      suggestions: ['赛博朋克城市夜景', '日系插画少女肖像', '极简扁平图标草图'],
    ),
    ContentType.video: _ContentTypeMeta(
      label: '视频',
      icon: Icons.movie_creation_outlined,
      hint: '描述镜头、节奏与旁白…',
      emptyHint: '从分镜脚本开始，让 AI 帮你搭好视频结构。',
      suggestions: ['30 秒产品宣传分镜', 'Vlog 开场旁白脚本', '教程类视频大纲'],
    ),
    ContentType.code: _ContentTypeMeta(
      label: '代码',
      icon: Icons.code_rounded,
      hint: '说明语言、功能与约束…',
      emptyHint: '说清楚技术栈和需求，生成可运行的代码片段。',
      suggestions: ['Flutter 列表分页示例', 'Go HTTP 中间件模板', 'SQL 查询优化建议'],
    ),
    ContentType.article: _ContentTypeMeta(
      label: '文章',
      icon: Icons.article_outlined,
      hint: '输入主题、受众与篇幅…',
      emptyHint: '给出主题与风格，生成结构清晰的长文。',
      suggestions: ['写一篇技术博客大纲', '科普文章三段式结构', '活动招募公众号稿'],
    ),
    ContentType.story: _ContentTypeMeta(
      label: '故事',
      icon: Icons.auto_stories_outlined,
      hint: '设定世界观与主角…',
      emptyHint: '从人设和冲突出发，展开一段有张力的叙事。',
      suggestions: ['奇幻冒险开篇', '悬疑短篇第一章', '治愈系日常小故事'],
    ),
    ContentType.poem: _ContentTypeMeta(
      label: '诗歌',
      icon: Icons.format_quote_rounded,
      hint: '说明意象、情绪与体裁…',
      emptyHint: '指定情绪与意象，生成有韵律感的诗句。',
      suggestions: ['写一首关于星空的现代诗', '古风四句送别诗', '轻快童趣短诗'],
    ),
  };

  bool get _isBackendProviderAgent =>
      widget.agent.providerProfileId == null ||
      widget.agent.providerProfileId == AiProviderProfile.builtinBackendId;

  String get _providerSourceLabel =>
      _isBackendProviderAgent ? '本机推理' : '我的 API';

  _ContentTypeMeta get _currentMeta => _typeMeta[_selectedContentType]!;

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
    HapticFeedback.lightImpact();

    setState(() {
      _isGenerating = true;
      _generationStatus = '正在生成内容…';
    });

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
      final content =
          await _callContentGenerationAPI(prompt, _selectedContentType);
      final aiMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: 'content_generation',
        role: 'assistant',
        content: content,
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _messages.add(aiMsg));
    } catch (e) {
      final errorMsg = AiChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: 'content_generation',
        role: 'assistant',
        content: '生成失败，请稍后重试。',
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _messages.add(errorMsg));
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generationStatus = '';
        });
        _scrollToBottom();
      }
    }
  }

  Future<String> _callContentGenerationAPI(
    String prompt,
    ContentType contentType,
  ) async {
    String systemPrompt;
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

    return AiChatGatewayService().sendChat(
      agent: widget.agent,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ],
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _selectedImage = image);
    }
  }

  Widget _buildTypeHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_currentMeta.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentMeta.label}创作',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentMeta.emptyHint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ContentType.values.map((type) {
            final meta = _typeMeta[type]!;
            final isSelected = _selectedContentType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedContentType = type;
                      _selectedImage = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isSelected ? AiBrandTokens.userBubbleGradient : null,
                      color: isSelected ? null : MoeTokens.pageBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          meta.icon,
                          size: 16,
                          color:
                              isSelected ? Colors.white : AiBrandTokens.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          meta.label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AiBrandTokens.titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && !_isGenerating) {
      return AiChatEmptyState(
        title: '开始你的${_currentMeta.label}创作',
        subtitle: _currentMeta.emptyHint,
        icon: _currentMeta.icon,
        suggestions: _currentMeta.suggestions,
        onSuggestionTap: (text) {
          setState(() => _controller.text = text);
          _focusNode.requestFocus();
        },
      );
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isGenerating && index == _messages.length) {
          return _buildTypingBubble();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
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
          if (_selectedContentType == ContentType.image &&
              _selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 100,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                    color: AiBrandTokens.primary,
                    onPressed: _pickImage,
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AiBrandTokens.chatBackground,
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
                      hintText: _currentMeta.hint,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                          gradient: AiBrandTokens.userBubbleGradient,
                        ),
                        child: const Center(
                          child: MoeSmallLoading(size: 22, color: Colors.white),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AiBrandTokens.userBubbleGradient,
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
          if (_isGenerating && _generationStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const MoeSmallLoading(size: 14),
                  const SizedBox(width: 8),
                  Text(
                    _generationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message) {
    final isUser = message.role == 'user';
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    var contentType = MessageContentType.text;
    String? language;
    if (message.content.startsWith('```')) {
      contentType = MessageContentType.code;
      final lines = message.content.split('\n');
      if (lines.isNotEmpty) {
        final firstLine = lines.first.trim();
        if (firstLine.length > 3) {
          language = firstLine.substring(3).trim();
        }
      }
    }

    return Column(
      key: ValueKey(message.id),
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AiMessageBubble(
          content: message.content,
          contentType: contentType,
          language: language,
          isUser: isUser,
          agentLabel: isUser ? null : widget.agent.name,
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
    );
  }

  Widget _buildTypingBubble() {
    return AiMessageBubble(
      content: '',
      contentType: MessageContentType.thinking,
      isUser: false,
      agentLabel: widget.agent.name,
    );
  }

  void _showAgentInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AiBrandTokens.heroGradient,
                  ),
                  child:
                      const Icon(Icons.smart_toy_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.agent.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$_providerSourceLabel · ${widget.agent.modelName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.agent.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                widget.agent.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AiBrandTokens.chatBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiBrandTokens.titleColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '内容生成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AiBrandTokens.titleColor,
              ),
            ),
            Text(
              '${widget.agent.name} · $_providerSourceLabel',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '智能体信息',
            onPressed: _showAgentInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeHero(),
          _buildContentTypeSelector(),
          Expanded(
            child: AiChatBackground(child: _buildMessageList()),
          ),
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
}
