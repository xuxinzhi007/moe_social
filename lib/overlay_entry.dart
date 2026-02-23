import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';
import 'services/llm_endpoint_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _isExpanded = false;
  String _response = '';
  bool _isLoading = false;
  String? _clipboardContent;

  @override
  void initState() {
    super.initState();
    // 监听来自主应用的事件（例如关闭）
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'close') {
        FlutterOverlayWindow.closeOverlay();
      }
    });
  }

  Future<void> _expand() async {
    // 读取剪贴板
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    setState(() {
      _clipboardContent = data?.text;
      _isExpanded = true;
    });
    // 调整窗口大小以显示面板
    await FlutterOverlayWindow.resizeOverlay(
      (MediaQuery.of(context).size.width * 0.9).toInt(),
      500,
      true,
    );
  }

  Future<void> _collapse() async {
    setState(() {
      _isExpanded = false;
      _response = '';
    });
    await FlutterOverlayWindow.resizeOverlay(150, 150, false);
  }

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
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen2.5:0.5b-instruct', // 暂时硬编码，后续优化
          'messages': [
            {'role': 'system', 'content': '你是一个输入法助手，请根据用户的输入生成回复，简短一点。'},
            {'role': 'user', 'content': text}
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
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _expand,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, color: Colors.pinkAccent, size: 40),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 16),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_rounded, color: Colors.pinkAccent),
                  const SizedBox(width: 8),
                  const Text("Moe AI 助手", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _collapse,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("检测到输入内容:", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _clipboardContent ?? "（剪贴板为空）",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_response.isNotEmpty) ...[
                      Text("AI 回复:", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(_response, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ] else if (_isLoading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else
                      const Expanded(child: Center(child: Text("点击生成获取回复"))),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _generate,
                      child: const Text("生成回复"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _response.isEmpty ? null : _paste,
                      child: const Text("复制并关闭"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
