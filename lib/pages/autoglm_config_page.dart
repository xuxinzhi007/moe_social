import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../services/enhanced_logger.dart';
import '../widgets/fade_in_up.dart';

class AutoGLMConfigPage extends StatefulWidget {
  @override
  _AutoGLMConfigPageState createState() => _AutoGLMConfigPageState();
}

class _AutoGLMConfigPageState extends State<AutoGLMConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _logger = EnhancedLogger();

  // 控制器
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _maxStepsController = TextEditingController();
  final _stepTimeoutController = TextEditingController();

  // 状态变量
  bool _isLoading = false;
  bool _obscureApiKey = true;
  bool _enableLogging = true;
  String _logLevel = 'info';
  bool _enablePerformanceMonitoring = false;
  bool _hasChanges = false;

  final List<String> _logLevels = ['debug', 'info', 'warn', 'error', 'critical'];
  final List<String> _presetModels = [
    'ZhipuAI/AutoGLM-Phone-9B',
    'ZhipuAI/AutoGLM-Web-6B',
    'OpenAI/GPT-4V',
    'Claude/Claude-3-Vision',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _setupChangeListeners();
  }

  void _setupChangeListeners() {
    _apiUrlController.addListener(() => setState(() => _hasChanges = true));
    _apiKeyController.addListener(() => setState(() => _hasChanges = true));
    _modelNameController.addListener(() => setState(() => _hasChanges = true));
    _maxStepsController.addListener(() => setState(() => _hasChanges = true));
    _stepTimeoutController.addListener(() => setState(() => _hasChanges = true));
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      _apiUrlController.text = await AppConfig.getApiUrl();
      _apiKeyController.text = await AppConfig.getApiKey();
      _modelNameController.text = await AppConfig.getModelName();
      _maxStepsController.text = (await AppConfig.getMaxSteps()).toString();
      _stepTimeoutController.text = (await AppConfig.getStepTimeout()).inSeconds.toString();
      _enableLogging = await AppConfig.getEnableLogging();
      _logLevel = await AppConfig.getLogLevel();
      _enablePerformanceMonitoring = await AppConfig.getEnablePerformanceMonitoring();

      setState(() => _hasChanges = false);

      _logger.info('配置加载完成', category: LogCategory.system);
    } catch (e) {
      _logger.error('配置加载失败: $e', category: LogCategory.system);
      _showSnackBar('配置加载失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'AutoGLM 配置',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF7F7FD5),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: _showHelp,
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _exportConfig,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'import', child: Text('导入配置')),
                const PopupMenuItem(value: 'reset', child: Text('重置为默认值')),
                const PopupMenuItem(value: 'test', child: Text('测试所有设置')),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5)),
              ))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: _buildApiConfigSection(),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: _buildTaskConfigSection(),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: _buildSystemConfigSection(),
                    ),
                    const SizedBox(height: 32),
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: _buildActionButtons(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildApiConfigSection() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('🌐 API 配置', '配置AI模型服务接口'),
            const SizedBox(height: 16),
            _buildApiUrlField(),
            const SizedBox(height: 16),
            _buildApiKeyField(),
            const SizedBox(height: 16),
            _buildModelNameField(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskConfigSection() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('⚙️ 任务配置', '调整任务执行参数'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMaxStepsField()),
                const SizedBox(width: 16),
                Expanded(child: _buildStepTimeoutField()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemConfigSection() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('🔧 系统配置', '日志和性能监控设置'),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: '启用日志记录',
              subtitle: '记录系统运行和错误日志',
              value: _enableLogging,
              onChanged: (value) => setState(() {
                _enableLogging = value;
                _hasChanges = true;
              }),
            ),
            if (_enableLogging) ...[
              const SizedBox(height: 12),
              _buildLogLevelDropdown(),
            ],
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: '性能监控',
              subtitle: '监控任务执行性能和资源使用',
              value: _enablePerformanceMonitoring,
              onChanged: (value) => setState(() {
                _enablePerformanceMonitoring = value;
                _hasChanges = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildApiUrlField() {
    return TextFormField(
      controller: _apiUrlController,
      decoration: InputDecoration(
        labelText: 'API 地址 *',
        hintText: '请输入 API 服务地址',
        prefixIcon: Icon(Icons.cloud, color: Color(0xFF7F7FD5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: PopupMenuButton<String>(
          icon: Icon(Icons.history, color: Colors.grey[600]),
          tooltip: '选择预设地址',
          onSelected: (url) => _apiUrlController.text = url,
          itemBuilder: (context) => [
            'https://api-inference.modelscope.cn/v1/chat/completions',
            'https://api.openai.com/v1/chat/completions',
            'https://api.anthropic.com/v1/messages',
          ].map((url) => PopupMenuItem(value: url, child: Text(url))).toList(),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入API地址';
        }
        final uri = Uri.tryParse(value);
        if (uri == null || !uri.hasAbsolutePath) {
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
        labelText: 'API 密钥 *',
        hintText: '请输入 API 密钥',
        prefixIcon: Icon(Icons.key, color: Color(0xFF7F7FD5)),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
            ),
            IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: _scanApiKey,
              tooltip: '扫描二维码',
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入API密钥';
        }
        if (value.length < 20) {
          return 'API密钥长度不足';
        }
        return null;
      },
    );
  }

  Widget _buildModelNameField() {
    return DropdownButtonFormField<String>(
      value: _presetModels.contains(_modelNameController.text)
          ? _modelNameController.text
          : null,
      decoration: InputDecoration(
        labelText: '模型名称',
        prefixIcon: Icon(Icons.smart_toy, color: Color(0xFF7F7FD5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: IconButton(
          icon: Icon(Icons.edit),
          onPressed: _editCustomModel,
          tooltip: '自定义模型',
        ),
      ),
      items: _presetModels.map((model) => DropdownMenuItem(
        value: model,
        child: Text(model, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          _modelNameController.text = value;
          setState(() => _hasChanges = true);
        }
      },
      validator: (value) {
        if (_modelNameController.text.isEmpty) {
          return '请选择或输入模型名称';
        }
        return null;
      },
    );
  }

  Widget _buildMaxStepsField() {
    return TextFormField(
      controller: _maxStepsController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: '最大步数',
        hintText: '20',
        prefixIcon: Icon(Icons.linear_scale, color: Color(0xFF7F7FD5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入最大步数';
        }
        final steps = int.tryParse(value);
        if (steps == null || steps < 1 || steps > 100) {
          return '步数范围: 1-100';
        }
        return null;
      },
    );
  }

  Widget _buildStepTimeoutField() {
    return TextFormField(
      controller: _stepTimeoutController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: '步骤超时(秒)',
        hintText: '30',
        prefixIcon: Icon(Icons.timer, color: Color(0xFF7F7FD5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入超时时间';
        }
        final timeout = int.tryParse(value);
        if (timeout == null || timeout < 5 || timeout > 300) {
          return '超时范围: 5-300秒';
        }
        return null;
      },
    );
  }

  Widget _buildLogLevelDropdown() {
    return DropdownButtonFormField<String>(
      value: _logLevel,
      decoration: InputDecoration(
        labelText: '日志等级',
        prefixIcon: Icon(Icons.bug_report, color: Color(0xFF7F7FD5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _logLevels.map((level) => DropdownMenuItem(
        value: level,
        child: Row(
          children: [
            _getLogLevelIcon(level),
            const SizedBox(width: 8),
            Text(level.toUpperCase()),
          ],
        ),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _logLevel = value;
            _hasChanges = true;
          });
        }
      },
    );
  }

  Widget _getLogLevelIcon(String level) {
    switch (level) {
      case 'debug':
        return const Icon(Icons.bug_report, color: Colors.blue, size: 16);
      case 'info':
        return const Icon(Icons.info, color: Colors.green, size: 16);
      case 'warn':
        return const Icon(Icons.warning, color: Colors.orange, size: 16);
      case 'error':
        return const Icon(Icons.error, color: Colors.red, size: 16);
      case 'critical':
        return const Icon(Icons.dangerous, color: Colors.red, size: 16);
      default:
        return const Icon(Icons.circle, color: Colors.grey, size: 16);
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF7F7FD5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _testConnection,
                icon: const Icon(Icons.network_check, color: Colors.white),
                label: const Text('测试连接', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _hasChanges ? _saveConfig : null,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('保存配置', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasChanges ? const Color(0xFF7F7FD5) : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '您有未保存的更改，请点击"保存配置"以应用更改。',
                    style: TextStyle(color: Colors.orange, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('您有未保存的配置更改，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AppConfig.setApiUrl(_apiUrlController.text.trim());
      await AppConfig.setApiKey(_apiKeyController.text.trim());
      await AppConfig.setModelName(_modelNameController.text.trim());
      await AppConfig.setMaxSteps(int.parse(_maxStepsController.text));
      await AppConfig.setStepTimeout(Duration(seconds: int.parse(_stepTimeoutController.text)));
      await AppConfig.setEnableLogging(_enableLogging);
      await AppConfig.setLogLevel(_logLevel);
      await AppConfig.setEnablePerformanceMonitoring(_enablePerformanceMonitoring);

      setState(() => _hasChanges = false);

      _logger.info('配置保存成功',
        metadata: {
          'apiUrl': _apiUrlController.text,
          'modelName': _modelNameController.text,
          'maxSteps': int.parse(_maxStepsController.text),
          'stepTimeout': int.parse(_stepTimeoutController.text),
          'enableLogging': _enableLogging,
          'logLevel': _logLevel,
        },
        category: LogCategory.system,
      );

      _showSnackBar('配置保存成功！');
    } catch (e) {
      _logger.error('配置保存失败: $e', category: LogCategory.system);
      _showSnackBar('配置保存失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    if (!await AppConfig.validateApiConfig()) {
      _showSnackBar('请先配置有效的API地址和密钥', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 这里应该实际调用API测试连接
      // 为了演示，我们模拟一个延迟
      await Future.delayed(const Duration(seconds: 2));

      _logger.info('API连接测试成功', category: LogCategory.network);
      _showSnackBar('API连接测试成功！');
    } catch (e) {
      _logger.error('API连接测试失败: $e', category: LogCategory.network);
      _showSnackBar('连接测试失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置帮助'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌐 API 配置', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• API地址：AI服务的接口地址'),
              Text('• API密钥：用于身份验证的密钥'),
              Text('• 模型名称：使用的AI模型标识'),
              SizedBox(height: 16),
              Text('⚙️ 任务配置', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 最大步数：单个任务的最大执行步骤'),
              Text('• 步骤超时：每步操作的超时时间'),
              SizedBox(height: 16),
              Text('🔧 系统配置', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• 日志记录：是否记录系统运行日志'),
              Text('• 日志等级：控制日志详细程度'),
              Text('• 性能监控：是否监控系统性能'),
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

  Future<void> _exportConfig() async {
    try {
      final config = await AppConfig.exportConfig();
      final configJson = JsonEncoder.withIndent('  ').convert(config);

      await Clipboard.setData(ClipboardData(text: configJson));
      _showSnackBar('配置已复制到剪贴板');

      _logger.info('配置导出成功', category: LogCategory.system);
    } catch (e) {
      _logger.error('配置导出失败: $e', category: LogCategory.system);
      _showSnackBar('导出失败: $e', isError: true);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _importConfig();
        break;
      case 'reset':
        _resetToDefaults();
        break;
      case 'test':
        _testAllSettings();
        break;
    }
  }

  void _importConfig() {
    // 实现配置导入功能
    _showSnackBar('配置导入功能开发中...');
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置配置'),
        content: const Text('确定要重置为默认配置吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppConfig.resetToDefaults();
      await _loadConfig();
      _showSnackBar('配置已重置为默认值');
    }
  }

  void _testAllSettings() {
    // 实现所有设置测试功能
    _showSnackBar('全面测试功能开发中...');
  }

  void _scanApiKey() {
    // 实现二维码扫描功能
    _showSnackBar('二维码扫描功能开发中...');
  }

  void _editCustomModel() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _modelNameController.text);
        return AlertDialog(
          title: const Text('自定义模型'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: '请输入完整的模型标识',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _modelNameController.text = controller.text;
                setState(() => _hasChanges = true);
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF7F7FD5),
        duration: Duration(seconds: isError ? 4 : 2),
        action: SnackBarAction(
          label: '知道了',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _maxStepsController.dispose();
    _stepTimeoutController.dispose();
    super.dispose();
  }
}