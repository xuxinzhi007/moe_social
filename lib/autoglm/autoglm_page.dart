import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../widgets/fade_in_up.dart';
import '../widgets/moe_toast.dart';
import '../widgets/moe_loading.dart';
import '../providers/theme_provider.dart';
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
  final List<String> _presetCommands = [
    '给第一条动态点赞',
    '搜索"Flutter"',
    '发布一条动态说Hello',
    '打开设置页面',
    '返回桌面',
  ];
  
  // 历史消息记录
  List<Map<String, dynamic>> _history = [];
  int _stepCount = 0;
  final int _maxSteps = 20;

  // 配置信息
  final String _baseUrl = "https://api-inference.modelscope.cn/v1/chat/completions"; 
  final String _apiKey = "ms-fa33637f-6572-4170-82b1-95f458fe9e7b"; // 您的 Key
  final String _model = "ZhipuAI/AutoGLM-Phone-9B";

  // 动态生成 System Prompt（包含已安装应用列表）
  String _generateSystemPrompt(List<String> installedApps) {
    String appList = installedApps.isEmpty 
        ? "微信、QQ、抖音、小红书、淘宝、京东、设置等常用应用"
        : installedApps.join("、");
    
    return """
你是一个智能体分析专家，可以根据操作历史和当前状态图执行一系列操作来完成任务。
你必须严格按照要求输出以下格式：
<think>{think}</think>
<answer>{action}</answer>

其中：
- {think} 是对你为什么选择这个操作的简短推理说明。
- {action} 是本次执行的具体操作指令，必须严格遵循下方定义的指令格式。

操作指令及其作用如下：
- do(action="Launch", app="xxx")  
    Launch是启动目标app的操作，这比通过主屏幕导航更快。此操作完成后，您将自动收到结果状态的截图。
- do(action="Tap", element=[x,y])  
    Tap是点击操作，点击屏幕上的特定点。可用此操作点击按钮、选择项目、从主屏幕打开应用程序，或与任何可点击的用户界面元素进行交互。坐标系统从左上角 (0,0) 开始到右下角（999,999)结束。此操作完成后，您将自动收到结果状态的截图。
- do(action="Type", text="xxx")  
    Type是输入文本的操作。使用此操作前，请确保输入框已被聚焦（先点击它）。可用于输入中文、英文、数字等任何文本内容。此操作完成后，您将自动收到结果状态的截图。
- do(action="Swipe", start=[x1,y1], end=[x2,y2])  
    Swipe是滑动操作，通过从起始坐标拖动到结束坐标来执行滑动手势。可用于滚动内容、在屏幕之间导航、下拉通知栏以及项目栏或进行基于手势的导航。坐标系统从左上角 (0,0) 开始到右下角（999,999)结束。滑动持续时间会自动调整以实现自然的移动。此操作完成后，您将自动收到结果状态的截图。
- do(action="Back")  
    导航返回到上一个屏幕或关闭当前对话框。相当于按下 Android 的返回按钮。使用此操作可以从更深的屏幕返回、关闭弹出窗口或退出当前上下文。此操作完成后，您将自动收到结果状态的截图。
- do(action="Home") 
    Home是回到系统桌面的操作，相当于按下 Android 主屏幕按钮。使用此操作可退出当前应用并返回启动器，或从已知状态启动新任务。此操作完成后，您将自动收到结果状态的截图。
- do(action="Wait", duration="x seconds")  
    等待页面加载，x为需要等待多少秒。
- finish(message="xxx")  
    finish是结束任务的操作，表示准确完整完成任务，message是终止信息。 

必须遵循的规则：
1. **应用切换**：在执行任何操作前，先检查当前app是否是目标app，如果不是，先执行 Home 返回桌面，然后执行 Launch 启动目标应用。
2. **错误恢复**：如果连续3步操作后仍然在错误的页面或应用内，**立即执行 Home 返回桌面**，然后重新 Launch 目标应用。
3. **页面导航**：如果进入到了无关页面，先尝试执行 Back。如果执行Back后页面没有变化，请点击页面左上角的返回键进行返回，或者右上角的X号关闭。如果还是无效，执行 Home 返回桌面。
4. **页面加载**：如果页面未加载出内容，最多连续 Wait 2 次（每次2秒），如果还是空白，执行 Home 返回桌面重新开始。
5. **网络问题**：如果页面显示网络问题，点击重新加载按钮。如果没有重新加载按钮，执行 Home 返回桌面重新开始。
6. **内容查找**：如果当前页面找不到目标联系人、商品、店铺等信息，可以尝试 Swipe 滑动查找（最多滑动3次）。如果滑动3次后仍未找到，执行 Home 返回桌面。
7. **操作验证**：在执行下一步操作前请一定要检查上一步的操作是否生效。如果点击没生效，等待1秒后重试，如果还是不生效，执行 Home 返回桌面。
8. **任务完成**：在结束任务前请一定要仔细检查任务是否完整准确的完成。
9. **重要**：当你感到迷失、不确定当前位置、或连续失败时，**不要犹豫，立即使用 Home 返回桌面重新开始**。
10. **本设备上已安装的应用（只能启动这些应用）**：$appList
11. 坐标系统使用相对坐标：从(0,0)到(999,999)，其中(0,0)是屏幕左上角，(999,999)是屏幕右下角。

**【极其重要 - 必须忽略系统UI元素】**：
12. 屏幕顶部可能会显示一个**深灰色的系统状态条**，上面有齿轮图标⚙、"步骤 X/Y"或"系统自动化服务"等文字。**这是系统服务组件，不是广告弹窗！绝对不要点击它、不要尝试关闭它、不要与它交互。**完全忽略它的存在，直接操作它下方的实际应用界面。
13. 如果看到带有"运行中"、"空闲"、"停止任务"等文字的深色面板，这也是**系统服务面板**，不是广告。请忽略它，专注于执行用户的任务。
14. 任何深灰色、带有⚙图标、显示"AutoGLM"或"系统自动化"字样的浮层都是**系统工具**，不需要处理。
""";
  }

  @override
  void dispose() {
    AutoGLMService.setStopCallback(null); // 清除回调
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

    // 尝试更新悬浮窗日志 (仅在开关开启时)
    if (AutoGLMService.enableOverlay) {
      AutoGLMService.updateOverlayLog(log);
    }
  }

  bool _isStopping = false;

  void _stopTask() {
    setState(() {
      _isStopping = true;
    });
    _addLog("🛑 正在停止任务...");
    
    // 更新悬浮窗状态
    if (AutoGLMService.enableOverlay) {
      AutoGLMService.updateOverlayStatus("正在停止...", false);
    }
  }
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();

    // 监听原生日志
    AutoGLMService.onLogReceived.listen((log) {
      if (!mounted) return;
      // 添加到日志列表 (加上前缀以区分)
      _addLog("[Native] $log");
    }, onError: (e) {
      print("Log stream error: $e");
    });
    
    // 设置悬浮窗停止回调
    AutoGLMService.setStopCallback(() {
      if (_isProcessing && !_isStopping) {
        _stopTask();
      }
    });
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

    // 仅在开关开启时处理悬浮窗逻辑
    if (AutoGLMService.enableOverlay) {
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
           // 即使没有悬浮窗权限，如果用户想跑任务，理论上也可以跑，只是看不到悬浮窗
           // 但为了避免混淆，这里我们保持原逻辑，或者您可以选择继续
        }
      }

      // 显示悬浮窗
      if (hasOverlayPermission) {
        await AutoGLMService.showOverlay();
      }
    } else {
      _addLog("ℹ️ 悬浮窗开关已关闭，仅在应用内显示日志");
    }

    setState(() {
      _isProcessing = true;
      _isStopping = false;
      _history = []; // 清空历史
      _stepCount = 0;
    });
    
    // 获取已安装应用列表
    _addLog("📱 正在获取已安装应用列表...");
    Map<String, String> installedAppsMap = await AutoGLMService.getInstalledApps();
    List<String> installedAppNames = installedAppsMap.keys.toList();
    _addLog("✅ 找到 ${installedAppNames.length} 个已安装应用");
    
    // 生成包含已安装应用的系统Prompt
    String systemPrompt = _generateSystemPrompt(installedAppNames);
    
    // 初始化系统Prompt
    _history.add({
      "role": "system", 
      "content": systemPrompt
    });

    _addLog("🤖 开始任务: $task");

    // --- 输入策略：默认使用“备用输入方式”（最稳定）---
    // 仅当用户当前已经在用 ADB Keyboard 时，才会自动走 ADB 广播输入。
    // 这样可以彻底避免“输入法切换/恢复”在不同 ROM 上的不稳定问题。
    final bool useAdbKeyboard = await AutoGLMService.isAdbKeyboardSelected();
    if (useAdbKeyboard) {
      _addLog("⌨️ 当前为 ADB Keyboard，将使用 ADB 输入");
    } else {
      _addLog("⌨️ 当前不是 ADB Keyboard，将使用备用输入方式（推荐）");
    }

    // 更新悬浮窗状态为运行中
    if (AutoGLMService.enableOverlay) {
      AutoGLMService.updateOverlayStatus("任务执行中", true);
    }

    try {
      bool finished = false;
      while (!finished && _stepCount < _maxSteps) {
        if (_isStopping) {
          _addLog("🛑 任务已手动停止");
          if (AutoGLMService.enableOverlay) {
            AutoGLMService.updateOverlayStatus("已停止", false);
          }
          break;
        }

        _stepCount++;
        _addLog("🔄 步骤 $_stepCount 执行中...");
        
        // 更新悬浮窗进度
        if (AutoGLMService.enableOverlay) {
          AutoGLMService.updateOverlayProgress(_stepCount, _maxSteps);
        }

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

        if (_isStopping) {
          _addLog("🛑 任务已手动停止");
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
           // 增强的解析逻辑：尝试从混杂文本中提取 do(...) 或 finish(...)
           
           // 1. 优先匹配 finish（支持多种格式）
           final finishPatterns = [
             RegExp(r'finish\s*\(\s*message\s*=\s*"([^"]*)"\s*\)'),
             RegExp(r"finish\s*\(\s*message\s*=\s*'([^']*)'\s*\)"),
             RegExp(r'finish\s*\([^)]*\)'),
           ];
           
           for (var pattern in finishPatterns) {
             final match = pattern.firstMatch(content);
             if (match != null) {
               actionStr = match.group(0)!;
               break;
             }
           }
           
           // 2. 匹配 do(...)
           if (actionStr.isEmpty) {
             final doPatterns = [
               RegExp(r'do\s*\(\s*action\s*=\s*"([^"]*)"[^)]*\)'),
               RegExp(r'do\s*\([^)]+\)'),
             ];
             
             for (var pattern in doPatterns) {
               final match = pattern.firstMatch(content);
               if (match != null) {
                 actionStr = match.group(0)!;
                 break;
               }
             }
           }
           
           // 3. 兜底：检查是否包含关键动作词
           if (actionStr.isEmpty) {
             // 检查是否是任务完成的信号
             final lowerContent = content.toLowerCase();
             if (lowerContent.contains("finish") || 
                 content.contains("完成") || 
                 content.contains("已完成") ||
                 content.contains("任务完成") ||
                 lowerContent.contains("task completed") ||
                 lowerContent.contains("done")) {
               // AI 可能用自然语言表达完成
               actionStr = 'finish(message="任务完成")';
               _addLog("💡 检测到任务完成信号，自动生成 finish 指令");
             } else if (content.trim().startsWith("do") || content.trim().startsWith("finish")) {
               actionStr = content.trim();
             }
           }
           
           // 4. Wait 命令特殊处理
           if (actionStr.isEmpty && content.contains('Wait') && content.contains('second')) {
             final waitMatch = RegExp(r'Wait.*?(\d+)\s*second').firstMatch(content);
             if (waitMatch != null) {
               actionStr = 'do(action="Wait", duration="${waitMatch.group(1)} seconds")';
             }
           }
           
           // 如果提取到了指令，剩下的部分作为 think
           if (actionStr.isNotEmpty) {
             think = content.replaceFirst(actionStr, "").trim();
           } else {
             think = content;
           }
        }
        
        if (think.isNotEmpty) {
          _addLog("🤔 思考: $think");
        }
        
        if (actionStr.isEmpty) {
           _addLog("❌ 无法解析动作");
           _addLog("📄 原始内容: ${content.length > 200 ? content.substring(0, 200) + '...' : content}");
           // 跳过本次，继续下一步
           continue; 
        }

        _addLog("🎯 动作: $actionStr");

        // 执行动作
        bool shouldFinish = await _executeAction(actionStr);
        if (shouldFinish) {
          finished = true;
          _addLog("✅ 任务完成");
          if (AutoGLMService.enableOverlay) {
            AutoGLMService.updateOverlayStatus("✓ 完成", false);
          }
        }
      }
      
      if (_stepCount >= _maxSteps) {
        _addLog("⚠️ 达到最大步骤数，停止执行");
        if (AutoGLMService.enableOverlay) {
          AutoGLMService.updateOverlayStatus("达到上限", false);
        }
      }

    } catch (e) {
      _addLog("❌ 发生异常: $e");
      if (AutoGLMService.enableOverlay) {
        AutoGLMService.updateOverlayStatus("错误", false);
      }
    } finally {
      // ===== 任务结束处理（无论何种原因结束都会执行）=====
      _addLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      _addLog("⌨️ 【任务结束】完成（无需切换/恢复输入法）");

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isStopping = false;
        });
      }
      
      // 更新悬浮窗最终状态
      if (AutoGLMService.enableOverlay) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_isProcessing) {
          AutoGLMService.updateOverlayStatus("就绪", false);
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _callApi() async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
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

        // 设置较长的超时时间
        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));

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
          throw Exception("HTTP ${streamedResponse.statusCode}: $body");
        }
      } catch (e) {
        retryCount++;
        _addLog("⚠️ API请求失败 ($retryCount/$maxRetries): ${e.toString().split('\n').first}"); // 简化日志
        
        if (retryCount >= maxRetries) {
          _addLog("❌ API请求最终失败");
          return null;
        }
        
        _addLog("⏳ 等待 2秒后重试...");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
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
      
      if (actionType == "Type") {
        final textMatch = RegExp(r'text="(.*?)"', dotAll: true).firstMatch(actionStr);
        if (textMatch != null) {
          final text = textMatch.group(1)!;
          _addLog("⌨️ 输入文本: $text");
          await AutoGLMService.performType(text);
          _addLog("✅ 文本已输入");
        } else {
          _addLog("⚠️ Type指令缺少text参数");
        }
      } else if (actionType == "Launch") {
        final appMatch = RegExp(r'app="(.*?)"').firstMatch(actionStr);
        if (appMatch != null) {
          final appName = appMatch.group(1)!;
          _addLog("🚀 启动应用: $appName");
          bool success = await AutoGLMService.launchApp(appName);
          if (!success) {
            _addLog("⚠️ 应用启动失败或未找到: $appName");
          }
        }
      } else if (actionType == "Tap") {
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
        // 解析 duration="2 seconds"
        int seconds = 2;
        final durationMatch = RegExp(r'duration="(\d+)\s*seconds?"').firstMatch(actionStr);
        if (durationMatch != null) {
          seconds = int.tryParse(durationMatch.group(1)!) ?? 2;
        }
        _addLog("⏳ 等待 $seconds 秒...");
        await Future.delayed(Duration(seconds: seconds));
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.primaryColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AutoGLM 助手', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'copy') {
                final text = _logs.join("\n");
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  MoeToast.success(context, "日志已复制到剪贴板");
                }
              } else if (value == 'clear') {
                setState(() { _logs.clear(); });
                if (mounted) {
                  MoeToast.show(context, "日志已清空");
                }
              } else if (value == 'help') {
                _showHelpDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(value: 'copy', child: Text("复制日志")),
                const PopupMenuItem(value: 'clear', child: Text("清空日志")),
                const PopupMenuItem(value: 'help', child: Text("使用帮助")),
              ];
            }
          )
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: InkWell(
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
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isServiceEnabled ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isServiceEnabled ? Colors.green[200]! : Colors.orange[200]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isServiceEnabled ? Colors.green[100]! : Colors.orange[100]!,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isServiceEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _isServiceEnabled ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _isServiceEnabled 
                          ? "无障碍服务已连接"
                          : "服务未开启，点击去设置开启 'Moe Social 助手'",
                        style: TextStyle(
                          color: _isServiceEnabled ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!_isServiceEnabled)
                      const Icon(Icons.chevron_right, color: Colors.orange),
                  ],
                ),
              ),
            ),
          ),

          // 功能介绍卡片
          FadeInUp(
            delay: const Duration(milliseconds: 150),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF7F7FD5), size: 16),
                      const SizedBox(width: 8),
                      const Text('功能介绍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AutoGLM 助手可以帮助你自动执行各种任务，如打开应用、点击按钮、输入文本等。只需输入你的指令，AI 会自动分析并执行相应的操作。',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ),

          // 日志区域
          Expanded(
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(color: primaryColor.withOpacity(0.2)),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.history, color: Color(0xFF7F7FD5), size: 16),
                          SizedBox(width: 8),
                          Text('执行日志', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _logs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_note_outlined, color: Colors.grey[300], size: 36),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '暂无执行日志',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '输入指令开始执行任务',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  _logs[index], 
                                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 输入区域
          FadeInUp(
            delay: const Duration(milliseconds: 250),
            child: Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 预设指令
                    if (_presetCommands.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _presetCommands.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(_presetCommands[index]),
                                onPressed: _isProcessing
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        _controller.text = _presetCommands[index];
                                      },
                                backgroundColor: primaryColor.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: primaryColor.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    // 输入框和发送按钮
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.grey[200]!,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: '输入指令 (例如: 给第一条动态点赞)',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                suffixIcon: _controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _controller.clear();
                                        },
                                      )
                                    : null,
                              ),
                              enabled: !_isProcessing,
                              onSubmitted: _isProcessing ? null : (_) => _startTask(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          onPressed: _isProcessing
                              ? (_isStopping ? null : () {
                                  HapticFeedback.lightImpact();
                                  _stopTask();
                                })
                              : () {
                                  HapticFeedback.lightImpact();
                                  _startTask();
                                },
                          elevation: 4,
                          backgroundColor: _isProcessing ? Colors.red : primaryColor,
                          shape: const CircleBorder(),
                          child: _isProcessing
                              ? (_isStopping
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.stop_rounded, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 执行状态
                    if (_isProcessing)
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7F7FD5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isStopping ? "正在停止任务..." : "任务执行中...",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 显示帮助对话框
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('使用帮助', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AutoGLM 助手使用说明:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text('1. 确保已开启无障碍服务', style: TextStyle(fontSize: 14)),
              const Text('2. 输入你想要执行的任务指令', style: TextStyle(fontSize: 14)),
              const Text('3. 点击发送按钮开始执行', style: TextStyle(fontSize: 14)),
              const Text('4. 查看执行日志了解任务进展', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              const Text('示例指令:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('- 给第一条动态点赞', style: TextStyle(fontSize: 14)),
              const Text('- 搜索"Flutter"', style: TextStyle(fontSize: 14)),
              const Text('- 发布一条动态说Hello', style: TextStyle(fontSize: 14)),
              const Text('- 打开设置页面', style: TextStyle(fontSize: 14)),
              const Text('- 返回桌面', style: TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('我知道了', style: TextStyle(color: Color(0xFF7F7FD5))),
            ),
          ],
        );
      },
    );
  }
}
