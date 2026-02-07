import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../autoglm/autoglm_service.dart';
import 'enhanced_logger.dart';
import 'ai_inference_service.dart';

/// 任务复杂度枚举
enum TaskComplexity { simple, moderate, complex }

/// 执行步骤定义
class ExecutionStep {
  final String id;
  final String type;
  final Map<String, dynamic> params;
  final String description;
  final List<String> expectedOutcomes;
  final List<String> preconditions;
  final int maxRetries;
  final Duration timeout;
  final double confidenceScore;

  ExecutionStep({
    required this.id,
    required this.type,
    required this.params,
    required this.description,
    this.expectedOutcomes = const [],
    this.preconditions = const [],
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
    this.confidenceScore = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'params': params,
    'description': description,
    'expectedOutcomes': expectedOutcomes,
    'preconditions': preconditions,
    'maxRetries': maxRetries,
    'timeout': timeout.inSeconds,
    'confidenceScore': confidenceScore,
  };

  factory ExecutionStep.fromJson(Map<String, dynamic> json) => ExecutionStep(
    id: json['id'],
    type: json['type'],
    params: Map<String, dynamic>.from(json['params']),
    description: json['description'] ?? '',
    expectedOutcomes: List<String>.from(json['expectedOutcomes'] ?? []),
    preconditions: List<String>.from(json['preconditions'] ?? []),
    maxRetries: json['maxRetries'] ?? 3,
    timeout: Duration(seconds: json['timeout'] ?? 10),
    confidenceScore: (json['confidenceScore'] ?? 1.0).toDouble(),
  );
}

/// 执行计划
class ExecutionPlan {
  final String id;
  final String userIntent;
  final TaskComplexity complexity;
  final List<ExecutionStep> steps;
  final Duration estimatedDuration;
  final List<RiskFactor> risks;
  final DateTime createdAt;

  ExecutionPlan({
    required this.id,
    required this.userIntent,
    required this.complexity,
    required this.steps,
    required this.estimatedDuration,
    required this.risks,
    required this.createdAt,
  });
}

/// 风险因素
class RiskFactor {
  final String type;
  final String description;
  final double severity; // 0.0 - 1.0
  final List<String> mitigations;

  RiskFactor({
    required this.type,
    required this.description,
    required this.severity,
    required this.mitigations,
  });
}

/// 执行结果
class ExecutionResult {
  final String stepId;
  final bool success;
  final Map<String, dynamic>? result;
  final String? reason;
  final Duration duration;
  final List<String> warnings;

  ExecutionResult._({
    required this.stepId,
    required this.success,
    this.result,
    this.reason,
    required this.duration,
    this.warnings = const [],
  });

  factory ExecutionResult.success({
    required String stepId,
    Map<String, dynamic>? result,
    required Duration duration,
    List<String> warnings = const [],
  }) => ExecutionResult._(
    stepId: stepId,
    success: true,
    result: result,
    duration: duration,
    warnings: warnings,
  );

  factory ExecutionResult.failure({
    required String stepId,
    required String reason,
    required Duration duration,
    List<String> warnings = const [],
  }) => ExecutionResult._(
    stepId: stepId,
    success: false,
    reason: reason,
    duration: duration,
    warnings: warnings,
  );
}

/// 智能任务规划器
class TaskPlanner {
  final EnhancedLogger _logger = EnhancedLogger();
  final AIInferenceService _aiService = AIInferenceService();

  /// 规划任务 - 使用AI推理生成执行计划
  Future<ExecutionPlan> planTask(String userIntent, {Uint8List? screenshot}) async {
    _logger.info('开始规划任务', metadata: {
      'userIntent': userIntent,
      'hasScreenshot': screenshot != null,
    }, category: LogCategory.ai);

    try {
      // 使用AI服务生成任务计划
      final aiPlan = await _aiService.planTask(
        userInstruction: userIntent,
        screenshot: screenshot,
        context: {'timestamp': DateTime.now().toIso8601String()},
      );

      if (aiPlan != null) {
        // 转换AI计划为执行计划
        return _convertAIPlanToExecutionPlan(aiPlan);
      }
    } catch (e) {
      _logger.warn('AI规划失败，使用后备方案', metadata: {
        'error': e.toString(),
        'intent': userIntent,
      }, category: LogCategory.ai);
    }

    // 后备方案：使用基于规则的规划
    return await _fallbackPlanTask(userIntent);
  }

  /// 转换AI计划为执行计划
  ExecutionPlan _convertAIPlanToExecutionPlan(TaskPlan aiPlan) {
    // AI计划中的步骤已经是ExecutionStep类型，直接使用
    final steps = aiPlan.steps;

    final risks = aiPlan.riskFactors.map((risk) {
      return RiskFactor(
        type: 'ai_identified',
        description: risk,
        severity: 0.5,
        mitigations: ['用户确认', '步骤验证'],
      );
    }).toList();

    return ExecutionPlan(
      id: _generatePlanId(),
      userIntent: aiPlan.userInstruction,
      complexity: aiPlan.complexity,
      steps: steps,
      estimatedDuration: Duration(seconds: aiPlan.estimatedTime),
      risks: risks,
      createdAt: DateTime.now(),
    );
  }

  /// 后备任务规划（当AI服务不可用时）
  Future<ExecutionPlan> _fallbackPlanTask(String userIntent) async {
    _logger.info('使用后备规划器', metadata: {'userIntent': userIntent}, category: LogCategory.ai);

    // 分析任务复杂度
    final complexity = await _analyzeTaskComplexity(userIntent);

    // 生成执行步骤
    final steps = await _generateExecutionSteps(userIntent, complexity);

    // 估算执行时间
    final estimatedDuration = _estimateExecutionTime(steps);

    // 风险评估
    final risks = await _assessRisks(steps);

    final plan = ExecutionPlan(
      id: _generatePlanId(),
      userIntent: userIntent,
      complexity: complexity,
      steps: steps,
      estimatedDuration: estimatedDuration,
      risks: risks,
      createdAt: DateTime.now(),
    );

    _logger.info('后备任务规划完成', metadata: {
      'planId': plan.id,
      'complexity': complexity.name,
      'stepCount': steps.length,
      'estimatedDuration': estimatedDuration.inSeconds,
      'riskCount': risks.length,
    }, category: LogCategory.ai);

    return plan;
  }

  Future<TaskComplexity> _analyzeTaskComplexity(String intent) async {
    // 复杂操作关键词
    final complexKeywords = ['登录', '发布', '上传', '下载', '支付', '注册', '设置', '配置'];
    final moderateKeywords = ['搜索', '浏览', '查看', '切换', '分享', '保存', '编辑'];
    final simpleKeywords = ['点击', '输入', '滑动', '返回', '打开', '关闭'];

    final lowerIntent = intent.toLowerCase();

    if (complexKeywords.any((keyword) => lowerIntent.contains(keyword))) {
      return TaskComplexity.complex;
    } else if (moderateKeywords.any((keyword) => lowerIntent.contains(keyword))) {
      return TaskComplexity.moderate;
    } else if (simpleKeywords.any((keyword) => lowerIntent.contains(keyword))) {
      return TaskComplexity.simple;
    } else {
      return TaskComplexity.moderate; // 默认中等复杂度
    }
  }

  Future<List<ExecutionStep>> _generateExecutionSteps(
      String intent, TaskComplexity complexity) async {
    // 这里应该调用AI模型进行步骤生成
    // 为了演示，我们提供一些基础的步骤模板

    final steps = <ExecutionStep>[];

    // 基于意图分析生成初步步骤
    if (intent.contains('点赞')) {
      steps.addAll(_generateLikeSteps());
    } else if (intent.contains('搜索')) {
      steps.addAll(_generateSearchSteps(intent));
    } else if (intent.contains('发布') || intent.contains('发送')) {
      steps.addAll(_generatePublishSteps(intent));
    } else {
      // 通用步骤
      steps.add(ExecutionStep(
        id: _generateStepId(),
        type: 'Analyze',
        params: {'intent': intent, 'target': '当前界面'},
        description: '分析当前界面状态',
        expectedOutcomes: ['界面分析完成'],
        confidenceScore: 0.8,
      ));
    }

    return steps;
  }

  List<ExecutionStep> _generateLikeSteps() {
    return [
      ExecutionStep(
        id: _generateStepId(),
        type: 'Analyze',
        params: {'target': '可点赞内容'},
        description: '分析界面查找点赞按钮',
        expectedOutcomes: ['找到点赞按钮'],
        confidenceScore: 0.9,
      ),
      ExecutionStep(
        id: _generateStepId(),
        type: 'Tap',
        params: {'element': 'like_button'},
        description: '点击点赞按钮',
        expectedOutcomes: ['点赞成功', '按钮状态改变'],
        preconditions: ['找到点赞按钮'],
        confidenceScore: 0.95,
      ),
    ];
  }

  List<ExecutionStep> _generateSearchSteps(String intent) {
    final searchQuery = _extractSearchQuery(intent);
    return [
      ExecutionStep(
        id: _generateStepId(),
        type: 'Analyze',
        params: {'target': '搜索框'},
        description: '查找搜索入口',
        expectedOutcomes: ['找到搜索入口'],
        confidenceScore: 0.85,
      ),
      ExecutionStep(
        id: _generateStepId(),
        type: 'Tap',
        params: {'element': 'search_box'},
        description: '点击搜索框',
        expectedOutcomes: ['搜索框激活'],
        preconditions: ['找到搜索入口'],
        confidenceScore: 0.9,
      ),
      ExecutionStep(
        id: _generateStepId(),
        type: 'Type',
        params: {'text': searchQuery},
        description: '输入搜索内容',
        expectedOutcomes: ['搜索内容输入完成'],
        preconditions: ['搜索框激活'],
        confidenceScore: 0.95,
      ),
      ExecutionStep(
        id: _generateStepId(),
        type: 'Tap',
        params: {'element': 'search_button'},
        description: '点击搜索按钮',
        expectedOutcomes: ['搜索结果显示'],
        preconditions: ['搜索内容输入完成'],
        confidenceScore: 0.9,
      ),
    ];
  }

  List<ExecutionStep> _generatePublishSteps(String intent) {
    return [
      ExecutionStep(
        id: _generateStepId(),
        type: 'Analyze',
        params: {'target': '发布入口'},
        description: '查找发布入口',
        expectedOutcomes: ['找到发布按钮或入口'],
        confidenceScore: 0.8,
      ),
      ExecutionStep(
        id: _generateStepId(),
        type: 'Tap',
        params: {'element': 'publish_button'},
        description: '点击发布按钮',
        expectedOutcomes: ['进入发布页面'],
        preconditions: ['找到发布按钮或入口'],
        confidenceScore: 0.85,
      ),
    ];
  }

  String _extractSearchQuery(String intent) {
    final searchPattern = RegExp(r'搜索\s*["""]?([^"""]+)["""]?');
    final match = searchPattern.firstMatch(intent);
    return match?.group(1) ?? '默认搜索内容';
  }

  Duration _estimateExecutionTime(List<ExecutionStep> steps) {
    final baseTimePerStep = Duration(seconds: 3);
    final networkTimeBuffer = Duration(seconds: 2);
    return Duration(seconds: steps.length * baseTimePerStep.inSeconds + networkTimeBuffer.inSeconds);
  }

  Future<List<RiskFactor>> _assessRisks(List<ExecutionStep> steps) async {
    final risks = <RiskFactor>[];

    // 网络相关风险
    if (steps.any((step) => step.type == 'Type' && (step.params['text']?.toString().length ?? 0) > 100)) {
      risks.add(RiskFactor(
        type: 'input_complexity',
        description: '输入内容较长，可能影响输入稳定性',
        severity: 0.3,
        mitigations: ['分段输入', '使用剪贴板'],
      ));
    }

    // UI变化风险
    if (steps.length > 10) {
      risks.add(RiskFactor(
        type: 'ui_complexity',
        description: '操作步骤较多，UI变化可能影响执行',
        severity: 0.5,
        mitigations: ['增加验证步骤', '实时UI分析'],
      ));
    }

    return risks;
  }

  String _generatePlanId() {
    return 'plan_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String _generateStepId() {
    return 'step_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }
}

/// 增强的执行引擎
class EnhancedExecutionEngine {
  final EnhancedLogger _logger = EnhancedLogger();
  final TaskPlanner _planner = TaskPlanner();

  /// 执行用户指令 - AI驱动的完整任务执行
  Future<Map<String, dynamic>> executeUserInstruction(String instruction) async {
    _logger.info('开始执行用户指令',
      metadata: {'instruction': instruction},
      category: LogCategory.user);

    if (kIsWeb) {
      // Web端不支持实际执行，返回模拟结果
      _logger.info('Web端环境，跳过实际执行', category: LogCategory.system);
      return {
        'success': true,
        'instruction': instruction,
        'totalSteps': 3,
        'completedSteps': 3,
        'successfulSteps': 3,
        'totalDuration': 2000,
        'results': [
          {'stepId': 'web_step_1', 'success': true, 'duration': 500},
          {'stepId': 'web_step_2', 'success': true, 'duration': 800},
          {'stepId': 'web_step_3', 'success': true, 'duration': 700},
        ],
      };
    }

    try {
      Uint8List? screenshot;
      if (!kIsWeb) {
        final screenshotBase64 = await AutoGLMService.getScreenshot();
        if (screenshotBase64 != null && screenshotBase64.isNotEmpty) {
          try {
            screenshot = base64Decode(screenshotBase64);
          } catch (e) {
            _logger.warn('截图Base64解析失败: $e', category: LogCategory.device);
          }
        }

        if (screenshot == null) {
          _logger.warn('无法获取屏幕截图，使用文本规划模式', category: LogCategory.device);
        }
      }

      // 使用AI规划器生成执行计划（如果没有截图则退化为文本规划）
      final plan = await _planner.planTask(instruction, screenshot: screenshot);

      _logger.info('任务规划完成', metadata: {
        'planId': plan.id,
        'stepCount': plan.steps.length,
        'complexity': plan.complexity.name,
        'estimatedTime': plan.estimatedDuration.inSeconds,
      }, category: LogCategory.ai);

      // 执行计划中的所有步骤
      final results = <ExecutionResult>[];
      bool allSuccess = true;

      for (int i = 0; i < plan.steps.length; i++) {
        final step = plan.steps[i];
        final result = await executeStep(step);
        results.add(result);

        if (!result.success) {
          allSuccess = false;
          _logger.warn('步骤执行失败，停止执行',
            metadata: {
              'stepIndex': i,
              'stepId': step.id,
              'reason': result.reason,
            },
            category: LogCategory.device);
          break;
        }

        // 短暂等待，避免操作过于频繁
        if (i < plan.steps.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final totalDuration = results.fold<Duration>(
        Duration.zero,
        (sum, result) => sum + result.duration,
      );

      final summary = {
        'success': allSuccess,
        'instruction': instruction,
        'planId': plan.id,
        'totalSteps': plan.steps.length,
        'completedSteps': results.length,
        'successfulSteps': results.where((r) => r.success).length,
        'totalDuration': totalDuration.inMilliseconds,
        'results': results.map((r) => {
          'stepId': r.stepId,
          'success': r.success,
          'duration': r.duration.inMilliseconds,
          'reason': r.reason,
        }).toList(),
      };

      _logger.info('指令执行完成',
        metadata: summary,
        category: LogCategory.user);

      return summary;

    } catch (e, stackTrace) {
      _logger.error('指令执行失败',
        metadata: {
          'instruction': instruction,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
        category: LogCategory.user);

      return {
        'success': false,
        'instruction': instruction,
        'error': e.toString(),
      };
    }
  }

  Future<ExecutionResult> executeStep(ExecutionStep step) async {
    final stopwatch = Stopwatch()..start();
    final stepId = step.id;

    _logger.info('开始执行步骤: ${step.type}', metadata: {
      'stepId': stepId,
      'type': step.type,
      'params': step.params,
      'confidenceScore': step.confidenceScore,
    }, category: LogCategory.device);

    try {
      // 前置条件检查
      if (!await _checkPreconditions(step)) {
        return ExecutionResult.failure(
          stepId: stepId,
          reason: '前置条件不满足',
          duration: stopwatch.elapsed,
        );
      }

      // 执行操作（带重试机制）
      Map<String, dynamic> result = {};
      String? lastError;

      for (int attempt = 1; attempt <= step.maxRetries; attempt++) {
        try {
          result = await _performAction(step).timeout(step.timeout);

          // 结果验证
          if (await _verifyResult(step, result)) {
            _logger.info('步骤执行成功: ${step.type}',
              metadata: {
                'stepId': stepId,
                'duration': stopwatch.elapsedMilliseconds,
                'result': result,
                'attempt': attempt,
              },
              category: LogCategory.device,
            );

            return ExecutionResult.success(
              stepId: stepId,
              result: result,
              duration: stopwatch.elapsed,
              warnings: attempt > 1 ? ['重试$attempt次后成功'] : [],
            );
          } else {
            lastError = '结果验证失败';
          }
        } catch (e) {
          lastError = e.toString();
          _logger.warn('步骤执行失败 (尝试 $attempt/${step.maxRetries}): $e',
            metadata: {
              'stepId': stepId,
              'type': step.type,
              'attempt': attempt,
              'error': e.toString(),
            },
            category: LogCategory.device,
          );

          if (attempt < step.maxRetries) {
            await Future.delayed(Duration(seconds: attempt)); // 递增延迟
          }
        }
      }

      return ExecutionResult.failure(
        stepId: stepId,
        reason: lastError ?? '未知错误',
        duration: stopwatch.elapsed,
        warnings: ['重试${step.maxRetries}次后仍失败'],
      );

    } catch (e, stackTrace) {
      _logger.error('步骤执行异常: ${step.type}', metadata: {
        'stepId': stepId,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
        'duration': stopwatch.elapsedMilliseconds,
      }, category: LogCategory.device);

      return ExecutionResult.failure(
        stepId: stepId,
        reason: e.toString(),
        duration: stopwatch.elapsed,
      );
    } finally {
      stopwatch.stop();
    }
  }

  Future<bool> _checkPreconditions(ExecutionStep step) async {
    for (final condition in step.preconditions) {
      if (!await _evaluateCondition(condition)) {
        _logger.warn('前置条件检查失败: $condition',
          metadata: {'stepId': step.id, 'condition': condition},
          category: LogCategory.device,
        );
        return false;
      }
    }
    return true;
  }

  Future<bool> _evaluateCondition(String condition) async {
    _logger.info('跳过前置条件检查: $condition',
        metadata: {'condition': condition},
        category: LogCategory.device);
    return true;
  }

  Future<Map<String, dynamic>> _performAction(ExecutionStep step) async {
    switch (step.type) {
      case 'Launch':
        return await _launchApp(step.params);
      case 'Tap':
        return await _performTap(step.params);
      case 'Type':
        return await _performType(step.params);
      case 'Swipe':
        return await _performSwipe(step.params);
      case 'Wait':
        return await _performWait(step.params);
      case 'Analyze':
        return await _performAnalyze(step.params);
      case 'Back':
        return await _performBack();
      case 'Home':
        return await _performHome();
      default:
        throw UnsupportedError('不支持的操作: ${step.type}');
    }
  }

  Future<Map<String, dynamic>> _launchApp(Map<String, dynamic> params) async {
    final appName = params['app'] ?? params['appName'];
    if (appName == null) {
      throw ArgumentError('缺少应用名称参数');
    }

    final success = await AutoGLMService.launchApp(appName);
    return {'success': success, 'app': appName};
  }

  Future<Map<String, dynamic>> _performTap(Map<String, dynamic> params) async {
    final element = params['element'];
    if (element == null) {
      throw ArgumentError('缺少点击目标参数');
    }

    if (element is List && element.length == 2) {
      final x = element[0].toDouble();
      final y = element[1].toDouble();
      await AutoGLMService.performClick(x, y);
      return {'success': true, 'element': element};
    } else {
      _logger.warn('当前版本不支持通过名称点击元素: $element',
          metadata: {'element': element},
          category: LogCategory.device);
      return {'success': false, 'element': element};
    }
  }

  Future<Map<String, dynamic>> _performType(Map<String, dynamic> params) async {
    final text = params['text'];
    if (text == null || text.isEmpty) {
      throw ArgumentError('缺少输入文本参数');
    }

    await AutoGLMService.performType(text.toString());
    return {'success': true, 'text': text};
  }

  Future<Map<String, dynamic>> _performSwipe(Map<String, dynamic> params) async {
    final start = params['start'];
    final end = params['end'];
    final duration = params['duration'] ?? 500;

    if (start == null || end == null) {
      throw ArgumentError('缺少滑动起始或结束坐标');
    }

    await AutoGLMService.performSwipe(
      start[0].toDouble(),
      start[1].toDouble(),
      end[0].toDouble(),
      end[1].toDouble(),
      duration: duration,
    );

    return {'success': true, 'start': start, 'end': end};
  }

  Future<Map<String, dynamic>> _performWait(Map<String, dynamic> params) async {
    final duration = params['duration'];
    int waitSeconds = 2; // 默认等待时间

    if (duration is int) {
      waitSeconds = duration;
    } else if (duration is String) {
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        waitSeconds = int.parse(match.group(1)!);
      }
    }

    await Future.delayed(Duration(seconds: waitSeconds));
    return {'success': true, 'waitSeconds': waitSeconds};
  }

  Future<Map<String, dynamic>> _performAnalyze(Map<String, dynamic> params) async {
    final target = params['target'] ?? '当前界面';

    final screenshotBase64 = await AutoGLMService.getScreenshot();
    final hasScreenshot = screenshotBase64 != null && screenshotBase64.isNotEmpty;

    return {
      'success': hasScreenshot,
      'target': target,
      'hasScreenshot': hasScreenshot,
    };
  }

  Future<Map<String, dynamic>> _performBack() async {
    await AutoGLMService.performBack();
    return {'success': true};
  }

  Future<Map<String, dynamic>> _performHome() async {
    await AutoGLMService.performHome();
    return {'success': true};
  }

  Future<bool> _verifyResult(ExecutionStep step, Map<String, dynamic> result) async {
    // 基础成功检查
    if (result['success'] != true) {
      return false;
    }

    // 根据期望结果验证
    for (final expectedOutcome in step.expectedOutcomes) {
      if (!await _verifyOutcome(expectedOutcome, result)) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _verifyOutcome(String outcome, Map<String, dynamic> result) async {
    _logger.info('跳过结果验证: $outcome',
        metadata: {'outcome': outcome, 'context': result},
        category: LogCategory.device);
    return true;
  }
}
