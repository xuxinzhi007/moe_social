# AutoGLM系统优化方案

## 📋 项目概述

AutoGLM是一个AI驱动的移动端自动化系统，采用Flutter前端 + Kotlin原生服务 + 大模型API的三层架构。本文档详细描述了系统的优化方案，旨在提升执行效率、用户体验和系统稳定性。

## 🎯 优化目标

### 性能指标
- 执行效率提升 40%
- 内存占用减少 30%
- 任务成功率从 70% 提升至 85%+
- API调用失败率降低 50%

### 用户体验
- 日志系统结构化，支持搜索和过滤
- 配置管理用户化，无需修改代码
- 错误诊断自动化，快速定位问题
- 操作确认机制，避免误操作

## 📊 当前系统分析

### 优点
- ✅ 架构清晰（Flutter + Native + API）
- ✅ 容错机制完善（多层降级）
- ✅ UI/UX设计用心（系统风格悬浮窗）
- ✅ 动作指令定义明确
- ✅ 相对坐标系统通用性强

### 主要问题
- ❌ API密钥硬编码，安全风险
- ❌ 日志系统简陋，难以调试
- ❌ 无任务持久化，崩溃后丢失状态
- ❌ 缺乏性能监控和异常检测
- ❌ AI推理上下文管理不足

## 🏗️ 优化架构设计

### 新架构图
```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter前端层                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │   UI组件    │ │   配置管理   │ │   日志系统   │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │  任务规划器  │ │  执行引擎    │ │  性能监控    │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
└──────────────────┬──────────────────────────────────────────┘
                   │ MethodChannel / EventChannel
┌──────────────────▼──────────────────────────────────────────┐
│              Android原生服务层                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │ 无障碍服务   │ │  屏幕管理    │ │  输入管理    │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │  悬浮窗UI   │ │  缓存管理    │ │  安全控制    │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
└──────────────────┬──────────────────────────────────────────┘
                   │ HTTP + Streaming + 缓存
┌──────────────────▼──────────────────────────────────────────┐
│              AI推理服务层                                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │  意图理解    │ │  任务规划    │ │  动作生成    │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │ 上下文管理   │ │  风险评估    │ │  结果验证    │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ 具体优化方案

### 1. 配置管理系统

#### 1.1 安全配置存储
```dart
class AppConfig {
  static final _secureStorage = FlutterSecureStorage();

  // API配置
  static Future<String> getApiUrl() async {
    return await _secureStorage.read(key: 'api_url') ??
           'https://api-inference.modelscope.cn/v1/chat/completions';
  }

  static Future<String> getApiKey() async {
    return await _secureStorage.read(key: 'api_key') ?? '';
  }

  static Future<String> getModelName() async {
    return await _secureStorage.read(key: 'model_name') ??
           'ZhipuAI/AutoGLM-Phone-9B';
  }

  // 任务配置
  static Future<int> getMaxSteps() async {
    final value = await _secureStorage.read(key: 'max_steps');
    return value != null ? int.parse(value) : 20;
  }

  static Future<Duration> getStepTimeout() async {
    final value = await _secureStorage.read(key: 'step_timeout');
    return value != null ? Duration(seconds: int.parse(value)) : Duration(seconds: 30);
  }
}
```

#### 1.2 配置UI界面
```dart
class ConfigPage extends StatefulWidget {
  @override
  _ConfigPageState createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _maxStepsController = TextEditingController();
  final _stepTimeoutController = TextEditingController();

  bool _isLoading = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    _apiUrlController.text = await AppConfig.getApiUrl();
    _apiKeyController.text = await AppConfig.getApiKey();
    _modelNameController.text = await AppConfig.getModelName();
    _maxStepsController.text = (await AppConfig.getMaxSteps()).toString();
    _stepTimeoutController.text = (await AppConfig.getStepTimeout()).inSeconds.toString();

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AutoGLM 配置'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildSectionTitle('API 配置'),
                _buildApiUrlField(),
                SizedBox(height: 16),
                _buildApiKeyField(),
                SizedBox(height: 16),
                _buildModelNameField(),

                SizedBox(height: 32),
                _buildSectionTitle('任务配置'),
                _buildMaxStepsField(),
                SizedBox(height: 16),
                _buildStepTimeoutField(),

                SizedBox(height: 32),
                _buildSectionTitle('系统配置'),
                _buildSystemSettings(),

                SizedBox(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testConnection,
                        child: Text('测试连接'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveConfig,
                        child: Text('保存配置'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF7F7FD5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7F7FD5),
        ),
      ),
    );
  }

  Widget _buildApiUrlField() {
    return TextFormField(
      controller: _apiUrlController,
      decoration: InputDecoration(
        labelText: 'API 地址',
        hintText: '请输入 API 服务地址',
        prefixIcon: Icon(Icons.cloud),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入API地址';
        }
        if (!Uri.tryParse(value)?.hasAbsolutePath == true) {
          return '请输入有效的URL';
        }
        return null;
      },
    );
  }

  Widget _buildApiKeyField() {
    return TextFormField(
      controller: _apiKeyController,
      obscureText: _obscureApiKey,
      decoration: InputDecoration(
        labelText: 'API 密钥',
        hintText: '请输入 API 密钥',
        prefixIcon: Icon(Icons.key),
        suffixIcon: IconButton(
          icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入API密钥';
        }
        if (value.length < 20) {
          return 'API密钥格式不正确';
        }
        return null;
      },
    );
  }
}
```

### 2. 日志系统重构

#### 2.1 结构化日志模型
```dart
enum LogLevel { debug, info, warn, error, critical }
enum LogCategory { system, ai, user, device, network, security, performance }

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic> metadata;
  final String? traceId;
  final String? userId;
  final Duration? duration;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata = const {},
    this.traceId,
    this.userId,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'category': category.name,
    'message': message,
    'metadata': metadata,
    'traceId': traceId,
    'userId': userId,
    'duration': duration?.inMilliseconds,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.byName(json['level']),
    category: LogCategory.values.byName(json['category']),
    message: json['message'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    traceId: json['traceId'],
    userId: json['userId'],
    duration: json['duration'] != null ? Duration(milliseconds: json['duration']) : null,
  );
}
```

#### 2.2 增强的日志管理器
```dart
class EnhancedLogger {
  static final _instance = EnhancedLogger._internal();
  factory EnhancedLogger() => _instance;
  EnhancedLogger._internal();

  final StreamController<LogEntry> _logStream = StreamController.broadcast();
  final List<LogEntry> _logBuffer = [];
  final int _maxBufferSize = 1000;

  String? _currentTraceId;
  String? _currentUserId;

  Stream<LogEntry> get logStream => _logStream.stream;

  void startTrace(String traceId, {String? userId}) {
    _currentTraceId = traceId;
    _currentUserId = userId;
    log(LogLevel.info, LogCategory.system, '开始执行任务',
        metadata: {'traceId': traceId, 'userId': userId});
  }

  void endTrace({String? result}) {
    if (_currentTraceId != null) {
      log(LogLevel.info, LogCategory.system, '任务执行完成',
          metadata: {'result': result});
      _currentTraceId = null;
      _currentUserId = null;
    }
  }

  void log(LogLevel level, LogCategory category, String message, {
    Map<String, dynamic>? metadata,
    String? traceId,
    String? userId,
    Duration? duration,
  }) {
    final entry = LogEntry(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata ?? {},
      traceId: traceId ?? _currentTraceId,
      userId: userId ?? _currentUserId,
      duration: duration,
    );

    _addToBuffer(entry);
    _logStream.add(entry);

    // 持久化重要日志
    if (level.index >= LogLevel.warn.index) {
      _persistLog(entry);
    }

    // 控制台输出（调试模式）
    if (kDebugMode) {
      print('${_formatLogForConsole(entry)}');
    }
  }

  void _addToBuffer(LogEntry entry) {
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
  }

  Future<void> _persistLog(LogEntry entry) async {
    try {
      final db = await _getDatabase();
      await db.insert('logs', entry.toJson());
    } catch (e) {
      print('日志持久化失败: $e');
    }
  }

  List<LogEntry> filter({
    LogLevel? level,
    LogCategory? category,
    String? traceId,
    String? userId,
    DateTime? since,
    DateTime? until,
    String? searchText,
  }) {
    return _logBuffer.where((log) {
      if (level != null && log.level != level) return false;
      if (category != null && log.category != category) return false;
      if (traceId != null && log.traceId != traceId) return false;
      if (userId != null && log.userId != userId) return false;
      if (since != null && log.timestamp.isBefore(since)) return false;
      if (until != null && log.timestamp.isAfter(until)) return false;
      if (searchText != null && !log.message.toLowerCase().contains(searchText.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           Random().nextInt(1000).toString().padLeft(3, '0');
  }

  String _formatLogForConsole(LogEntry entry) {
    final time = DateFormat('HH:mm:ss.SSS').format(entry.timestamp);
    final level = entry.level.name.toUpperCase().padRight(8);
    final category = entry.category.name.padRight(11);
    return '[$time] $level [$category] ${entry.message}';
  }
}
```

### 3. 任务执行引擎优化

#### 3.1 智能任务规划器
```dart
enum TaskComplexity { simple, moderate, complex }

class TaskPlanner {
  Future<ExecutionPlan> planTask(String userIntent, String currentState) async {
    // 分析任务复杂度
    final complexity = await _analyzeTaskComplexity(userIntent);

    // 生成执行步骤
    final steps = await _generateExecutionSteps(userIntent, currentState, complexity);

    // 估算执行时间
    final estimatedDuration = _estimateExecutionTime(steps);

    // 风险评估
    final risks = await _assessRisks(steps);

    return ExecutionPlan(
      id: _generatePlanId(),
      userIntent: userIntent,
      complexity: complexity,
      steps: steps,
      estimatedDuration: estimatedDuration,
      risks: risks,
      createdAt: DateTime.now(),
    );
  }

  Future<TaskComplexity> _analyzeTaskComplexity(String intent) async {
    // 使用关键词和模式匹配分析
    final complexKeywords = ['登录', '发布', '上传', '下载', '支付', '注册'];
    final moderateKeywords = ['搜索', '浏览', '查看', '切换'];
    final simpleKeywords = ['点击', '输入', '滑动', '返回'];

    if (complexKeywords.any((keyword) => intent.contains(keyword))) {
      return TaskComplexity.complex;
    } else if (moderateKeywords.any((keyword) => intent.contains(keyword))) {
      return TaskComplexity.moderate;
    } else {
      return TaskComplexity.simple;
    }
  }
}

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

class ExecutionStep {
  final String id;
  final String action;
  final Map<String, dynamic> parameters;
  final List<String> expectedOutcomes;
  final List<String> preconditions;
  final int maxRetries;
  final Duration timeout;
  final double confidenceScore;

  ExecutionStep({
    required this.id,
    required this.action,
    required this.parameters,
    this.expectedOutcomes = const [],
    this.preconditions = const [],
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
    this.confidenceScore = 1.0,
  });
}
```

#### 3.2 改进的执行引擎
```dart
class EnhancedExecutionEngine {
  final EnhancedLogger _logger = EnhancedLogger();

  Future<ExecutionResult> executeStep(ExecutionStep step) async {
    final stopwatch = Stopwatch()..start();
    final stepId = step.id;

    _logger.log(LogLevel.info, LogCategory.system,
      '开始执行步骤: ${step.action}',
      metadata: {
        'stepId': stepId,
        'action': step.action,
        'parameters': step.parameters,
        'confidenceScore': step.confidenceScore,
      }
    );

    try {
      // 前置条件检查
      if (!await _checkPreconditions(step)) {
        return ExecutionResult.failure(
          stepId: stepId,
          reason: '前置条件不满足',
          duration: stopwatch.elapsed,
        );
      }

      // 执行操作
      final result = await _performAction(step);

      // 结果验证
      if (!await _verifyResult(step, result)) {
        return ExecutionResult.failure(
          stepId: stepId,
          reason: '结果验证失败',
          duration: stopwatch.elapsed,
        );
      }

      _logger.log(LogLevel.info, LogCategory.system,
        '步骤执行成功: ${step.action}',
        metadata: {
          'stepId': stepId,
          'duration': stopwatch.elapsedMilliseconds,
          'result': result,
        }
      );

      return ExecutionResult.success(
        stepId: stepId,
        result: result,
        duration: stopwatch.elapsed,
      );

    } catch (e, stackTrace) {
      _logger.log(LogLevel.error, LogCategory.system,
        '步骤执行异常: ${step.action}',
        metadata: {
          'stepId': stepId,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
          'duration': stopwatch.elapsedMilliseconds,
        }
      );

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
        _logger.log(LogLevel.warn, LogCategory.system,
          '前置条件检查失败: $condition');
        return false;
      }
    }
    return true;
  }

  Future<Map<String, dynamic>> _performAction(ExecutionStep step) async {
    switch (step.action) {
      case 'Launch':
        return await _launchApp(step.parameters);
      case 'Tap':
        return await _performTap(step.parameters);
      case 'Type':
        return await _performType(step.parameters);
      case 'Swipe':
        return await _performSwipe(step.parameters);
      case 'Wait':
        return await _performWait(step.parameters);
      default:
        throw UnsupportedError('不支持的操作: ${step.action}');
    }
  }
}

class ExecutionResult {
  final String stepId;
  final bool success;
  final Map<String, dynamic>? result;
  final String? reason;
  final Duration duration;

  ExecutionResult._({
    required this.stepId,
    required this.success,
    this.result,
    this.reason,
    required this.duration,
  });

  factory ExecutionResult.success({
    required String stepId,
    Map<String, dynamic>? result,
    required Duration duration,
  }) => ExecutionResult._(
    stepId: stepId,
    success: true,
    result: result,
    duration: duration,
  );

  factory ExecutionResult.failure({
    required String stepId,
    required String reason,
    required Duration duration,
  }) => ExecutionResult._(
    stepId: stepId,
    success: false,
    reason: reason,
    duration: duration,
  );
}
```

## 🚀 实施计划

### 第1阶段：基础优化（1-2周）
- [x] 创建优化文档
- [ ] 配置管理系统实现
- [ ] 基础日志结构化
- [ ] 错误处理增强

### 第2阶段：核心优化（3-4周）
- [ ] 任务执行引擎重构
- [ ] AI推理流程优化
- [ ] 性能监控实现
- [ ] UI界面改进

### 第3阶段：高级功能（5-8周）
- [ ] 任务持久化
- [ ] 异常检测系统
- [ ] 安全加固
- [ ] 完整测试覆盖

## 📈 预期成果

### 量化指标
- 任务成功率：70% → 85%+
- 执行效率：提升 40%
- 内存占用：减少 30%
- 故障诊断时间：减少 60%

### 质量改善
- 配置管理用户友好化
- 日志系统专业化
- 错误处理智能化
- 性能监控实时化

---

*此文档将随着优化进度持续更新*