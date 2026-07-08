import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/achievement_hooks.dart';
import '../../utils/validators.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'package:provider/provider.dart';
import '../../providers/loading_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/email_completion_bubble.dart';
import '../../widgets/moe_toast.dart';
import '../../theme/moe_tokens.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  Timer? _emailCompletionDebounce;

  final Color _primaryColor = MoeTokens.primary;
  final ValueNotifier<List<String>> _emailCompletions =
      ValueNotifier<List<String>>(const []);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailTextChanged);
    _emailFocus.addListener(_onEmailFocusChanged);
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
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted || _emailFocus.hasFocus) return;
        if (_emailCompletions.value.isNotEmpty) {
          _emailCompletions.value = const [];
        }
      });
    }
  }

  void _pickEmailSuffix(String picked) {
    if (_emailCompletions.value.isEmpty) return;
    final e = picked.trim();
    if (e.isEmpty) return;
    _emailController.value = TextEditingValue(
      text: e,
      selection: TextSelection.collapsed(offset: e.length),
    );
    _emailCompletions.value = const [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _formKey.currentState?.validate();
    });
  }

  void _syncEmailCompletions() {
    if (!_emailFocus.hasFocus) return;
    final next =
        Validators.emailDomainCompletionCandidates(_emailController.text);
    if (listEquals(_emailCompletions.value, next)) return;
    _emailCompletions.value = next;
  }

  Future<void> _register() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final loadingProvider = context.read<LoadingProvider>();

    await loadingProvider.executeOperation<AuthResult>(
      operation: () => AuthService.register(
        username,
        email,
        password,
      ),
      key: LoadingKeys.register,
      onSuccess: (result) async {
        if (!mounted) return;
        if (!result.success) {
          MoeToast.error(context, result.errorMessage ?? '注册失败，请稍后重试');
          return;
        }
        final moe = result.moeNo;
        if (moe != null && moe.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('你的 Moe 号'),
              content: SelectableText(
                '请妥善保存。可使用该 10 位数字与密码登录：\n\n$moe',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
          if (!mounted) return;
        }
        try {
          context.read<NotificationProvider>().init();
        } catch (_) {}
        final uid = AuthService.currentUser;
        if (uid != null) {
          unawaited(AchievementHooks.ensureReady(uid));
        }
        if (!mounted) return;
        MoeToast.success(context, '欢迎加入 Moe Social！(≧∇≦)/');
        Navigator.pushReplacementNamed(context, '/home');
      },
      onError: (_) {
        if (!mounted) return;
        MoeToast.error(context, '注册异常，请稍后重试');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Stack(
        children: [
          // 顶部返回按钮
          Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60), // 给返回按钮留出空间
                  MoeReveal(
                    duration: const Duration(milliseconds: 800),
                    child: Column(
                      children: [
                        const Text(
                          '创建账号',
                          style: TextStyle(
                            fontSize: MoeTokens.text3xl,
                            fontWeight: FontWeight.w900,
                            color: MoeTokens.titleText,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '开始你的萌系社交之旅',
                          style: TextStyle(
                            fontSize: MoeTokens.textMd,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  MoeReveal(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 800),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          MoeInputField(
                            controller: _usernameController,
                            hintText: '用户名',
                            icon: Icons.person_outline_rounded,
                            validator: Validators.username,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            focusNode: _usernameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_emailFocus),
                          ),
                          const SizedBox(height: 20),
                          ValueListenableBuilder<List<String>>(
                            valueListenable: _emailCompletions,
                            builder: (_, completions, __) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MoeInputField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    hintText: '电子邮箱',
                                    icon: Icons.email_outlined,
                                    validator: completions.isNotEmpty
                                        ? (_) => null
                                        : Validators.email,
                                    keyboardType: TextInputType.emailAddress,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context)
                                            .requestFocus(_passwordFocus),
                                  ),
                                  EmailSuffixBar(
                                    candidates: completions,
                                    accentColor: _primaryColor,
                                    onSelected: _pickEmailSuffix,
                                  ),
                                  SizedBox(
                                      height: completions.isEmpty ? 20 : 12),
                                ],
                              );
                            },
                          ),
                          MoeInputField(
                            controller: _passwordController,
                            hintText: '设置密码',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            validator: Validators.password,
                            autovalidateMode: AutovalidateMode.disabled,
                            focusNode: _passwordFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_confirmPasswordFocus),
                          ),
                          const SizedBox(height: 20),
                          MoeInputField(
                            controller: _confirmPasswordController,
                            hintText: '确认密码',
                            icon: Icons.lock_reset_rounded,
                            isPassword: true,
                            validator: (value) => Validators.confirmPassword(
                                value, _passwordController.text),
                            autovalidateMode: AutovalidateMode.disabled,
                            focusNode: _confirmPasswordFocus,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: LoadingButton(
                              operationKey: LoadingKeys.register,
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      MoeTokens.radiusButton),
                                ),
                                elevation: 8,
                                shadowColor:
                                    _primaryColor.withValues(alpha: 0.4),
                              ),
                              child: const Text(
                                '立即注册',
                                style: TextStyle(
                                  fontSize: MoeTokens.textLg,
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

                  const SizedBox(height: 30),

                  MoeReveal(
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(milliseconds: 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '已有账户？',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radiusMd),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Text(
                                '直接登录',
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChanged);
    _emailController.removeListener(_onEmailTextChanged);
    _emailCompletionDebounce?.cancel();
    _emailCompletions.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
