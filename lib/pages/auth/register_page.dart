import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/achievement_hooks.dart';
import '../../services/api_service.dart' show ApiException;
import '../../services/auth_flow_service.dart';
import '../../utils/validators.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'package:provider/provider.dart';
import '../../providers/loading_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/email_completion_bubble.dart';
import '../../widgets/moe_toast.dart';
import '../../theme/moe_tokens.dart';
import 'dart:ui';
import '../../widgets/motion/moe_pressable.dart';

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
  bool _isGeneratingTempEmail = false;
  bool _hasGeneratedTempEmail = false;
  String? _generatedTempEmail;

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
    final generated = _generatedTempEmail;
    if (generated != null && _emailController.text.trim() != generated) {
      _generatedTempEmail = null;
      if (_hasGeneratedTempEmail && mounted) {
        setState(() => _hasGeneratedTempEmail = false);
      }
    }
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

  Future<void> _generateTempEmail() async {
    if (_isGeneratingTempEmail) return;
    setState(() {
      _isGeneratingTempEmail = true;
      _hasGeneratedTempEmail = false;
      _generatedTempEmail = null;
    });
    try {
      final email = await AuthFlowService.generateTempEmail();
      if (!mounted) return;
      _emailController.value = TextEditingValue(
        text: email,
        selection: TextSelection.collapsed(offset: email.length),
      );
      _emailCompletions.value = const [];
      _formKey.currentState?.validate();
      setState(() {
        _hasGeneratedTempEmail = true;
        _generatedTempEmail = email;
      });
      FocusScope.of(context).requestFocus(_passwordFocus);
      MoeToast.info(context, '临时邮箱已生成，注册成功后记得保存这个邮箱地址');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasGeneratedTempEmail = false;
        _generatedTempEmail = null;
      });
      MoeToast.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasGeneratedTempEmail = false;
        _generatedTempEmail = null;
      });
      MoeToast.error(context, '临时邮箱生成失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTempEmail = false);
      }
    }
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
                    child: _buildHeader(),
                  ),

                  const SizedBox(height: 32),

                  MoeReveal(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 800),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: MoeTokens.blurMedium,
                          sigmaY: MoeTokens.blurMedium,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius:
                                BorderRadius.circular(MoeTokens.radius2xl),
                            border: Border.all(
                                color: MoeTokens.surfaceBorder, width: 1),
                            boxShadow: MoeTokens.shadowCard(),
                          ),
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
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context)
                                          .requestFocus(_emailFocus),
                                ),
                                const SizedBox(height: 20),
                                ValueListenableBuilder<List<String>>(
                                  valueListenable: _emailCompletions,
                                  builder: (_, completions, __) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        MoeInputField(
                                          controller: _emailController,
                                          focusNode: _emailFocus,
                                          maxLines: 1,
                                          hintText: '电子邮箱',
                                          icon: Icons.email_outlined,
                                          suffixIcon: _TempMailButton(
                                            isLoading: _isGeneratingTempEmail,
                                            onTap: _generateTempEmail,
                                            accentColor: _primaryColor,
                                          ),
                                          validator: completions.isNotEmpty
                                              ? (_) => null
                                              : Validators.email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
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
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          child: _hasGeneratedTempEmail
                                              ? Container(
                                                  key: const ValueKey(
                                                      'temp-mail-hint'),
                                                  margin: const EdgeInsets.only(
                                                      top: 10),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _primaryColor
                                                        .withValues(
                                                            alpha: 0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      MoeTokens.radiusLg,
                                                    ),
                                                    border: Border.all(
                                                      color: _primaryColor
                                                          .withValues(
                                                              alpha: 0.18),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .mark_email_read_rounded,
                                                        size: 18,
                                                        color: _primaryColor,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          '已为你填入临时邮箱。完成注册后请保存该邮箱，后续收验证码或回查会更方便。',
                                                          style: TextStyle(
                                                            fontSize: MoeTokens
                                                                .textSm,
                                                            height: 1.45,
                                                            color: MoeTokens
                                                                .bodyText,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                        SizedBox(
                                            height:
                                                completions.isEmpty ? 20 : 12),
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
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context)
                                          .requestFocus(_confirmPasswordFocus),
                                ),
                                const SizedBox(height: 20),
                                MoeInputField(
                                  controller: _confirmPasswordController,
                                  hintText: '确认密码',
                                  icon: Icons.lock_reset_rounded,
                                  isPassword: true,
                                  validator: (value) =>
                                      Validators.confirmPassword(
                                          value, _passwordController.text),
                                  autovalidateMode: AutovalidateMode.disabled,
                                  focusNode: _confirmPasswordFocus,
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 20),
                                _buildGradientRegisterButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  MoeReveal(
                    delay: const Duration(milliseconds: 400),
                    duration: const Duration(milliseconds: 800),
                    child: _buildLoginPrompt(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 标题区域 — 渐变文字 ────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              MoeTokens.gradientText.createShader(bounds),
          child: const Text(
            '创建账号',
            style: TextStyle(
              fontSize: MoeTokens.text3xl,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) =>
              MoeTokens.gradientSoft.createShader(bounds),
          child: Text(
            '开始你的萌系社交之旅',
            style: TextStyle(
              fontSize: MoeTokens.textMd,
              color: Colors.white,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 渐变注册按钮 ────────────────────────────────────────────────
  Widget _buildGradientRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: MoePressable(
        onTap: _register,
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
        child: Consumer<LoadingProvider>(
          builder: (context, loadingProvider, _) {
            final isLoading =
                loadingProvider.isOperationLoading(LoadingKeys.register);
            return Container(
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientPrimary,
                borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                boxShadow:
                    isLoading ? null : MoeTokens.shadowGlow(_primaryColor),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : _register,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                  child: Center(
                    child: isLoading
                        ? const MoeSmallLoading(
                            size: 22,
                            color: Colors.white,
                          )
                        : const Text(
                            '立即注册',
                            style: TextStyle(
                              fontSize: MoeTokens.textLg,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 底部登录引导 — 渐变分隔线 + 渐变文字 ──────────────────────────
  Widget _buildLoginPrompt() {
    return Column(
      children: [
        const _GradientDivider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '已有账户？',
              style: TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textBase,
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        MoeTokens.gradientPrimary.createShader(bounds),
                    child: const Text(
                      '直接登录',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: MoeTokens.textBase,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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

/// 渐变淡出分隔线 — 左透明 → 中间灰 → 右透明。
class _GradientDivider extends StatelessWidget {
  const _GradientDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            MoeTokens.hintText.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _TempMailButton extends StatelessWidget {
  const _TempMailButton({
    required this.isLoading,
    required this.onTap,
    required this.accentColor,
  });

  final bool isLoading;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isLoading ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.22),
                ),
              ),
              child: isLoading
                  ? MoeSmallLoading(
                      size: 14,
                      color: accentColor,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '临邮',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: MoeTokens.textXs,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
