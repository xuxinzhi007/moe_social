import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
// import '../../config/app_config.dart'; // AI服务内部已使用
import '../../services/enhanced_logger.dart';
import '../../services/task_execution_engine.dart';
import '../../services/ai_inference_service.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';
import '../../autoglm/autoglm_service.dart';
import 'autoglm_config_page.dart';

class AutoGLMTaskPage extends StatefulWidget {
  const AutoGLMTaskPage({Key? key}) : super(key: key);

  @override
  _AutoGLMTaskPageState createState() => _AutoGLMTaskPageState();
}

class _AutoGLMTaskPageState extends State<AutoGLMTaskPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _logger = EnhancedLogger();
  final _executionEngine = EnhancedExecutionEngine();

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isProcessing = false;
  bool _isAccessibilityServiceConnected = false;
  bool _hasShownAccessibilityHint = false;
  String? _currentTraceId;
  ExecutionPlan? _currentPlan;
  int _currentStep = 0;

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  StreamSubscription<LogEntry>? _logSubscription;
  List<LogEntry> _displayLogs = [];

  // 预设命令
  final List<String> _presetCommands = [
    '给第一条动态点赞',
    '搜索"Flutter"',
    '发布一条动态',
    '切换到设置页面',
    '查看消息列表',
    '打开相机拍照',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibilityService(showDialogIfDisabled: true);
    _setupLogListener();
    _initializeAIService();
  }

  Future<void> _initializeAIService() async {
    try {
      await AIInferenceService().initialize();
      _logger.info('AI推理服务初始化成功', category: LogCategory.ai);
    } catch (e) {
      _logger.error('AI推理服务初始化失败: $e', category: LogCategory.ai);
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
  }

  void _setupLogListener() {
    _logSubscription = _logger.logStream.listen((logEntry) {
      if (mounted) {
        setState(() {
          _displayLogs.add(logEntry);
          if (_displayLogs.length > 100) {
            _displayLogs.removeAt(0);
          }
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
      }
    });
  }

  Future<void> _checkAccessibilityService({bool showDialogIfDisabled = false}) async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _isAccessibilityServiceConnected = true;
        });
      }
      _logger.info('运行在Web端，跳过无障碍服务检查', category: LogCategory.system);
      return;
    }

    try {
      final result = await AutoGLMService.checkServiceStatus();
      if (mounted) {
        setState(() {
          _isAccessibilityServiceConnected = result;
        });
      }

      if (_isAccessibilityServiceConnected) {
        _logger.info('无障碍服务已连接', category: LogCategory.system);
      } else {
        _logger.warn('无障碍服务未连接，部分功能将不可用', category: LogCategory.system);
        if (showDialogIfDisabled && !_hasShownAccessibilityHint && mounted) {
          _hasShownAccessibilityHint = true;
          _showAccessibilityDialog();
        }
      }
    } catch (e) {
      _logger.error('检查无障碍服务失败: $e', category: LogCategory.system);
      if (mounted) {
        setState(() {
          _isAccessibilityServiceConnected = false;
        });
      }
    }
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要开启无障碍服务'),
        content: const Text('请在系统设置中开启 Moe Social 助手无障碍服务，以便 AutoGLM 正常工作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openAccessibilitySettings();
            },
            child: const Text('前往开启'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityService();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatusCard(),
          Expanded(child: _buildLogDisplay()),
          _buildInputArea(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'AutoGLM 智能助手',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF7F7FD5),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined, color: Colors.white),
          onPressed: _showAnalytics,
          tooltip: '查看分析',
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: _showHistory,
          tooltip: '执行历史',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'config', child: Text('配置设置')),
            const PopupMenuItem(value: 'logs', child: Text('导出日志')),
            const PopupMenuItem(value: 'help', child: Text('使用帮助')),
            const PopupMenuItem(value: 'about', child: Text('关于')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: _isAccessibilityServiceConnected ? null : _openAccessibilitySettings,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _isAccessibilityServiceConnected
                    ? const Color(0xFF91EAE4)
                    : Colors.orange,
                _isAccessibilityServiceConnected
                    ? const Color(0xFF7F7FD5)
                    : Colors.deepOrange,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isProcessing ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAccessibilityServiceConnected
                          ? (_isProcessing ? Icons.psychology : Icons.check_circle)
                          : Icons.warning,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAccessibilityServiceConnected
                        ? (_isProcessing ? '正在执行任务...' : '服务就绪')
                        : '服务未启用',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAccessibilityServiceConnected
                        ? (_isProcessing
                            ? '步骤 $_currentStep${_currentPlan?.steps.length != null ? '/${_currentPlan!.steps.length}' : ''}'
                            : '可以开始执行智能任务')
                        : '请在设置中启用无障碍服务',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (_isProcessing && _currentPlan != null)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            final progress = _currentPlan!.steps.isNotEmpty
                                ? _currentStep / _currentPlan!.steps.length
                                : 0.0;
                            return LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 4,
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (!_isAccessibilityServiceConnected)
              ElevatedButton(
                onPressed: _openAccessibilitySettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('设置'),
              ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogDisplay() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: Color(0xFF7F7FD5)),
                const SizedBox(width: 8),
                const Text(
                  '执行日志',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 20),
                  onPressed: _clearLogs,
                  tooltip: '清空日志',
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: _copyLogs,
                  tooltip: '复制日志',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _displayLogs.isEmpty
                  ? _buildEmptyLogView()
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _displayLogs.length,
                      itemBuilder: (context, index) {
                        return _buildLogItem(_displayLogs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无执行日志',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入命令开始使用智能助手',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getLogBackgroundColor(log.level),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getLogBorderColor(log.level),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                log.levelEmoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 4),
              Text(
                log.categoryEmoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                log.timestamp.toString().substring(11, 19),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              if (log.duration != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${log.duration!.inMilliseconds}ms',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            log.message,
            style: TextStyle(
              fontSize: 14,
              color: _getLogTextColor(log.level),
              fontFamily: 'monospace',
            ),
          ),
          if (log.metadata.isNotEmpty && log.level.index >= LogLevel.warn.index)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Details: ${jsonEncode(log.metadata)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getLogBackgroundColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue.shade50;
      case LogLevel.info:
        return Colors.green.shade50;
      case LogLevel.warn:
        return Colors.orange.shade50;
      case LogLevel.error:
      case LogLevel.critical:
        return Colors.red.shade50;
    }
  }

  Color _getLogBorderColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue.shade200;
      case LogLevel.info:
        return Colors.green.shade200;
      case LogLevel.warn:
        return Colors.orange.shade200;
      case LogLevel.error:
      case LogLevel.critical:
        return Colors.red.shade200;
    }
  }

  Color _getLogTextColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.blue.shade800;
      case LogLevel.info:
        return Colors.green.shade800;
      case LogLevel.warn:
        return Colors.orange.shade800;
      case LogLevel.error:
      case LogLevel.critical:
        return Colors.red.shade800;
    }
  }

  Widget _buildInputArea() {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            if (_presetCommands.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetCommands.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(_presetCommands[index]),
                        onPressed: () {
                          _inputController.text = _presetCommands[index];
                        },
                        backgroundColor: const Color(0xFFF5F7FA),
                        labelStyle: const TextStyle(
                          color: Color(0xFF7F7FD5),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isProcessing && _isAccessibilityServiceConnected,
                      decoration: InputDecoration(
                        hintText: _isAccessibilityServiceConnected
                            ? '输入命令 (例如: 给第一条动态点赞)'
                            : '请先启用无障碍服务',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.mic, color: Color(0xFF7F7FD5)),
                          onPressed: _startVoiceInput,
                          tooltip: '语音输入',
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (value) => _executeTask(value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 56,
                    height: 56,
                    child: FloatingActionButton(
                      heroTag: "execute_button",
                      onPressed: _isProcessing ? _stopTask : _executeCurrentTask,
                      backgroundColor: _isProcessing
                          ? Colors.red
                          : const Color(0xFF7F7FD5),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isProcessing
                            ? const Icon(Icons.stop, color: Colors.white, key: ValueKey('stop'))
                            : const Icon(Icons.send, color: Colors.white, key: ValueKey('send')),
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
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isProcessing)
          FloatingActionButton(
            heroTag: "pause_button",
            mini: true,
            onPressed: _pauseTask,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.pause, color: Colors.white),
            tooltip: '暂停任务',
          ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: "quick_actions_button",
          onPressed: _showQuickActions,
          backgroundColor: const Color(0xFF86A8E7),
          child: const Icon(Icons.apps, color: Colors.white),
          tooltip: '快速操作',
        ),
      ],
    );
  }

  Future<void> _executeCurrentTask() async {
    final command = _inputController.text.trim();
    if (command.isEmpty) return;

    await _executeTask(command);
    _inputController.clear();
  }

  Future<void> _executeTask(String command) async {
    if (!_isAccessibilityServiceConnected && !kIsWeb) {
      _logger.warn('无障碍服务未连接，无法执行任务', category: LogCategory.system);
      MoeToast.error(context, '请先在系统设置中启用 Moe Social 助手无障碍服务');
      _openAccessibilitySettings();
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = 0;
    });

    _pulseController.repeat(reverse: true);
    _progressController.forward();

    final traceId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    _currentTraceId = traceId;

    try {
      _logger.startTrace(traceId);
      _logger.info('开始执行任务: $command',
        metadata: {'command': command, 'traceId': traceId},
        category: LogCategory.user,
      );

      if (kIsWeb) {
        // Web端模拟执行
        await _simulateTaskExecution(command);
      } else {
        // 移动端真实执行
        final result = await _executionEngine.executeUserInstruction(command);

        if (result['success'] == true) {
          _logger.info('任务执行完成',
            metadata: {
              'totalSteps': result['totalSteps'],
              'completedSteps': result['completedSteps'],
              'successfulSteps': result['successfulSteps'],
              'totalDuration': result['totalDuration'],
            },
            category: LogCategory.system);

          // 更新UI显示完成状态
          setState(() {
            _currentStep = result['totalSteps'] as int? ?? 0;
          });
        } else {
          _logger.error('任务执行失败: ${result['error'] ?? '未知错误'}',
            metadata: result,
            category: LogCategory.system);
        }
      }

    } catch (e, stackTrace) {
      _logger.error('任务执行异常: $e',
        metadata: {
          'command': command,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
        category: LogCategory.system,
      );
    } finally {
      _logger.endTrace(result: '任务执行结束');

      setState(() {
        _isProcessing = false;
        _currentStep = 0;
        _currentPlan = null;
        _currentTraceId = null;
      });

      _pulseController.stop();
      _progressController.reset();
    }
  }

  /// Web端模拟任务执行
  Future<void> _simulateTaskExecution(String command) async {
    _logger.info('Web端模拟执行，仅用于UI演示', category: LogCategory.system);

    // 模拟任务分析阶段
    _logger.info('正在分析任务: $command', category: LogCategory.ai);
    await Future.delayed(const Duration(seconds: 1));

    // 模拟生成执行计划
    final steps = _getSimulatedSteps(command);
    _logger.info('任务规划完成，共${steps.length}个步骤',
      metadata: {'stepCount': steps.length},
      category: LogCategory.ai);

    // 模拟执行每个步骤
    for (int i = 0; i < steps.length; i++) {
      if (!_isProcessing) break; // 检查是否被停止

      setState(() => _currentStep = i + 1);

      _logger.info('执行步骤 ${i + 1}: ${steps[i]}',
        category: LogCategory.device);

      // 模拟步骤执行时间
      await Future.delayed(const Duration(milliseconds: 800));

      _logger.info('步骤 ${i + 1} 执行成功',
        category: LogCategory.device);
    }

    _logger.info('模拟任务执行完成 ✨', category: LogCategory.system);
  }

  /// 根据命令生成模拟的执行步骤
  List<String> _getSimulatedSteps(String command) {
    final lowerCommand = command.toLowerCase();

    if (lowerCommand.contains('点赞')) {
      return ['分析界面', '查找点赞按钮', '点击点赞', '验证结果'];
    } else if (lowerCommand.contains('搜索')) {
      return ['分析界面', '查找搜索框', '点击搜索框', '输入搜索内容', '点击搜索按钮', '等待结果'];
    } else if (lowerCommand.contains('发布')) {
      return ['分析界面', '查找发布入口', '点击发布按钮', '进入发布页面'];
    } else {
      return ['分析界面', '识别操作目标', '执行操作', '验证结果'];
    }
  }

  Future<String> _getCurrentScreenshot() async {
    try {
      final screenshot = await AutoGLMService.getScreenshot();
      return screenshot ?? '';
    } catch (e) {
      _logger.warn('获取截图失败: $e', category: LogCategory.device);
      return '';
    }
  }

  void _stopTask() {
    if (_isProcessing) {
      setState(() => _isProcessing = false);
      _logger.warn('任务被用户停止', category: LogCategory.user);
    }
  }

  void _pauseTask() {
    // 实现任务暂停逻辑
    _logger.info('任务暂停功能开发中...', category: LogCategory.system);
  }

  void _startVoiceInput() {
    // 实现语音输入功能
    _logger.info('语音输入功能开发中...', category: LogCategory.system);
  }

  void _clearLogs() {
    setState(() => _displayLogs.clear());
    _logger.info('日志已清空', category: LogCategory.system);
  }

  Future<void> _copyLogs() async {
    final logsText = _displayLogs.map((log) => log.format(includeMetadata: true)).join('\n');
    await Clipboard.setData(ClipboardData(text: logsText));
    MoeToast.success(context, '日志已复制到剪贴板');
  }

  void _openAccessibilitySettings() {
    AutoGLMService.openAccessibilitySettings();
  }

  void _showAnalytics() {
    if (_currentTraceId != null) {
      // 显示当前任务分析
      _showTaskAnalysis(_currentTraceId!);
    } else {
      // 显示总体分析
      _showOverallAnalytics();
    }
  }

  void _showHistory() {
    // 显示执行历史
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildHistoryPage(),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildQuickActionsSheet(),
    );
  }

  Widget _buildQuickActionsSheet() {
    final quickActions = [
      {'title': '屏幕截图', 'icon': Icons.screenshot, 'action': 'screenshot'},
      {'title': '返回桌面', 'icon': Icons.home, 'action': 'home'},
      {'title': '返回上级', 'icon': Icons.arrow_back, 'action': 'back'},
      {'title': '重启服务', 'icon': Icons.refresh, 'action': 'restart_service'},
      {'title': '系统设置', 'icon': Icons.settings, 'action': 'system_settings'},
      {'title': '网络测试', 'icon': Icons.network_check, 'action': 'network_test'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '快速操作',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _handleQuickAction(action['action'] as String);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        size: 32,
                        color: const Color(0xFF7F7FD5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['title'] as String,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String action) async {
    switch (action) {
      case 'screenshot':
        final screenshot = await _getCurrentScreenshot();
        if (screenshot.isNotEmpty) {
          _logger.info('已截取当前屏幕', category: LogCategory.device);
        } else {
          _logger.warn('截图失败', category: LogCategory.device);
        }
        break;
      case 'home':
        await AutoGLMService.performHome();
        _logger.info('已发送返回桌面指令', category: LogCategory.device);
        break;
      case 'back':
        await AutoGLMService.performBack();
        _logger.info('已发送返回上级指令', category: LogCategory.device);
        break;
      case 'restart_service':
        _restartService();
        break;
      case 'system_settings':
        _executeTask('打开系统设置');
        break;
      case 'network_test':
        _testNetworkConnection();
        break;
    }
  }

  void _restartService() {
    // 重启服务
    _logger.info('重启服务功能开发中...', category: LogCategory.system);
  }

  void _testNetworkConnection() {
    // 测试网络连接
    _logger.info('正在测试网络连接...', category: LogCategory.network);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'config':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AutoGLMConfigPage()),
        );
        break;
      case 'logs':
        _exportLogs();
        break;
      case 'help':
        _showHelp();
        break;
      case 'about':
        _showAbout();
        break;
    }
  }

  void _exportLogs() {
    // 导出日志功能
    _logger.info('日志导出功能开发中...', category: LogCategory.system);
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🤖 AutoGLM 智能助手', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('AutoGLM 是一个AI驱动的智能手机操作助手，可以通过自然语言命令自动执行各种手机操作。'),
              SizedBox(height: 16),
              Text('📱 支持的操作', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 点击按钮和链接'),
              Text('• 输入文本内容'),
              Text('• 滑动和手势操作'),
              Text('• 启动和切换应用'),
              Text('• 搜索和浏览内容'),
              SizedBox(height: 16),
              Text('💡 使用示例', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• "给第一条动态点赞"'),
              Text('• "搜索Flutter教程"'),
              Text('• "发布一条动态说Hello"'),
              Text('• "打开设置页面"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 AutoGLM'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Color(0xFF7F7FD5)),
            SizedBox(height: 16),
            Text('AutoGLM 智能助手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('版本: 1.0.0'),
            SizedBox(height: 16),
            Text('基于大型语言模型的智能手机操作助手，让您的手机更智能、更便捷。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showTaskAnalysis(String traceId) {
    // 显示任务分析
    _logger.info('任务分析功能开发中...', category: LogCategory.system);
  }

  void _showOverallAnalytics() {
    // 显示总体分析
    _logger.info('总体分析功能开发中...', category: LogCategory.system);
  }

  Widget _buildHistoryPage() {
    // 构建历史页面
    return Scaffold(
      appBar: AppBar(
        title: const Text('执行历史'),
        backgroundColor: const Color(0xFF7F7FD5),
      ),
      body: const Center(
        child: Text('历史页面开发中...'),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _logSubscription?.cancel();
    super.dispose();
  }
}
