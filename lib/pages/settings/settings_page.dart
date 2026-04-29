import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/startup_update_preferences.dart';
import '../../providers/device_info_provider.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/settings/settings_search_bar.dart';
import '../../providers/virtual_avatar_provider.dart';
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

  @override
  Widget build(BuildContext context) {
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
              controller: _scrollController,
              physics: isMobile ? const BouncingScrollPhysics() : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                if (_isSearching)
                  _buildSearchResults()
                else
                  ..._buildNormalSettings(),
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
            ...moduleResults.map((result) => _buildSearchResultItem(result)),
          ],
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _getSearchResults() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return <Map<String, dynamic>>[];

    final entries = _buildSearchEntries();
    final matched = entries.where((entry) {
      final keywords = (entry['keywords'] as List<String>).join(' ');
      final haystack =
          '${entry['title']} ${entry['description']} ${entry['module']} $keywords'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    matched.sort((a, b) {
      final aTitle = (a['title'] as String).toLowerCase();
      final bTitle = (b['title'] as String).toLowerCase();
      final aStarts = aTitle.startsWith(query) ? 1 : 0;
      final bStarts = bTitle.startsWith(query) ? 1 : 0;
      return bStarts.compareTo(aStarts);
    });

    return matched;
  }

  List<Map<String, dynamic>> _buildSearchEntries() {
    return [
      {
        'title': '推送通知',
        'description': '接收最新动态和系统通知',
        'icon': Icons.notifications_active_rounded,
        'color': Colors.orange,
        'module': '常规设置',
        'keywords': ['通知', '消息', '提醒', 'push'],
        'action': 'scroll',
        'target': '常规设置',
      },
      {
        'title': '虚拟助手开关',
        'description': '开启或关闭悬浮虚拟助手',
        'icon': Icons.smart_toy_rounded,
        'color': Colors.deepPurple,
        'module': '常规设置',
        'keywords': ['虚拟', '助手', '角色', '悬浮', '开关'],
        'action': 'scroll',
        'target': '常规设置',
      },
      {
        'title': '虚拟助手设置',
        'description': '自定义快捷功能、皮肤与角色',
        'icon': Icons.tune_rounded,
        'color': Colors.deepPurpleAccent,
        'module': '常规设置',
        'keywords': ['虚拟', '助手', '皮肤', '角色', '快捷功能'],
        'action': 'route',
        'target': '/virtual-avatar-settings',
      },
      {
        'title': '启动自动检查更新',
        'description': '打开应用时自动检查新版本',
        'icon': Icons.system_update_alt_rounded,
        'color': Colors.blue,
        'module': '设备与存储',
        'keywords': ['更新', '启动', '自动更新', '版本'],
        'action': 'scroll',
        'target': '设备与存储',
      },
      {
        'title': '本机设备信息',
        'description': '查看设备ID、系统版本、网络状态等',
        'icon': Icons.phone_iphone_rounded,
        'color': Colors.blueGrey,
        'module': '设备与存储',
        'keywords': ['设备', '系统', '版本', '网络', 'ID'],
        'action': 'scroll',
        'target': '设备与存储',
      },
      {
        'title': '存储空间管理',
        'description': '清理缓存和临时数据',
        'icon': Icons.storage_rounded,
        'color': Colors.amber,
        'module': '设备与存储',
        'keywords': ['缓存', '清理', '存储', '空间'],
        'action': 'scroll',
        'target': '设备与存储',
      },
      {
        'title': '终端同款（本地 Ollama）',
        'description': '直连电脑 Ollama，尽量对齐终端输出',
        'icon': Icons.terminal_rounded,
        'color': Colors.deepPurpleAccent,
        'module': 'AI 模型',
        'keywords': ['ai', '模型', 'ollama', '终端'],
        'action': 'scroll',
        'target': 'AI 模型',
      },
      {
        'title': '模型记忆线',
        'description': '查看模型记录的所有记忆',
        'icon': Icons.psychology_rounded,
        'color': Colors.deepPurple,
        'module': 'AI 模型',
        'keywords': ['记忆', 'ai', '模型', '上下文'],
        'action': 'scroll',
        'target': 'AI 模型',
      },
      {
        'title': '主题模式',
        'description': '切换浅色/深色/跟随系统',
        'icon': Icons.color_lens_rounded,
        'color': Colors.purple,
        'module': '外观',
        'keywords': ['主题', '深色', '浅色', '模式'],
        'action': 'scroll',
        'target': '外观',
      },
      {
        'title': '主题颜色',
        'description': '自定义应用主色调',
        'icon': Icons.palette_rounded,
        'color': Colors.pink,
        'module': '外观',
        'keywords': ['颜色', '主题色', '皮肤'],
        'action': 'scroll',
        'target': '外观',
      },
      {
        'title': '字体大小',
        'description': '调整应用字体大小',
        'icon': Icons.text_fields_rounded,
        'color': Colors.green,
        'module': '外观',
        'keywords': ['字体', '字号', '文字'],
        'action': 'scroll',
        'target': '外观',
      },
      {
        'title': '修改密码',
        'description': '修改账户登录密码',
        'icon': Icons.lock_rounded,
        'color': Colors.blue,
        'module': '账户与安全',
        'keywords': ['密码', '安全', '账户'],
        'action': 'scroll',
        'target': '账户与安全',
      },
      {
        'title': '隐私设置',
        'description': '管理应用权限和隐私设置',
        'icon': Icons.privacy_tip_rounded,
        'color': Colors.green,
        'module': '账户与安全',
        'keywords': ['隐私', '权限', '安全'],
        'action': 'scroll',
        'target': '账户与安全',
      },
      {
        'title': '账号安全',
        'description': '查看登录历史，管理登录设备',
        'icon': Icons.shield_rounded,
        'color': Colors.red,
        'module': '账户与安全',
        'keywords': ['账号', '安全', '登录设备'],
        'action': 'scroll',
        'target': '账户与安全',
      },
      {
        'title': '软件版本',
        'description': '点击检查更新',
        'icon': Icons.info_rounded,
        'color': Colors.teal,
        'module': '关于',
        'keywords': ['版本', '更新', '软件'],
        'action': 'scroll',
        'target': '关于',
      },
      {
        'title': '意见反馈',
        'description': '问题描述与联系方式',
        'icon': Icons.feedback_outlined,
        'color': Colors.deepOrange,
        'module': '关于',
        'keywords': ['反馈', '问题', '建议', 'bug'],
        'action': 'scroll',
        'target': '关于',
      },
      {
        'title': '用户协议',
        'description': '查看用户协议和隐私政策',
        'icon': Icons.description_rounded,
        'color': Colors.grey,
        'module': '关于',
        'keywords': ['协议', '条款', '隐私政策'],
        'action': 'scroll',
        'target': '关于',
      },
    ];
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
            _navigateToSettingItem(result);
          },
        ),
      ),
    );
  }

  void _navigateToSettingItem(Map<String, dynamic> item) {
    final action = item['action'] as String?;
    final target = item['target'] as String?;
    if (action == null || target == null) return;

    if (action == 'route') {
      Navigator.pushNamed(context, target);
      return;
    }
    if (action == 'scroll') {
      _scrollToModule(target);
    }
  }

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 模块滚动位置映射
  final Map<String, GlobalKey> _moduleKeys = {
    '账户与安全': GlobalKey(),
    '外观': GlobalKey(),
    '常规设置': GlobalKey(),
    '设备与存储': GlobalKey(),
    'AI 模型': GlobalKey(),
    '关于': GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToModule(String moduleName) {
    _onClearSearch();
    
    // 使用 ScrollController 实现精确滚动
    final key = _moduleKeys[moduleName];
    if (key != null) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  List<Widget> _buildNormalSettings() {
    final avatarProvider = Provider.of<VirtualAvatarProvider>(context);

    return [
      _buildExperienceDashboard(avatarProvider),
      const SizedBox(height: 14),
      _buildQuickActionGrid(),
      const SizedBox(height: 24),
      _buildSectionTitle('账户与安全', key: _moduleKeys['账户与安全']),
      const AccountSecurityModule(),

      const SizedBox(height: 24),
      _buildSectionTitle('外观', key: _moduleKeys['外观']),
      const AppearanceModule(),

      const SizedBox(height: 24),
      _buildSectionTitle('常规设置', key: _moduleKeys['常规设置']),
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
              activeThumbColor: const Color(0xFF7F7FD5),
              onChanged: (bool value) async {
                setState(() {
                  _notificationsEnabled = value;
                });
                if (!mounted) return;
                
                // 显示操作结果反馈
                MoeToast.info(context, value ? '通知已开启' : '通知已关闭');
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      FadeInUp(
        delay: const Duration(milliseconds: 120),
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
                color: const Color(0xFF7F7FD5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Color(0xFF7F7FD5), size: 20),
            ),
            title: const Text('虚拟助手',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              avatarProvider.enabled ? '已开启，可点击进入自定义' : '默认关闭，点击进入设置',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: avatarProvider.enabled,
                  activeThumbColor: const Color(0xFF7F7FD5),
                  onChanged: (bool value) async {
                    await avatarProvider.setEnabled(value);
                    if (!mounted) return;
                    MoeToast.info(context, value ? '虚拟助手已开启' : '虚拟助手已关闭');
                  },
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(context, '/virtual-avatar-settings');
            },
          ),
        ),
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('设备与存储', key: _moduleKeys['设备与存储']),
      DeviceStorageModule(
        autoUpdateOnLaunch: _autoUpdateOnLaunch,
        onAutoUpdateChanged: (bool value) async {
          setState(() => _autoUpdateOnLaunch = value);
          await StartupUpdatePreferences.setAutoCheckOnLaunch(value);
        },
      ),
      
      const SizedBox(height: 24),
      _buildSectionTitle('AI 模型', key: _moduleKeys['AI 模型']),
      const AiSettingsModule(),

      const SizedBox(height: 24),
      _buildSectionTitle('关于', key: _moduleKeys['关于']),
      const AboutModule(),
    ];
  }

  Widget _buildExperienceDashboard(VirtualAvatarProvider avatarProvider) {
    final summary = <String>[
      _notificationsEnabled ? '通知开启' : '通知关闭',
      avatarProvider.enabled ? '助手开启' : '助手关闭',
      _autoUpdateOnLaunch ? '启动自动检查更新' : '启动不自动检查更新',
    ].join(' · ');

    return FadeInUp(
      delay: const Duration(milliseconds: 60),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F7FD5).withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前体验状态',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12,
                      height: 1.25,
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

  Widget _buildQuickActionGrid() {
    final shortcuts = [
      (
        icon: Icons.shield_rounded,
        title: '账号安全',
        onTap: () => _scrollToModule('账户与安全')
      ),
      (
        icon: Icons.color_lens_rounded,
        title: '外观主题',
        onTap: () => _scrollToModule('外观')
      ),
      (
        icon: Icons.smart_toy_rounded,
        title: '虚拟助手',
        onTap: () => Navigator.pushNamed(context, '/virtual-avatar-settings')
      ),
      (
        icon: Icons.psychology_rounded,
        title: 'AI 模型',
        onTap: () => _scrollToModule('AI 模型')
      ),
    ];

    return FadeInUp(
      delay: const Duration(milliseconds: 80),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: shortcuts.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final item = shortcuts[index];
            return Material(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: const Color(0xFF7F7FD5), size: 20),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444444),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Key? key}) {
    return Padding(
      key: key,
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


