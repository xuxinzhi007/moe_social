import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

import '../auth_service.dart';
import '../providers/notification_provider.dart';
import '../providers/virtual_avatar_provider.dart';
import '../services/companion_service.dart';
import '../services/rive_bootstrap.dart';
import '../theme/moe_tokens.dart';
import 'moe_action_row.dart';
import 'moe_toast.dart';
import 'motion/moe_pressable.dart';
import 'motion/moe_reveal.dart';
import 'motion/moe_sheet.dart';

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
  FileLoader? _riveLoader;
  Offset _offset = Offset.zero;
  bool _positionInitialized = false;
  bool _isAssistantPanelOpen = false;
  bool _isActionMenuOpen = false;
  bool _isRoutePushing = false;
  bool _isApplyingHideAction = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  void _ensureRiveLoader() {
    if (_riveLoader != null || kIsWeb) return;
    unawaited(RiveBootstrap.ensureInitialized().then((_) {
      if (!mounted || _riveLoader != null) return;
      setState(() {
        _riveLoader =
            FileLoader.fromAsset(_assetPath, riveFactory: Factory.rive);
      });
    }));
  }

  @override
  void dispose() {
    _riveLoader?.dispose();
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
    Object? arguments,
  }) async {
    if (_isRoutePushing) {
      _showBusyHint();
      return;
    }
    final state = AuthService.navigatorKey.currentState;
    if (state == null) {
      MoeToast.error(context, '当前页面暂时无法跳转，请稍后重试');
      return;
    }
    _isRoutePushing = true;
    if (startMessage != null) {
      MoeToast.info(context, startMessage);
    }
    try {
      await state.pushNamed(routeName, arguments: arguments);
    } finally {
      _isRoutePushing = false;
    }
  }

  bool _ensureLoggedIn(String featureName) {
    if (AuthService.isLoggedIn) return true;
    MoeToast.info(context, '登录后可使用$featureName，先去登录吧');
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
      await MoeSheet.show<void>(
        context,
        builder: (sheetContext) {
          final avatarProvider =
              Provider.of<VirtualAvatarProvider>(context, listen: false);
          final actions = avatarProvider.quickActions;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoeReveal(
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: MoeTokens.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: MoeTokens.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Moe 虚拟助手',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: MoeTokens.titleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const MoeReveal(
                    delay: Duration(milliseconds: 30),
                    child: Text(
                      '这里保留高频操作入口，让交互更顺手，但不过度打扰。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (actions.isEmpty)
                    const MoeReveal(
                      delay: Duration(milliseconds: 60),
                      child: _AssistantEmptyState(),
                    )
                  else
                    MoeReveal(
                      delay: const Duration(milliseconds: 60),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (actions
                              .contains(AvatarQuickActions.notifications))
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
                                CompanionCommunityIdentityData identity;
                                try {
                                  identity = await CompanionService()
                                      .getCommunityIdentity();
                                } catch (e) {
                                  if (!mounted || !sheetContext.mounted) {
                                    return;
                                  }
                                  MoeToast.error(
                                    context,
                                    e
                                        .toString()
                                        .replaceFirst('Exception: ', ''),
                                  );
                                  return;
                                }
                                if (!mounted || !sheetContext.mounted) return;
                                if (!identity.isValid) {
                                  MoeToast.error(context, 'AI 账号信息不完整');
                                  return;
                                }
                                Navigator.pop(sheetContext);
                                await _pushNamed(
                                  '/create-post',
                                  startMessage: '正在进入发布页',
                                  arguments: {
                                    'communityIdentity': identity,
                                  },
                                );
                              },
                            ),
                          if (actions.contains(AvatarQuickActions.greet))
                            _actionChip(
                              icon: Icons.favorite_rounded,
                              label: '打招呼',
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                MoeToast.info(context, '今天也要元气满满');
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
      await MoeSheet.show<void>(
        context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MoeReveal(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Text(
                        '助手显示设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                        ),
                      ),
                    ),
                  ),
                ),
                MoeReveal(
                  delay: const Duration(milliseconds: 30),
                  child: MoeActionRow(
                    icon: Icons.visibility_off_rounded,
                    title: '本次会话隐藏',
                    subtitle: const Text('重新打开 App 后恢复'),
                    iconColor: MoeTokens.primary,
                    showDefaultTrailing: false,
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
                      MoeToast.info(context, '已隐藏，本次会话生效');
                    },
                  ),
                ),
                MoeReveal(
                  delay: const Duration(milliseconds: 60),
                  child: MoeActionRow(
                    icon: Icons.today_rounded,
                    title: '隐藏到今天结束',
                    subtitle: const Text('明天会自动恢复显示'),
                    iconColor: MoeTokens.primary,
                    showDefaultTrailing: false,
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
                ),
                MoeReveal(
                  delay: const Duration(milliseconds: 90),
                  child: MoeActionRow(
                    icon: Icons.settings_rounded,
                    title: '虚拟助手设置',
                    iconColor: MoeTokens.primary,
                    showDefaultTrailing: false,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _pushNamed(
                        '/virtual-avatar-settings',
                        startMessage: '正在打开助手设置',
                      );
                    },
                  ),
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
    return MoePressable(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (_isRoutePushing) {
          _showBusyHint();
          return;
        }
        unawaited(onTap());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MoeTokens.pageBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: MoeTokens.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCore() {
    final loader = _riveLoader;
    if (loader == null) return _fallbackAvatar();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: RiveWidgetBuilder(
        fileLoader: loader,
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
          colors: [MoeTokens.primary, MoeTokens.secondary],
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
    if (kIsWeb) {
      return widget.child;
    }

    final avatarProvider = context.watch<VirtualAvatarProvider>();
    if (!AuthService.isLoggedIn || !avatarProvider.isVisible) {
      return widget.child;
    }

    _ensureRiveLoader();

    final unreadCount =
        context.watch<NotificationProvider>().activityUnreadCount;

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
                            color: MoeTokens.primary.withValues(alpha: 0.28),
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

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: MoeTokens.pageBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '当前还没有可用的快捷动作，去助手设置开启后会展示在这里。',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}
