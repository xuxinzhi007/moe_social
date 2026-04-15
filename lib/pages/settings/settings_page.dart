import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/startup_update_preferences.dart';
import '../../providers/device_info_provider.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/settings/lazy_load_widget.dart';
import '../../widgets/settings/settings_search_bar.dart';
import 'modules/device_storage_module.dart';
import 'modules/ai_settings_module.dart';
import 'modules/appearance_module.dart';
import 'modules/account_security_module.dart';
import 'modules/about_module.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoUpdateOnLaunch = true;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceInfoProvider>(context, listen: false).init();
      unawaited(_loadStartupUpdatePref());
    });
  }

  Future<void> _loadStartupUpdatePref() async {
    final v = await StartupUpdatePreferences.getAutoCheckOnLaunch();
    if (mounted) {
      setState(() => _autoUpdateOnLaunch = v);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
  }

  void _onClearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  bool _shouldShowModule(String moduleName) {
    if (!_isSearching) return true;
    return moduleName.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);
    final isWeb = kIsWeb;
    final isMobile = !isWeb;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 在Web平台上，搜索栏的样式和布局可能需要调整
          if (isWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7F7FD5).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: '搜索设置',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _onClearSearch();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            )
          else
            SettingsSearchBar(
              onSearch: _onSearch,
              onClear: _onClearSearch,
            ),
          Expanded(
            child: ListView(
              physics: isMobile ? const BouncingScrollPhysics() : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                if (_isSearching) {
                  _buildSearchResults()
                } else {
                  ..._buildNormalSettings()
                },
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResults = _getSearchResults();
    
    if (searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '未找到与「$_searchQuery」相关的设置',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // 按模块分类展示搜索结果
    final categorizedResults = _categorizeSearchResults(searchResults);
    
    return Column(
      children: categorizedResults.entries.map((entry) {
        final moduleName = entry.key;
        final moduleResults = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
              child: Text(
                moduleName,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...moduleResults.map((result) => _buildSearchResultItem(result)).toList(),
          ],
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _getSearchResults() {
    final results = <Map<String, dynamic>>[];
    
    // 模拟搜索结果，实际应用中应该根据实际设置项进行搜索
    if (_searchQuery.toLowerCase().contains('通知')) {
      results.add({
        'title': '推送通知',
        'description': '接收最新动态和系统通知',
        'icon': Icons.notifications_active_rounded,
        'color': Colors.orange,
        'module': '常规设置',
      });
    }
    
    if (_searchQuery.toLowerCase().contains('设备')) {
      results.add({
        'title': '本机设备信息',
        'description': '查看设备ID、系统版本、网络状态等',
        'icon': Icons.phone_iphone_rounded,
        'color': Colors.blueGrey,
        'module': '设备与存储',
      });
      results.add({
        'title': '远程设备列表',
        'description': '查看登录过的设备',
        'icon': Icons.devices_other_rounded,
        'color': Colors.cyan,
        'module': '设备与存储',
      });
      results.add({
        'title': '存储空间管理',
        'description': '查看应用存储使用情况，清理缓存',
        'icon': Icons.storage_rounded,
        'color': Colors.amber,
        'module': '设备与存储',
      });
    }
    
    if (_searchQuery.toLowerCase().contains('ai') || _searchQuery.toLowerCase().contains('模型')) {
      results.add({
        'title': '终端同款（本地 Ollama）',
        'description': '直连电脑 Ollama，尽量对齐终端输出',
        'icon': Icons.terminal_rounded,
        'color': Colors.deepPurpleAccent,
        'module': 'AI 模型',
      });
      results.add({
        'title': '模型记忆线',
        'description': '查看模型记录的所有记忆',
        'icon': Icons.psychology_rounded,
        'color': Colors.deepPurple,
        'module': 'AI 模型',
      });
    }
    
    if (_searchQuery.toLowerCase().contains('主题') || _searchQuery.toLowerCase().contains('外观')) {
      results.add({
        'title': '主题模式',
        'description': '选择应用明暗模式',
        'icon': Icons.color_lens_rounded,
        'color': Colors.purple,
        'module': '外观',
      });
      results.add({
        'title': '主题颜色',
        'description': '自定义应用主色调',
        'icon': Icons.palette_rounded,
        'color': Colors.pink,
        'module': '外观',
      });
      results.add({
        'title': '字体大小',
        'description': '调整应用字体大小',
        'icon': Icons.text_fields_rounded,
        'color': Colors.green,
        'module': '外观',
      });
    }
    
    if (_searchQuery.toLowerCase().contains('账户') || _searchQuery.toLowerCase().contains('安全')) {
      results.add({
        'title': '修改密码',
        'description': '修改您的账户密码',
        'icon': Icons.lock_rounded,
        'color': Colors.blue,
        'module': '账户与安全',
      });
      results.add({
        'title': '隐私设置',
        'description': '管理应用权限和隐私设置',
        'icon': Icons.privacy_tip_rounded,
        'color': Colors.green,
        'module': '账户与安全',
      });
      results.add({
        'title': '账号安全',
        'description': '查看登录历史，管理登录设备',
        'icon': Icons.shield_rounded,
        'color': Colors.red,
        'module': '账户与安全',
      });
    }
    
    if (_searchQuery.toLowerCase().contains('关于')) {
      results.add({
        'title': '软件版本',
        'description': '点击检查更新',
        'icon': Icons.info_rounded,
        'color': Colors.teal,
        'module': '关于',
      });
      results.add({
        'title': '意见反馈',
        'description': '问题描述与联系方式',
        'icon': Icons.feedback_outlined,
        'color': Colors.deepOrange,
        'module': '关于',
      });
      results.add({
        'title': '用户协议',
        'description': '查看用户协议和隐私政策',
        'icon': Icons.description_rounded,
        'color': Colors.grey,
        'module': '关于',
      });
    }
    
    return results;
  }

  Map<String, List<Map<String, dynamic>>> _categorizeSearchResults(List<Map<String, dynamic>> results) {
    final categorized = <String, List<Map<String, dynamic>>>{};
    
    for (final result in results) {
      final module = result['module'] as String;
      if (!categorized.containsKey(module)) {
        categorized[module] = [];
      }
      categorized[module]!.add(result);
    }
    
    return categorized;
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F7FD5).withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (result['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(result['icon'] as IconData, color: result['color'] as Color, size: 20),
          ),
          title: Text(result['title'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(result['description'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            // 实现搜索结果导航逻辑
            _navigateToSettingItem(result['title'] as String);
          },
        ),
      ),
    );
  }

  void _navigateToSettingItem(String title) {
    switch (title) {
      case '推送通知':
        // 通知设置在当前页面，无需跳转
        break;
      case '本机设备信息':
      case '远程设备列表':
      case '存储空间管理':
        // 这些功能在设备与存储模块中
        _showDeviceStorageModule();
        break;
      case '终端同款（本地 Ollama）':
      case '模型记忆线':
        // 这些功能在AI模型模块中
        _showAiSettingsModule();
        break;
      case '主题模式':
      case '主题颜色':
        // 这些功能在外观模块中
        _showAppearanceModule();
        break;
      case '修改密码':
      case '隐私设置':
        // 这些功能在账户与安全模块中
        _showAccountSecurityModule();
        break;
      case '软件版本':
      case '意见反馈':
        // 这些功能在关于模块中
        _showAboutModule();
        break;
      default:
        break;
    }
  }

  void _showDeviceStorageModule() {
    // 滚动到设备与存储模块
    _scrollToModule('设备与存储');
  }

  void _showAiSettingsModule() {
    // 滚动到AI模型模块
    _scrollToModule('AI 模型');
  }

  void _showAppearanceModule() {
    // 滚动到外观模块
    _scrollToModule('外观');
  }

  void _showAccountSecurityModule() {
    // 滚动到账户与安全模块
    _scrollToModule('账户与安全');
  }

  void _showAboutModule() {
    // 滚动到关于模块
    _scrollToModule('关于');
  }

  void _scrollToModule(String moduleName) {
    // 这里可以实现滚动逻辑，将指定模块滚动到视图中
    // 由于当前实现中没有使用滚动控制器，我们可以通过重置搜索状态并让用户手动滚动
    _onClearSearch();
    // 实际应用中，应该使用 ScrollController 来实现精确滚动
  }

  List<Widget> _buildNormalSettings() {
    return [
      _buildSectionTitle('账户与安全'),
      LazyLoadWidget(
        child: const AccountSecurityModule(),
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('外观'),
      LazyLoadWidget(
        child: const AppearanceModule(),
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('常规设置'),
      FadeInUp(
        delay: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7F7FD5).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 20),
            ),
            title: const Text('推送通知', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('接收最新动态和系统通知', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              activeColor: const Color(0xFF7F7FD5),
              onChanged: (bool value) async {
                setState(() {
                  _isLoading = true;
                });
                
                // 模拟网络请求或其他操作
                await Future.delayed(const Duration(seconds: 1));
                
                setState(() {
                  _notificationsEnabled = value;
                  _isLoading = false;
                });
                
                // 显示操作结果反馈
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? '通知已开启' : '通知已关闭'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ),
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('设备与存储'),
      LazyLoadWidget(
        child: DeviceStorageModule(
          autoUpdateOnLaunch: _autoUpdateOnLaunch,
          onAutoUpdateChanged: (bool value) async {
            setState(() => _autoUpdateOnLaunch = value);
            await StartupUpdatePreferences.setAutoCheckOnLaunch(value);
          },
        ),
      ),
      
      const SizedBox(height: 24),
      _buildSectionTitle('AI 模型'),
      LazyLoadWidget(
        child: const AiSettingsModule(),
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('关于'),
      LazyLoadWidget(
        child: const AboutModule(),
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


