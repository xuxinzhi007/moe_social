import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;

import 'services/llm_endpoint_config.dart';

/// 悬浮窗内 [MediaQuery] 反映的是窗口自身尺寸，resize 必须用真实屏幕逻辑宽度。
double _logicalDisplayWidthPx() {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return 360;
  double maxW = 0;
  for (final v in views) {
    final w = v.physicalSize.width / v.devicePixelRatio;
    if (w > maxW) maxW = w;
  }
  return maxW > 0 ? maxW : 360;
}

/// 悬浮窗 AI 功能类型（必须顶层声明，不能写在 State 类里）
enum AssistType {
  reply,
  polish,
  translate,
}

// 配置管理类
class OverlayConfig {
  // 默认模型配置
  static const String defaultModel = 'qwen2.5:0.5b-instruct';
  
  // 获取模型配置
  static String getModel() {
    // 这里可以扩展为从配置文件或其他来源获取模型
    // 目前返回默认模型
    return defaultModel;
  }
}

// 必须是顶层函数
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  String _response = '';
  bool _isLoading = false;
  String? _clipboardContent;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    // 监听来自主应用的事件（例如关闭）
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'close') {
        FlutterOverlayWindow.closeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    final screenW = _logicalDisplayWidthPx();
    await _animationController.forward();
    // 读取剪贴板
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() {
      _clipboardContent = data?.text;
      _isExpanded = true;
    });
    // 调整窗口大小以显示面板
    await FlutterOverlayWindow.resizeOverlay(
      (screenW * 0.9).toInt(),
      500,
      true,
    );
  }

  Future<void> _collapse() async {
    await _animationController.reverse();
    setState(() {
      _isExpanded = false;
      _response = '';
    });
    await FlutterOverlayWindow.resizeOverlay(140, 140, false);
  }

  AssistType _currentAssistType = AssistType.reply;
  String _targetLanguage = 'English';

  Future<void> _generate() async {
    final text = _clipboardContent ?? '';
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final uri = await LlmEndpointConfig.chatUri();
      // 这里简单硬编码一个模型，或者应该从 SharedPrefs 读取默认模型
      // 由于 Overlay 是独立进程，可能无法直接访问主进程的 SharedPrefs (除非用 group)
      // 这里先尝试直接调用，假设后端配置正确
      
      String systemPrompt;
      String userPrompt;
      
      switch (_currentAssistType) {
        case AssistType.reply:
          systemPrompt = '你是一个输入法助手，请根据用户的输入生成回复，简短一点，自然流畅。';
          userPrompt = text;
          break;
        case AssistType.polish:
          systemPrompt = '你是一个文本润色助手，请优化用户输入的文本，使其更加流畅、自然、有文采。';
          userPrompt = '请润色以下文本：$text';
          break;
        case AssistType.translate:
          systemPrompt = '你是一个翻译助手，请将用户输入的文本翻译成目标语言，保持原意的同时使翻译自然流畅。';
          userPrompt = '请将以下文本翻译成$_targetLanguage：$text';
          break;
      }
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': OverlayConfig.getModel(), // 从配置中获取模型
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = '';
        if (data is Map && data['message'] != null) {
           content = data['message']['content'];
        } else if (data is Map && data['content'] != null) {
           content = data['content'];
        }
        setState(() {
          _response = content;
        });
      } else {
        setState(() => _response = "请求失败: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _response = "错误: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _paste() async {
    if (_response.isEmpty) return;
    
    // 1. 复制到剪贴板
    await Clipboard.setData(ClipboardData(text: _response));
    
    // 2. 调用 Native 方法执行粘贴
    // 由于我们没有直接绑定 MethodChannel 到 overlay，这里需要一点技巧
    // flutter_overlay_window 插件底层可能有通信机制，或者我们通过 Intent
    // 为了简单，我们先只是复制，用户手动粘贴
    // 进阶：需要在 overlay 的 engine 注册 method channel 来调用 AccessibilityService
    
    // 暂时先这样，用户点击后复制并关闭
    await _collapse();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _expand,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _opacityAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text("Moe AI 助手", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: _collapse,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 功能选择
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ChoiceChip(
                      label: const Text('生成回复'),
                      selected: _currentAssistType == AssistType.reply,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _currentAssistType = AssistType.reply;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF7F7FD5),
                      labelStyle: TextStyle(
                        color: _currentAssistType == AssistType.reply
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('润色文本'),
                      selected: _currentAssistType == AssistType.polish,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _currentAssistType = AssistType.polish;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF7F7FD5),
                      labelStyle: TextStyle(
                        color: _currentAssistType == AssistType.polish
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('翻译'),
                      selected: _currentAssistType == AssistType.translate,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _currentAssistType = AssistType.translate;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF7F7FD5),
                      labelStyle: TextStyle(
                        color: _currentAssistType == AssistType.translate
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 语言选择（仅翻译功能显示）
              if (_currentAssistType == AssistType.translate)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: _targetLanguage,
                    decoration: InputDecoration(
                      labelText: '目标语言',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      'English', '中文', 'Japanese', 'Korean', 'French', 'Spanish', 'German'
                    ].map((language) => DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _targetLanguage = value;
                        });
                      }
                    },
                  ),
                ),
              
              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "输入内容:",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _clipboardContent ?? "（剪贴板为空）",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_response.isNotEmpty) ...[
                        Text(
                          _currentAssistType == AssistType.reply
                              ? "AI 回复:"
                              : _currentAssistType == AssistType.polish
                                  ? "润色结果:"
                                  : "翻译结果:",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE1E5EB)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _response,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (_isLoading)
                        const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5))))
                      else
                        const Expanded(
                          child: Center(
                            child: Text(
                              "点击生成获取结果",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _generate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF7F7FD5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF7F7FD5),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "生成",
                                style: TextStyle(color: Color(0xFF7F7FD5)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _response.isEmpty ? null : _paste,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF7F7FD5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("复制并关闭"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
