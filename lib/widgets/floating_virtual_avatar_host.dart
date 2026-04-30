import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

import '../auth_service.dart';
import '../providers/notification_provider.dart';
import '../providers/virtual_avatar_provider.dart';
import 'moe_toast.dart';

class FloatingVirtualAvatarHost extends StatefulWidget {
  const FloatingVirtualAvatarHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<FloatingVirtualAvatarHost> createState() =>
      _FloatingVirtualAvatarHostState();
}

class _FloatingVirtualAvatarHostState extends State<FloatingVirtualAvatarHost>
    with SingleTickerProviderStateMixin {
  static const String _assetPath = 'assets/avatars/moe_assistant.riv';
  static const double _avatarSize = 74;

  late final AnimationController _floatController;
  late final FileLoader _riveLoader;
  Offset _offset = Offset.zero;
  bool _positionInitialized = false;
  bool _isAssistantPanelOpen = false;
  bool _isActionMenuOpen = false;
  bool _isRoutePushing = false;
  bool _isApplyingHideAction = false;

  @override
  void initState() {
    super.initState();
    _riveLoader =
        FileLoader.fromAsset(_assetPath, riveFactory: Factory.rive);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _riveLoader.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _ensureInitialPosition(Size size) {
    if (_positionInitialized) return;
    _positionInitialized = true;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    _offset = Offset(
      size.width - _avatarSize - 16,
      size.height - _avatarSize - 96 - bottomSafe,
    );
  }

  void _snapToEdge(Size size) {
    final x = _offset.dx;
    final left = 12.0;
    final right = size.width - _avatarSize - 12;
    final targetX = x < size.width / 2 ? left : right;
    setState(() {
      _offset = Offset(
        targetX,
        _offset.dy.clamp(86.0, size.height - _avatarSize - 92.0),
      );
    });
  }

  void _showBusyHint() {
    MoeToast.info(context, '操作进行中，请稍候');
  }

  Future<void> _pushNamed(
    String routeName, {
    String? startMessage,
  }) async {
    if (_isRoutePushing) {
      _showBusyHint();
      return;
    }
    final state = AuthService.navigatorKey.currentState;
    if (state == null) {
      MoeToast.error(context, '当前页面暂不可跳转，请稍后重试');
      return;
    }
    _isRoutePushing = true;
    if (startMessage != null) {
      MoeToast.info(context, startMessage);
    }
    try {
      await state.pushNamed(routeName);
    } finally {
      _isRoutePushing = false;
    }
  }

  bool _ensureLoggedIn(String featureName) {
    if (AuthService.isLoggedIn) return true;
    MoeToast.info(context, '登录后可使用$featureName，快去登录吧');
    return false;
  }

  Future<void> _showAssistantPanel() async {
    if (_isAssistantPanelOpen) {
      _showBusyHint();
      return;
    }
    HapticFeedback.lightImpact();
    _isAssistantPanelOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final avatarProvider =
              Provider.of<VirtualAvatarProvider>(context, listen: false);
          final actions = avatarProvider.quickActions;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F7FD5).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFF7F7FD5), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Moe 虚拟助手（MVP）',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (actions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '当前没有可用快捷动作，去助手设置开启后会展示在这里。',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (actions.contains(AvatarQuickActions.notifications))
                          _actionChip(
                            icon: Icons.notifications_active_rounded,
                            label: '通知中心',
                            onTap: () async {
                              if (!_ensureLoggedIn('通知中心')) return;
                              Navigator.pop(sheetContext);
                              await _pushNamed(
                                '/notifications',
                                startMessage: '正在打开通知中心',
                              );
                            },
                          ),
                        if (actions.contains(AvatarQuickActions.createPost))
                          _actionChip(
                            icon: Icons.edit_note_rounded,
                            label: '发布动态',
                            onTap: () async {
                              if (!_ensureLoggedIn('发布动态')) return;
                              Navigator.pop(sheetContext);
                              await _pushNamed(
                                '/create-post',
                                startMessage: '正在进入发布页',
                              );
                            },
                          ),
                        if (actions.contains(AvatarQuickActions.greet))
                          _actionChip(
                            icon: Icons.favorite_rounded,
                            label: '打招呼',
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              MoeToast.info(context, '嗨～今天也要元气满满呀');
                            },
                          ),
                        if (actions.contains(AvatarQuickActions.checkin))
                          _actionChip(
                            icon: Icons.event_available_rounded,
                            label: '去签到',
                            onTap: () async {
                              if (!_ensureLoggedIn('签到')) return;
                              Navigator.pop(sheetContext);
                              await _pushNamed(
                                '/checkin',
                                startMessage: '正在前往签到',
                              );
                            },
                          ),
                        _actionChip(
                          icon: Icons.tune_rounded,
                          label: '助手设置',
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _pushNamed(
                              '/virtual-avatar-settings',
                              startMessage: '正在打开助手设置',
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _isAssistantPanelOpen = false;
    }
  }

  Future<void> _showAvatarActionMenu() async {
    if (_isActionMenuOpen) {
      _showBusyHint();
      return;
    }
    HapticFeedback.mediumImpact();
    final avatar = Provider.of<VirtualAvatarProvider>(context, listen: false);
    _isActionMenuOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_off_rounded),
                  title: const Text('本次会话隐藏'),
                  subtitle: const Text('重新打开 App 后恢复'),
                  onTap: () {
                    if (_isApplyingHideAction) {
                      _showBusyHint();
                      return;
                    }
                    _isApplyingHideAction = true;
                    Navigator.pop(ctx);
                    try {
                      avatar.hideForSession();
                    } finally {
                      _isApplyingHideAction = false;
                    }
                    MoeToast.info(context, '已隐藏（本次会话）');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.today_rounded),
                  title: const Text('隐藏到今天结束'),
                  subtitle: const Text('明天会自动恢复显示'),
                  onTap: () async {
                    if (_isApplyingHideAction) {
                      _showBusyHint();
                      return;
                    }
                    _isApplyingHideAction = true;
                    Navigator.pop(ctx);
                    try {
                      await avatar.hideForToday();
                    } finally {
                      _isApplyingHideAction = false;
                    }
                    if (!mounted) return;
                    MoeToast.info(context, '已隐藏到今天结束');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('虚拟助手设置'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pushNamed(
                      '/virtual-avatar-settings',
                      startMessage: '正在打开助手设置',
                    );
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isActionMenuOpen = false;
    }
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (_isRoutePushing) {
            _showBusyHint();
            return;
          }
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF7F7FD5)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCore() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: RiveWidgetBuilder(
        fileLoader: _riveLoader,
        builder: (context, state) {
          return switch (state) {
            RiveLoaded() => RiveWidget(
                controller: state.controller,
                fit: Fit.cover,
              ),
            RiveFailed() => _fallbackAvatar(),
            _ => _fallbackAvatar(),
          };
        },
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = context.watch<VirtualAvatarProvider>();
    if (!AuthService.isLoggedIn || !avatarProvider.isVisible) return widget.child;

    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _ensureInitialPosition(size);

        final dy = Tween<double>(begin: -2, end: 3).evaluate(
          CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
        );

        return Stack(
          children: [
            widget.child,
            Positioned(
              left: _offset.dx,
              top: _offset.dy + dy,
              child: GestureDetector(
                onTap: _showAssistantPanel,
                onLongPress: _showAvatarActionMenu,
                onPanUpdate: (details) {
                  final next = _offset + details.delta;
                  setState(() {
                    _offset = Offset(
                      next.dx.clamp(8.0, size.width - _avatarSize - 8.0),
                      next.dy.clamp(72.0, size.height - _avatarSize - 88.0),
                    );
                  });
                },
                onPanEnd: (_) => _snapToEdge(size),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: _avatarSize,
                      height: _avatarSize,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF7F7FD5).withValues(alpha: 0.28),
                            blurRadius: unreadCount > 0 ? 24 : 14,
                            offset: const Offset(0, 7),
                          ),
                        ],
                        border: Border.all(
                          color: unreadCount > 0
                              ? const Color(0xFFFF6B6B)
                              : Colors.white,
                          width: unreadCount > 0 ? 2.2 : 1.5,
                        ),
                        color: Colors.white,
                      ),
                      child: _buildAvatarCore(),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D6D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
