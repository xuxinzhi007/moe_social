import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'autoglm_service.dart';

class AutoGLMPage extends StatefulWidget {
  const AutoGLMPage({super.key});

  @override
  State<AutoGLMPage> createState() => _AutoGLMPageState();
}

class _AutoGLMPageState extends State<AutoGLMPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isServiceEnabled = false;
  bool _isProcessing = false;
  
  // 历史消息记录
  List<Map<String, dynamic>> _history = [];
  int _stepCount = 0;
  final int _maxSteps = 20;

  // 配置信息
  final String _baseUrl = "https://api-inference.modelscope.cn/v1/chat/completions"; 
  final String _apiKey = "ms-fa33637f-6572-4170-82b1-95f458fe9e7b"; // 您的 Key
  final String _model = "ZhipuAI/AutoGLM-Phone-9B";

  static const String _systemPrompt = """
你是一个智能体分析专家，可以根据操作历史和当前状态图执行一系列操作来完成任务。
你必须严格按照要求输出以下格式：
<think>{think}</think>
<answer>{action}</answer>

其中：
- {think} 是对你为什么选择这个操作的简短推理说明。
- {action} 是本次执行的具体操作指令，必须严格遵循下方定义的指令格式。

操作指令及其作用如下：
- do(action="Tap", element=[x,y])  
    Tap是点击操作，点击屏幕上的特定点。坐标系统从左上角 (0,0) 开始到右下角（999,999)结束。
- do(action="Swipe", start=[x1,y1], end=[x2,y2])  
    Swipe是滑动操作。坐标系统从左上角 (0,0) 开始到右下角（999,999)结束。
- do(action="Back")  
    导航返回到上一个屏幕。
- do(action="Home") 
    Home是回到系统桌面的操作。
- do(action="Wait", duration="x seconds")  
    等待页面加载，x为需要等待多少秒。
- finish(message="xxx")  
    finish是结束任务的操作，表示准确完整完成任务，message是终止信息。 

必须遵循的规则：
1. 在执行任何操作前，先检查当前app是否是目标app，如果不是，先执行 Launch (暂不支持，请手动打开或使用Home/Back找到)。
2. 如果进入到了无关页面，先执行 Back。
3. 如果页面未加载出内容，最多连续 Wait 三次，否则执行 Back重新进入。
4. 坐标均为相对坐标 (0-1000)。
5. 每次只输出一个动作。
""";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    bool enabled = await AutoGLMService.checkServiceStatus();
    if (mounted) {
      setState(() {
        _isServiceEnabled = enabled;
      });
    }
  }

  void _addLog(String log) {
    if (!mounted) return;
    
    // 更新本地日志
    setState(() {
      _logs.add(log);
    });
    
    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // 尝试更新悬浮窗日志
    AutoGLMService.updateOverlayLog(log);
  }

  // 核心逻辑：执行任务
  Future<void> _startTask() async {
    if (!_isServiceEnabled) {
      _addLog("❌ 错误: 请先开启无障碍服务");
      _checkStatus();
      return;
    }
    
    String task = _controller.text;
    if (task.isEmpty) return;

    // 检查并请求悬浮窗权限
    bool hasOverlayPermission = await AutoGLMService.checkOverlayPermission();
    if (!hasOverlayPermission) {
      _addLog("⚠️ 需要悬浮窗权限，请授权...");
      await AutoGLMService.requestOverlayPermission();
      // 等待用户授权回来
      await Future.delayed(const Duration(seconds: 2));
      hasOverlayPermission = await AutoGLMService.checkOverlayPermission();
      if (!hasOverlayPermission) {
         _addLog("❌ 未获得悬浮窗权限，无法显示进度");
         // 可以选择继续执行但不显示悬浮窗，或者终止
      }
    }

    // 显示悬浮窗
    if (hasOverlayPermission) {
      await AutoGLMService.showOverlay();
    }

    setState(() {
      _isProcessing = true;
      _history = []; // 清空历史
      _stepCount = 0;
    });
    
    // 初始化系统Prompt
    _history.add({
      "role": "system", 
      "content": _systemPrompt
    });

    _addLog("🤖 开始任务: $task");

    try {
      bool finished = false;
      while (!finished && _stepCount < _maxSteps) {
        _stepCount++;
        _addLog("🔄 步骤 $_stepCount 执行中...");

        // 1. 获取截图
        // _addLog("📸 正在截图...");
        await Future.delayed(const Duration(milliseconds: 500)); // 等待界面稳定
        String? screenshot = await AutoGLMService.getScreenshot();
        
        if (screenshot == null) {
          _addLog("❌ 截图失败，任务终止");
          break;
        }

        // 2. 构造消息
        String textContent;
        if (_stepCount == 1) {
          textContent = "$task\n\nCurrent UI Screenshot";
        } else {
          textContent = "** Screen Info **\n\nCurrent UI Screenshot";
          // 移除上一轮图片以节省token (简单策略：只保留文本)
           if (_history.length > 2) { // system, user(img), assistant, user(img)...
             var lastUserMsg = _history[_history.length - 2];
             if (lastUserMsg['role'] == 'user' && lastUserMsg['content'] is List) {
                // 简化上一轮 User 消息，移除图片
                lastUserMsg['content'] = (lastUserMsg['content'] as List)
                    .where((item) => item['type'] == 'text')
                    .toList();
             }
           }
        }

        Map<String, dynamic> userMsg = {
          "role": "user",
          "content": [
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$screenshot"
              }
            },
            {
              "type": "text",
              "text": textContent
            }
          ]
        };
        _history.add(userMsg);

        // 3. 调用API
        _addLog("☁️ 请求大模型中...");
        final response = await _callApi();
        if (response == null) {
           _addLog("❌ API请求失败");
           break;
        }

        // 4. 解析与执行
        final content = response['content'];
        _history.add({
          "role": "assistant",
          "content": content
        });

        // 解析 <think> 和 <answer>
        String think = "";
        String actionStr = "";
        
        if (content.contains("<answer>")) {
           var parts = content.split("<answer>");
           think = parts[0].replaceAll("<think>", "").replaceAll("</think>", "").trim();
           actionStr = parts[1].replaceAll("</answer>", "").trim();
        } else {
          // 尝试直接匹配 do(...) 或 finish(...)
          actionStr = content;
        }
        
        if (think.isNotEmpty) {
          _addLog("🤔 思考: $think");
        }
        
        if (actionStr.isEmpty) {
           _addLog("❌ 无法解析动作: $content");
           break;
        }

        _addLog("🎯 动作: $actionStr");

        // 执行动作
        bool shouldFinish = await _executeAction(actionStr);
        if (shouldFinish) {
          finished = true;
          _addLog("✅ 任务完成");
        }
      }
      
      if (_stepCount >= _maxSteps) {
        _addLog("⚠️ 达到最大步骤数，停止执行");
      }

    } catch (e) {
      _addLog("❌ 发生异常: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      // 任务结束，稍后隐藏悬浮窗 (可选，这里先不隐藏以便用户查看最终状态)
      // await Future.delayed(Duration(seconds: 5));
      // AutoGLMService.removeOverlay();
    }
  }

  Future<Map<String, dynamic>?> _callApi() async {
    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll({
        "Content-Type": "application/json",
        "Authorization": "Bearer $_apiKey"
      });
      request.body = jsonEncode({
        "model": _model,
        "messages": _history,
        "max_tokens": 1024,
        "temperature": 0.1,
        "stream": true, // 开启流式响应
      });

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        String fullContent = "";
        String buffer = "";

        await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
          buffer += chunk;
          
          while (true) {
             // 处理 SSE 格式: data: {...}
             int newlineIndex = buffer.indexOf('\n');
             if (newlineIndex == -1) break;
             
             String line = buffer.substring(0, newlineIndex).trim();
             buffer = buffer.substring(newlineIndex + 1);
             
             if (line.startsWith("data: ")) {
               String jsonStr = line.substring(6);
               if (jsonStr == "[DONE]") break;
               
               try {
                 final data = jsonDecode(jsonStr);
                 final content = data['choices']?[0]['delta']?['content'];
                 if (content != null) {
                   fullContent += content;
                   // 可以在这里实时更新 UI，例如:
                   // _updateStreamingLog(fullContent); 
                 }
               } catch (e) {
                 // 忽略解析错误
               }
             }
          }
        }
        
        return {
          "role": "assistant", 
          "content": fullContent
        };
      } else {
        final body = await streamedResponse.stream.bytesToString();
        _addLog("❌ API Error: ${streamedResponse.statusCode} $body");
        return null;
      }
    } catch (e) {
      _addLog("❌ API Exception: $e");
      return null;
    }
  }

  Future<bool> _executeAction(String actionStr) async {
    // 简单解析器
    // do(action="Tap", element=[500, 500])
    // finish(message="done")
    
    try {
      if (actionStr.startsWith("finish")) {
        final msgMatch = RegExp(r'message="(.*?)"').firstMatch(actionStr);
        final msg = msgMatch?.group(1) ?? "Finished";
        _addLog("🏁 结束: $msg");
        return true;
      }

      if (!actionStr.startsWith("do")) {
         _addLog("⚠️ 未知指令格式，跳过");
         return false;
      }

      // 提取 action type
      final actionTypeMatch = RegExp(r'action="(.*?)"').firstMatch(actionStr);
      final actionType = actionTypeMatch?.group(1);
      
      // 辅助函数：相对坐标转绝对坐标
      // 现在的 AutoGLMAccessibilityService 已经能够直接接受 0-1000 的相对坐标
      // 并使用 DisplayMetrics 自动计算物理坐标，所以这里直接传递原始值
      
      if (actionType == "Tap") {
        final elementMatch = RegExp(r'element=\[(\d+),\s*(\d+)\]').firstMatch(actionStr);
        if (elementMatch != null) {
          final x = double.parse(elementMatch.group(1)!);
          final y = double.parse(elementMatch.group(2)!);
          await AutoGLMService.performClick(x, y);
        }
      } else if (actionType == "Swipe") {
        final startMatch = RegExp(r'start=\[(\d+),\s*(\d+)\]').firstMatch(actionStr);
        final endMatch = RegExp(r'end=\[(\d+),\s*(\d+)\]').firstMatch(actionStr);
        if (startMatch != null && endMatch != null) {
          final x1 = double.parse(startMatch.group(1)!);
          final y1 = double.parse(startMatch.group(2)!);
          final x2 = double.parse(endMatch.group(1)!);
          final y2 = double.parse(endMatch.group(2)!);
          await AutoGLMService.performSwipe(x1, y1, x2, y2);
        }
      } else if (actionType == "Back") {
        await AutoGLMService.performBack();
      } else if (actionType == "Home") {
        await AutoGLMService.performHome();
      } else if (actionType == "Wait") {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        _addLog("⚠️ 不支持的动作: $actionType");
      }

      // 动作执行后等待一会
      await Future.delayed(const Duration(seconds: 1));
      return false;

    } catch (e) {
      _addLog("❌ 执行指令失败: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoGLM 助手'),
      ),
      body: Column(
        children: [
          // 状态栏
          InkWell(
            onTap: () async {
              if (!_isServiceEnabled) {
                await AutoGLMService.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 1)); 
                _checkStatus();
              } else {
                _checkStatus();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              color: _isServiceEnabled ? Colors.green[50] : Colors.orange[50],
              child: Row(
                children: [
                  Icon(
                    _isServiceEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _isServiceEnabled ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isServiceEnabled 
                        ? "无障碍服务已连接" 
                        : "服务未开启，点击去设置开启 'Moe Social 助手'",
                      style: TextStyle(
                        color: _isServiceEnabled ? Colors.green[900] : Colors.orange[900],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                  if (!_isServiceEnabled)
                    const Icon(Icons.chevron_right, color: Colors.orange),
                ],
              ),
            ),
          ),
          
          // 日志区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _logs[index], 
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),

          // 输入区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '输入指令 (例如: 给第一条动态点赞)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      enabled: !_isProcessing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: _isProcessing ? null : _startTask,
                    elevation: 0,
                    backgroundColor: _isProcessing ? Colors.grey : Theme.of(context).primaryColor,
                    mini: true,
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
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
