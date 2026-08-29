import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/notification_preferences.dart';
import '../../services/startup_update_preferences.dart';
import '../../providers/device_info_provider.dart';

import '../../widgets/moe_menu_card.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/settings/settings_search_bar.dart';
import '../../providers/virtual_avatar_provider.dart';
import 'modules/device_storage_module.dart';
import 'modules/account_security_module.dart';
import 'modules/about_module.dart';
import 'message_retention_settings_page.dart';
import 'widgets/settings_advanced_section.dart';

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
      unawaited(_loadNotificationPref());
    });
  }

  Future<void> _loadNotificationPref() async {
    final enabled = await NotificationPreferences.getEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
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
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            fontWeight: MoeTokens.fontWeightTitle,
            color: MoeTokens.titleText,
          ),
        ),
        backgroundColor: MoeTokens.surface1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: MoeTokens.surfaceBorder),
        ),
      ),
      body: Column(
        children: [
          // 在Web平台上，搜索栏的样式和布局可能需要调整
          if (isWeb)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: MoeTokens.surface1,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  border: Border.all(color: MoeTokens.surfaceBorder),
                ),
                child: TextField(
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: '搜索设置',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: MoeTokens.hintText,
                    ),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: MoeTokens.hintText,
                            ),
                            onPressed: () {
                              _onClearSearch();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
              const Icon(
                Icons.search_off,
                size: 64,
                color: MoeTokens.hintText,
              ),
              const SizedBox(height: 16),
              Text(
                '未找到与「$_searchQuery」相关的设置',
                style: const TextStyle(color: MoeTokens.hintText),
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
                  color: MoeTokens.titleText,
                  fontSize: MoeTokens.textMd,
                  fontWeight: MoeTokens.fontWeightSubtitle,
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
        'module': '账号与隐私',
        'keywords': ['通知', '消息', '提醒', 'push'],
        'action': 'scroll',
        'target': '账号与隐私',
      },
      {
        'title': 'AI 助手',
        'description': '管理社区 AI 账号与悬浮助手入口',
        'icon': Icons.smart_toy_rounded,
        'color': Colors.deepPurple,
        'module': 'AI 与助手',
        'keywords': ['ai', '助手', '社区ai', 'bot', '标签', '悬浮'],
        'action': 'scroll',
        'target': 'AI 与助手',
      },
      {
        'title': '社区 AI 设置',
        'description': '统一管理 AI 账号、悬浮入口与社区互动形态',
        'icon': Icons.tune_rounded,
        'color': Colors.deepPurpleAccent,
        'module': 'AI 与助手',
        'keywords': ['社区ai', 'bot', '动态', '评论', '发帖', '设置'],
        'action': 'route',
        'target': '/virtual-avatar-settings',
      },
      {
        'title': '启动时检查更新',
        'description': '打开应用时自动检查新版本',
        'icon': Icons.system_update_alt_rounded,
        'color': Colors.blue,
        'module': '设备与数据',
        'keywords': ['更新', '启动', '自动更新', '版本'],
        'action': 'scroll',
        'target': '设备与数据',
      },
      {
        'title': '本机设备信息',
        'description': '查看设备ID、系统版本、网络状态等',
        'icon': Icons.phone_iphone_rounded,
        'color': Colors.blueGrey,
        'module': '设备与数据',
        'keywords': ['设备', '系统', '版本', '网络', 'ID'],
        'action': 'scroll',
        'target': '设备与数据',
      },
      {
        'title': '清理缓存',
        'description': '释放本应用临时文件',
        'icon': Icons.cleaning_services_rounded,
        'color': Colors.amber,
        'module': '设备与数据',
        'keywords': ['缓存', '清理', '存储', '空间'],
        'action': 'scroll',
        'target': '设备与数据',
      },
      {
        'title': '模型记忆线',
        'description': '查看模型记录的所有记忆',
        'icon': Icons.psychology_rounded,
        'color': Colors.deepPurple,
        'module': '高级选项',
        'keywords': ['记忆', 'ai', '模型', '上下文'],
        'action': 'scroll',
        'target': '高级选项',
      },
      {
        'title': '飞书通知',
        'description': '企业内机器人推送（可选）',
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFF3370FF),
        'module': '高级选项',
        'keywords': ['飞书', '企业', '通知'],
        'action': 'scroll',
        'target': '高级选项',
      },
      {
        'title': '修改密码',
        'description': '修改账户登录密码',
        'icon': Icons.lock_rounded,
        'color': Colors.blue,
        'module': '账号与隐私',
        'keywords': ['密码', '安全', '账户'],
        'action': 'scroll',
        'target': '账号与隐私',
      },
      {
        'title': '隐私设置',
        'description': '管理应用权限和隐私设置',
        'icon': Icons.privacy_tip_rounded,
        'color': Colors.green,
        'module': '账号与隐私',
        'keywords': ['隐私', '权限', '安全'],
        'action': 'scroll',
        'target': '账号与隐私',
      },
      {
        'title': '私信记录保留',
        'description': '发送方私信在服务端保留天数偏好',
        'icon': Icons.mark_chat_unread_outlined,
        'color': Colors.teal,
        'module': '账号与隐私',
        'keywords': ['私信', '聊天记录', '保留', '删除', '消息'],
        'action': 'route',
        'target': '/message-retention-settings',
      },
      {
        'title': '账号安全',
        'description': '查看登录记录与密码管理',
        'icon': Icons.shield_rounded,
        'color': Colors.red,
        'module': '账号与隐私',
        'keywords': ['账号', '安全', '登录记录', '密码'],
        'action': 'scroll',
        'target': '账号与隐私',
      },
      {
        'title': '注销账号',
        'description': '永久删除账号与登录绑定',
        'icon': Icons.person_off_rounded,
        'color': Colors.red,
        'module': '账号与隐私',
        'keywords': ['注销', '删除账号', '销号', '账号'],
        'action': 'scroll',
        'target': '账号与隐私',
      },
      {
        'title': '软件版本',
        'description': '点击检查更新',
        'icon': Icons.info_rounded,
        'color': Colors.teal,
        'module': '关于与支持',
        'keywords': ['版本', '更新', '软件'],
        'action': 'scroll',
        'target': '关于与支持',
      },
      {
        'title': '访问官网',
        'description': '了解 Moe Social 产品介绍与最新信息',
        'icon': Icons.language_rounded,
        'color': MoeTokens.primary,
        'module': '关于与支持',
        'keywords': ['官网', '网站', '主页', '介绍', 'moe social'],
        'action': 'scroll',
        'target': '关于与支持',
      },
      {
        'title': '意见反馈',
        'description': '问题描述与联系方式',
        'icon': Icons.feedback_outlined,
        'color': Colors.deepOrange,
        'module': '关于与支持',
        'keywords': ['反馈', '问题', '建议', 'bug'],
        'action': 'scroll',
        'target': '关于与支持',
      },
      {
        'title': '用户协议',
        'description': '查看用户协议和隐私政策',
        'icon': Icons.description_rounded,
        'color': Colors.grey,
        'module': '关于与支持',
        'keywords': ['协议', '条款', '隐私政策'],
        'action': 'scroll',
        'target': '关于与支持',
      },
    ];
  }

  Map<String, List<Map<String, dynamic>>> _categorizeSearchResults(
      List<Map<String, dynamic>> results) {
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
    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: result['icon'] as IconData,
          title: result['title'] as String,
          subtitle: result['description'] as String,
          color: result['color'] as Color,
          onTap: () => _navigateToSettingItem(result),
        ),
      ],
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
    '账号与隐私': GlobalKey(),
    'AI 与助手': GlobalKey(),
    '设备与数据': GlobalKey(),
    '高级选项': GlobalKey(),
    '关于与支持': GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToModule(String moduleName) {
    _onClearSearch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final key = _moduleKeys[moduleName];
      if (key == null) {
        return;
      }
      final targetContext = key.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  List<Widget> _buildNormalSettings() {
    final avatarProvider = Provider.of<VirtualAvatarProvider>(context);

    return [
      MoeReveal(
        delay: Duration.zero,
        child: _buildExperienceDashboard(avatarProvider),
      ),
      const SizedBox(height: 24),
      MoeReveal(
        delay: const Duration(milliseconds: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('账号与隐私', key: _moduleKeys['账号与隐私']),
            const AccountSecurityModule(),
            MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.campaign_outlined,
                  title: '系统公告',
                  subtitle: '查看运营发布的平台公告',
                  color: MoeTokens.primary,
                  onTap: () => Navigator.pushNamed(context, '/announcements'),
                ),
                MoeMenuItem(
                  icon: Icons.mark_chat_unread_outlined,
                  title: '私信记录保留',
                  subtitle: '发送方在服务端保留策略（与会员/VIP 规则配合）',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const MessageRetentionSettingsPage(),
                      ),
                    );
                  },
                ),
                MoeMenuItem(
                  icon: Icons.notifications_active_rounded,
                  title: '推送通知',
                  subtitle: '接收最新动态和系统通知',
                  color: Colors.orange,
                  trailing: Switch.adaptive(
                    value: _notificationsEnabled,
                    activeThumbColor: MoeTheme.of(context).primary,
                    onChanged: (bool value) => _onNotificationToggle(value),
                  ),
                  onTap: () => _onNotificationToggle(!_notificationsEnabled),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      MoeReveal(
        delay: const Duration(milliseconds: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('AI 与助手', key: _moduleKeys['AI 与助手']),
            MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.smart_toy_rounded,
                  title: 'AI 助手与社区 AI',
                  subtitle: avatarProvider.enabled
                      ? '已启用悬浮助手入口，可继续配置社区 AI 账号形态'
                      : '统一管理社区 AI 账号与悬浮助手入口',
                  color: MoeTheme.of(context).primary,
                  trailing: Switch.adaptive(
                    value: avatarProvider.enabled,
                    activeThumbColor: MoeTheme.of(context).primary,
                    onChanged: (bool value) async {
                      await avatarProvider.setEnabled(value);
                      if (!mounted) return;
                      MoeToast.info(
                          context, value ? 'AI 助手入口已开启' : 'AI 助手入口已关闭');
                    },
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/virtual-avatar-settings');
                  },
                ),
                MoeMenuItem(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI 伙伴设置',
                  subtitle: '管理主动陪伴、免打扰时间和伙伴消息',
                  color: MoeTokens.secondary,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/companion-settings',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      MoeReveal(
        delay: const Duration(milliseconds: 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('设备与数据', key: _moduleKeys['设备与数据']),
            DeviceStorageModule(
              autoUpdateOnLaunch: _autoUpdateOnLaunch,
              onAutoUpdateChanged: (bool value) async {
                setState(() => _autoUpdateOnLaunch = value);
                await StartupUpdatePreferences.setAutoCheckOnLaunch(value);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      MoeReveal(
        delay: const Duration(milliseconds: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('高级选项', key: _moduleKeys['高级选项']),
            const SettingsAdvancedSection(),
          ],
        ),
      ),
      const SizedBox(height: 24),
      MoeReveal(
        delay: const Duration(milliseconds: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('关于与支持', key: _moduleKeys['关于与支持']),
            const AboutModule(),
          ],
        ),
      ),
    ];
  }

  Future<void> _onNotificationToggle(bool value) async {
    final ok = await NotificationPreferences.setEnabled(value);
    if (!mounted) {
      return;
    }
    if (value && !ok) {
      MoeToast.error(context, '未获得通知权限，请在系统设置中允许通知');
      return;
    }
    setState(() => _notificationsEnabled = value);
    MoeToast.info(context, value ? '通知已开启' : '通知已关闭');
  }

  Widget _buildExperienceDashboard(VirtualAvatarProvider avatarProvider) {
    final summary = <String>[
      _notificationsEnabled ? '通知开启' : '通知关闭',
      avatarProvider.enabled ? '助手开启' : '助手关闭',
      _autoUpdateOnLaunch ? '启动自动检查更新' : '启动不自动检查更新',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _scrollToModule('账号与隐私'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MoeTokens.primary, MoeTokens.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MoeTokens.primary.withValues(alpha: 0.22),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.92),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: MoeTokens.titleText,
          fontSize: MoeTokens.textMd,
          fontWeight: MoeTokens.fontWeightSubtitle,
        ),
      ),
    );
  }
}
