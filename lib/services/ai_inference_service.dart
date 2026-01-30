import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'enhanced_logger.dart';
import 'task_execution_engine.dart';

/// AI推理服务 - 负责与大模型API通信
class AIInferenceService {
  static final AIInferenceService _instance = AIInferenceService._internal();
  factory AIInferenceService() => _instance;
  AIInferenceService._internal();

  final _logger = EnhancedLogger();
  final _dio = Dio();

  /// 初始化服务
  Future<void> initialize() async {
    _logger.info('初始化AI推理服务', category: LogCategory.ai);

    // 配置HTTP客户端
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'MoeSocial-AutoGLM/1.0.0',
      },
    );

    // 添加请求拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.debug('AI推理请求: ${options.method} ${options.path}',
            category: LogCategory.ai,
            metadata: {'headers': options.headers});
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.debug('AI推理响应: ${response.statusCode}',
            category: LogCategory.ai,
            metadata: {'responseTime': '${DateTime.now().millisecondsSinceEpoch}'});
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.error('AI推理请求失败: ${error.message}',
            category: LogCategory.ai,
            metadata: {'error': error.toString()});
          handler.next(error);
        },
      ),
    );
  }

  /// 任务规划 - 将自然语言指令转换为执行步骤
  Future<TaskPlan?> planTask({
    required String userInstruction,
    required Uint8List? screenshot,
    Map<String, dynamic>? context,
  }) async {
    try {
      _logger.info('开始任务规划',
        category: LogCategory.ai,
        metadata: {'instruction': userInstruction, 'hasScreenshot': screenshot != null});

      final apiKey = await AppConfig.getApiKey();
      final apiUrl = await AppConfig.getApiUrl();
      // 获取模型名称（后续版本可能用到）
      // final modelName = await AppConfig.getModelName();

      if (apiKey.isEmpty) {
        throw Exception('API密钥未配置');
      }

      final requestData = await _buildPlanRequest(userInstruction, screenshot, context);

      final response = await _dio.post(
        apiUrl,
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        return _parsePlanResponse(response.data, userInstruction);
      } else {
        throw Exception('API调用失败: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('任务规划失败',
        category: LogCategory.ai,
        metadata: {'error': e.toString(), 'instruction': userInstruction});
      return _fallbackPlan(userInstruction);
    }
  }

  /// 构建规划请求
  Future<Map<String, dynamic>> _buildPlanRequest(
    String instruction,
    Uint8List? screenshot,
    Map<String, dynamic>? context
  ) async {
    final modelName = await AppConfig.getModelName();

    final systemPrompt = '''
你是AutoGLM智能助手，专门帮助用户自动化手机操作。请根据用户指令和当前界面截图，生成详细的执行计划。

支持的操作类型：
1. Launch(appName) - 启动应用
2. Tap(x, y) - 点击坐标
3. Type(text) - 输入文本
4. Swipe(startX, startY, endX, endY) - 滑动手势
5. Wait(seconds) - 等待
6. Back() - 返回键
7. Home() - 主页键
8. Analyze(description) - 分析界面

请返回JSON格式的执行计划，包含：
- steps: 执行步骤数组
- complexity: simple/moderate/complex
- estimatedTime: 预估时间(秒)
- riskFactors: 风险因素数组
- preconditions: 前置条件数组

示例格式：
{
  "steps": [
    {
      "type": "Launch",
      "params": {"appName": "微信"},
      "description": "启动微信应用",
      "expectedOutcomes": ["微信界面显示"]
    }
  ],
  "complexity": "simple",
  "estimatedTime": 10,
  "riskFactors": ["网络连接"],
  "preconditions": ["微信已安装"]
}
''';

    final messages = [
      {
        'role': 'system',
        'content': systemPrompt,
      },
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': '请帮我执行以下指令：$instruction'},
          if (screenshot != null)
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,${base64Encode(screenshot)}'
              }
            },
        ],
      },
    ];

    // 根据不同模型调整请求格式
    if (modelName.contains('ZhipuAI') || modelName.contains('AutoGLM')) {
      return {
        'model': modelName,
        'messages': messages,
        'temperature': 0.1,
        'max_tokens': 2000,
        'stream': false,
      };
    } else if (modelName.contains('OpenAI') || modelName.contains('GPT')) {
      return {
        'model': 'gpt-4-vision-preview',
        'messages': messages,
        'max_tokens': 2000,
        'temperature': 0.1,
      };
    } else {
      // 默认格式
      return {
        'model': modelName,
        'messages': messages,
        'temperature': 0.1,
        'max_tokens': 2000,
      };
    }
  }

  /// 解析规划响应
  TaskPlan? _parsePlanResponse(Map<String, dynamic> response, String instruction) {
    try {
      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content == null) return null;

      // 尝试提取JSON
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) return null;

      final planData = json.decode(jsonMatch.group(0)!);
      return TaskPlan.fromJson(planData, instruction);
    } catch (e) {
      _logger.warn('解析AI响应失败',
        category: LogCategory.ai,
        metadata: {'error': e.toString(), 'response': response.toString()});
      return null;
    }
  }

  /// 后备规划方案（当AI服务不可用时）
  TaskPlan _fallbackPlan(String instruction) {
    _logger.info('使用后备规划方案',
      category: LogCategory.ai,
      metadata: {'instruction': instruction});

    final lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('点赞') || lowerInstruction.contains('like')) {
      return TaskPlan(
        userInstruction: instruction,
        steps: [
          ExecutionStep(
            id: 'fallback_step_1',
            type: 'Analyze',
            params: {'target': '点赞按钮'},
            description: '分析界面查找点赞按钮',
            expectedOutcomes: ['找到点赞按钮'],
          ),
          ExecutionStep(
            id: 'fallback_step_2',
            type: 'Tap',
            params: {'description': '点赞按钮'},
            description: '点击点赞按钮',
            expectedOutcomes: ['点赞成功'],
          ),
        ],
        complexity: TaskComplexity.simple,
        estimatedTime: 5,
        riskFactors: ['界面变化'],
        preconditions: ['当前页面有点赞按钮'],
      );
    }

    if (lowerInstruction.contains('搜索')) {
      final searchQuery = _extractSearchQuery(instruction);
      return TaskPlan(
        userInstruction: instruction,
        steps: [
          ExecutionStep(
            id: 'fallback_search_1',
            type: 'Analyze',
            params: {'target': '搜索框'},
            description: '查找搜索框',
            expectedOutcomes: ['找到搜索框'],
          ),
          ExecutionStep(
            id: 'fallback_search_2',
            type: 'Tap',
            params: {'description': '搜索框'},
            description: '点击搜索框',
            expectedOutcomes: ['搜索框激活'],
          ),
          ExecutionStep(
            id: 'fallback_search_3',
            type: 'Type',
            params: {'text': searchQuery},
            description: '输入搜索内容',
            expectedOutcomes: ['文本输入完成'],
          ),
          ExecutionStep(
            id: 'fallback_search_4',
            type: 'Tap',
            params: {'description': '搜索按钮'},
            description: '点击搜索按钮',
            expectedOutcomes: ['开始搜索'],
          ),
        ],
        complexity: TaskComplexity.moderate,
        estimatedTime: 12,
        riskFactors: ['输入法切换', '网络延迟'],
        preconditions: ['应用已打开', '有搜索功能'],
      );
    }

    // 默认分析计划
    return TaskPlan(
      userInstruction: instruction,
      steps: [
        ExecutionStep(
          id: 'fallback_analyze_1',
          type: 'Analyze',
          params: {'target': '当前界面'},
          description: '分析当前界面状态',
          expectedOutcomes: ['界面分析完成'],
        ),
      ],
      complexity: TaskComplexity.simple,
      estimatedTime: 3,
      riskFactors: [],
      preconditions: [],
    );
  }

  /// 提取搜索关键词
  String _extractSearchQuery(String instruction) {
    // 匹配引号中的内容
    final quotedMatch = RegExp(r'["""]([^"""]+)["""]').firstMatch(instruction);
    if (quotedMatch != null) {
      return quotedMatch.group(1)!;
    }

    // 匹配"搜索"后的内容
    final searchMatch = RegExp(r'搜索\s*(.+?)(?:\s|$)').firstMatch(instruction);
    if (searchMatch != null) {
      return searchMatch.group(1)!.trim();
    }

    return 'Flutter'; // 默认搜索词
  }

  /// 界面理解 - 分析截图中的UI元素
  Future<UIAnalysis?> analyzeUI({
    required Uint8List screenshot,
    String? targetDescription,
  }) async {
    try {
      _logger.info('开始界面分析',
        category: LogCategory.ai,
        metadata: {'target': targetDescription, 'screenshotSize': screenshot.length});

      final apiKey = await AppConfig.getApiKey();
      final apiUrl = await AppConfig.getApiUrl();

      if (apiKey.isEmpty) {
        throw Exception('API密钥未配置');
      }

      final requestData = await _buildAnalysisRequest(screenshot, targetDescription);

      final response = await _dio.post(
        apiUrl,
        data: requestData,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      if (response.statusCode == 200) {
        return _parseAnalysisResponse(response.data);
      } else {
        throw Exception('API调用失败: ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('界面分析失败',
        category: LogCategory.ai,
        metadata: {'error': e.toString(), 'target': targetDescription});
      return null;
    }
  }

  /// 构建分析请求
  Future<Map<String, dynamic>> _buildAnalysisRequest(
    Uint8List screenshot,
    String? targetDescription,
  ) async {
    final modelName = await AppConfig.getModelName();

    final systemPrompt = '''
你是UI界面分析专家。请分析这张手机界面截图，识别其中的UI元素和布局。

请返回JSON格式，包含：
- elements: UI元素数组，每个元素包含 {type, text, bounds: {x, y, width, height}, description}
- layout: 界面布局描述
- primaryAction: 主要操作建议
- accessibility: 无障碍信息

focus: ${targetDescription ?? '分析所有可交互元素'}
''';

    return {
      'model': modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,${base64Encode(screenshot)}'
              }
            },
            {
              'type': 'text',
              'text': targetDescription ?? '请分析这个界面的所有可交互元素'
            },
          ],
        },
      ],
      'temperature': 0.1,
      'max_tokens': 1500,
    };
  }

  /// 解析分析响应
  UIAnalysis? _parseAnalysisResponse(Map<String, dynamic> response) {
    try {
      final content = response['choices']?[0]?['message']?['content'] as String?;
      if (content == null) return null;

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) return null;

      final analysisData = json.decode(jsonMatch.group(0)!);
      return UIAnalysis.fromJson(analysisData);
    } catch (e) {
      _logger.warn('解析UI分析响应失败',
        category: LogCategory.ai,
        metadata: {'error': e.toString()});
      return null;
    }
  }
}

/// 任务执行计划
class TaskPlan {
  final String userInstruction;
  final List<ExecutionStep> steps;
  final TaskComplexity complexity;
  final int estimatedTime;
  final List<String> riskFactors;
  final List<String> preconditions;

  TaskPlan({
    required this.userInstruction,
    required this.steps,
    required this.complexity,
    required this.estimatedTime,
    required this.riskFactors,
    required this.preconditions,
  });

  factory TaskPlan.fromJson(Map<String, dynamic> json, String instruction) {
    return TaskPlan(
      userInstruction: instruction,
      steps: (json['steps'] as List)
          .map((step) => ExecutionStep(
            id: 'ai_step_${DateTime.now().millisecondsSinceEpoch}_${step['type']}',
            type: step['type'],
            params: Map<String, dynamic>.from(step['params'] ?? {}),
            description: step['description'] ?? '',
            expectedOutcomes: List<String>.from(step['expectedOutcomes'] ?? []),
          ))
          .toList(),
      complexity: TaskComplexity.values.firstWhere(
        (c) => c.name == json['complexity'],
        orElse: () => TaskComplexity.moderate,
      ),
      estimatedTime: json['estimatedTime'] ?? 10,
      riskFactors: List<String>.from(json['riskFactors'] ?? []),
      preconditions: List<String>.from(json['preconditions'] ?? []),
    );
  }
}

/// UI分析结果
class UIAnalysis {
  final List<UIElement> elements;
  final String layout;
  final String primaryAction;
  final Map<String, dynamic> accessibility;

  UIAnalysis({
    required this.elements,
    required this.layout,
    required this.primaryAction,
    required this.accessibility,
  });

  factory UIAnalysis.fromJson(Map<String, dynamic> json) {
    return UIAnalysis(
      elements: (json['elements'] as List?)
          ?.map((e) => UIElement.fromJson(e))
          .toList() ?? [],
      layout: json['layout'] ?? '',
      primaryAction: json['primaryAction'] ?? '',
      accessibility: Map<String, dynamic>.from(json['accessibility'] ?? {}),
    );
  }
}

/// UI元素
class UIElement {
  final String type;
  final String text;
  final ElementBounds bounds;
  final String description;

  UIElement({
    required this.type,
    required this.text,
    required this.bounds,
    required this.description,
  });

  factory UIElement.fromJson(Map<String, dynamic> json) {
    return UIElement(
      type: json['type'] ?? '',
      text: json['text'] ?? '',
      bounds: ElementBounds.fromJson(json['bounds'] ?? {}),
      description: json['description'] ?? '',
    );
  }
}

/// 元素边界
class ElementBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  ElementBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ElementBounds.fromJson(Map<String, dynamic> json) {
    return ElementBounds(
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
    );
  }
}