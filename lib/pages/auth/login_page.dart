import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/achievement_hooks.dart';
import '../../utils/validators.dart';
import 'forgot_password_page.dart';
import '../../widgets/fade_in_up.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/email_completion_bubble.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  Timer? _emailCompletionDebounce;

  final Color _primaryColor = const Color(0xFF7F7FD5);
  final ValueNotifier<List<String>> _emailCompletions =
      ValueNotifier<List<String>>(const []);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailTextChanged);
    _emailFocus.addListener(_onEmailFocusChanged);
    _prefillLastAccount();
  }

  void _onEmailTextChanged() {
    _emailCompletionDebounce?.cancel();
    _emailCompletionDebounce = Timer(
      const Duration(milliseconds: 100),
      _syncEmailCompletions,
    );
  }

  void _onEmailFocusChanged() {
    if (!mounted) return;
    if (_emailFocus.hasFocus) {
      _syncEmailCompletions();
    } else {
      _emailCompletionDebounce?.cancel();
      // 延迟收起：在输入框外点气泡时，须等 chip 的 onTap 跑完再清列表。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _emailFocus.hasFocus) return;
        if (_emailCompletions.value.isNotEmpty) {
          _emailCompletions.value = const [];
        }
      });
    }
  }

  void _syncEmailCompletions() {
    if (!_emailFocus.hasFocus) return;
    final next =
        Validators.emailDomainCompletionCandidates(_emailController.text);
    if (listEquals(_emailCompletions.value, next)) return;
    _emailCompletions.value = next;
  }

  /// 仅预填「上次登录成功」保存的账号，失败登录不会写入本地
  Future<void> _prefillLastAccount() async {
    final acc = await AuthService.getLastLoginAccount();
    if (!mounted || acc == null || acc.isEmpty) return;
    _emailController.text = acc;
  }

  Future<void> _login() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    final account = _emailController.text.trim();
    final password = _passwordController.text;

    final loadingProvider = context.read<LoadingProvider>();

    await loadingProvider.executeOperation<AuthResult>(
      operation: () => AuthService.login(
        account,
        password,
      ),
      key: LoadingKeys.login,
      onSuccess: (result) {
        if (!mounted) return;
        if (!result.success) {
          MoeToast.error(context, result.errorMessage ?? '登录失败，请稍后重试');
          return;
        }
        try {
          context.read<NotificationProvider>().init();
        } catch (_) {}
        final uid = AuthService.currentUser;
        if (uid != null) {
          unawaited(AchievementHooks.ensureReady(uid));
        }
        MoeToast.success(context, '欢迎回来！(｡♥♥｡)');
        Navigator.pushReplacementNamed(context, '/home');
      },
      onError: (_) {
        if (!mounted) return;
        MoeToast.error(context, '登录异常，请稍后重试');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo 区域
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 64,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Moe Social',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF333333),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '发现更可爱的世界',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[500],
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 表单区域
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 800),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 气泡放在整列之上绘制，避免被下方密码框盖住。
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MoeInputField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                hintText: '邮箱或 10 位 Moe 号',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.loginAccount,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () =>
                                    FocusScope.of(context)
                                        .requestFocus(_passwordFocus),
                              ),
                              const SizedBox(height: 20),
                              MoeInputField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                hintText: '密码',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: Validators.password,
                                autovalidateMode: AutovalidateMode.disabled,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: () =>
                                    unawaited(_login()),
                              ),
                            ],
                          ),
                          ValueListenableBuilder<List<String>>(
                            valueListenable: _emailCompletions,
                            builder: (_, completions, __) {
                              if (completions.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                left: 4,
                                right: 4,
                                top: 56,
                                child: EmailCompletionBubble(
                                  candidates: completions,
                                  accentColor: _primaryColor,
                                  onSelected: (picked) {
                                    final e = picked.trim();
                                    if (e.isEmpty) return;
                                    _emailController.value = TextEditingValue(
                                      text: e,
                                      selection: TextSelection.collapsed(
                                          offset: e.length),
                                    );
                                    _emailCompletions.value = const [];
                                    // 下一帧再校验 / 移焦点，避免与失焦、Scroll 手势抢同一帧。
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      _formKey.currentState?.validate();
                                      FocusScope.of(context)
                                          .requestFocus(_passwordFocus);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[400],
                          ),
                          child: const Text('忘记密码？'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: LoadingButton(
                          operationKey: LoadingKeys.login,
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 8,
                            shadowColor: _primaryColor.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            '登 录',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 底部注册引导
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 800),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '还没有账号？',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            '立即注册',
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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


  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChanged);
    _emailController.removeListener(_onEmailTextChanged);
    _emailCompletionDebounce?.cancel();
    _emailCompletions.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
