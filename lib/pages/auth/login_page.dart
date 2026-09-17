import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/auth_flow_service.dart';
import '../../services/achievement_hooks.dart';
import '../../utils/validators.dart';
import 'forgot_password_page.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/email_completion_bubble.dart';
import '../../widgets/feishu_enterprise_invite_banner.dart';
import '../../utils/oauth_app_launcher.dart';
import '../../utils/oauth_flow_helper.dart';
import '../../utils/oauth_web_history.dart';
import 'feishu_login_page.dart';
import 'feishu_login_result.dart';
import '../../services/daily_growth_service.dart';
import '../../services/oauth_begin.dart';
import '../../services/oauth_pending_store.dart';
import '../../services/wechat_sdk_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../utils/moe_error_copy.dart';

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

  final Color _primaryColor = MoeTokens.primary;
  final ValueNotifier<List<String>> _emailCompletions =
      ValueNotifier<List<String>>(const []);
  StreamSubscription<Uri>? _feishuLinkSub;
  StreamSubscription<Uri>? _wechatLinkSub;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailTextChanged);
    _emailFocus.addListener(_onEmailFocusChanged);
    _prefillLastAccount();
    if (!kIsWeb) {
      _feishuLinkSub = OAuthAppLauncher.uriLinkStream.listen((uri) {
        if (!isFeishuOAuthReturnUri(uri)) return;
        unawaited(
          _completeFromCallback(
            OauthBeginService.feishu,
            OauthCallback.fromUri(uri),
          ),
        );
      });
      _wechatLinkSub = OAuthAppLauncher.uriLinkStream.listen((uri) {
        if (!isWechatOAuthReturnUri(uri)) return;
        unawaited(
          _completeFromCallback(
            OauthBeginService.wechat,
            OauthCallback.fromUri(uri),
          ),
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        unawaited(_resumeOAuthFromBrowserUrl());
      } else {
        unawaited(_resumeFeishuOAuthFromDeepLink());
        unawaited(_resumeWechatOAuthFromDeepLink());
      }
    });
  }

  static const String _noPendingAuthMessage = '未找到本次授权记录，请重新登录。\n'
      '常见原因：授权已超时，或授权是在别的标签页 / 别的设备上发起的。';

  /// Web：服务端 302 回当前页并带上 `oauth_ticket` / `oauth_state`。
  ///
  /// 回跳参数里不含 provider —— 两家用的是同一对参数名，靠本地待处理事务的
  /// state 认领。这同时保证了「本页没发起过授权」的回跳被拒绝，
  /// 而不是拿着别人递来的 ticket 去登录。
  Future<void> _resumeOAuthFromBrowserUrl() async {
    final callback = OauthCallback.fromCurrentBrowserUrl();
    if (callback == null || !callback.isValid) return;
    // 先把参数从地址栏抹掉：ticket 是一次性的，留在 URL 上只会被刷新或分享带走。
    clearOAuthParamsFromBrowserUrl();

    for (final provider in [
      OauthBeginService.feishu,
      OauthBeginService.wechat,
    ]) {
      final pending =
          await OauthPendingStore.takeForState(provider, callback.state);
      if (pending != null) {
        await _completeOAuthLogin(pending, callback.ticket);
        return;
      }
    }
    if (mounted) {
      MoeToast.error(context, _noPendingAuthMessage);
    }
  }

  /// App：飞书授权后服务端 302 到 `moesocial://feishu/oauth?oauth_ticket=…`。
  Future<void> _resumeFeishuOAuthFromDeepLink() async {
    final uri =
        await OAuthAppLauncher.getInitialOAuthUri(isFeishuOAuthReturnUri);
    await _completeFromCallback(
      OauthBeginService.feishu,
      OauthCallback.fromUri(uri),
    );
  }

  /// App：微信浏览器 flow（扫码 / 公众号）授权后 302 到 `moesocial://wechat/oauth`。
  Future<void> _resumeWechatOAuthFromDeepLink() async {
    final uri =
        await OAuthAppLauncher.getInitialOAuthUri(isWechatOAuthReturnUri);
    await _completeFromCallback(
      OauthBeginService.wechat,
      OauthCallback.fromUri(uri),
    );
  }

  /// 核对 state 并取出本地事务；对不上就静默返回。
  ///
  /// deep link 能被任何 App 触发，冷启动时也总会走一遍，
  /// 所以「没有匹配事务」是常态而不是错误 —— 只有 Web 那条路径才需要提示用户。
  Future<void> _completeFromCallback(
    String provider,
    OauthCallback? callback,
  ) async {
    if (callback == null || !callback.isValid) return;
    final pending =
        await OauthPendingStore.takeForState(provider, callback.state);
    if (pending == null) return;
    await _completeOAuthLogin(pending, callback.ticket);
  }

  /// 用回调带回的一次性 ticket + 本地保管的 verifier 换 token。
  ///
  /// 请求发出后无论成败都清除本地事务：ticket 在服务端是一次性消费的，
  /// 留着记录只会让重复送达的 deep link 或页面刷新拿着已作废的 ticket 再试一次。
  /// 若因网络中断没登录成功，用户重点一次登录按钮即可（会重新发起授权）。
  Future<void> _completeOAuthLogin(
    OauthPendingAuth pending,
    String ticket,
  ) async {
    if (!mounted) return;
    final isFeishu = pending.provider == OauthBeginService.feishu;
    final providerName = isFeishu ? '飞书' : '微信';
    final loadingProvider = context.read<LoadingProvider>();
    try {
      await loadingProvider.executeOperation<AuthResult>(
        operation: () => isFeishu
            ? AuthService.loginWithFeishu(
                ticket: ticket,
                codeVerifier: pending.codeVerifier,
              )
            : AuthService.loginWithWechatTicket(
                flow: pending.flow,
                ticket: ticket,
                codeVerifier: pending.codeVerifier,
              ),
        key: isFeishu ? LoadingKeys.feishuLogin : LoadingKeys.wechatLogin,
        onSuccess: (authResult) {
          if (!mounted) return;
          if (!authResult.success) {
            MoeToast.error(
              context,
              authResult.errorMessage ?? '$providerName登录失败',
            );
            return;
          }
          unawaited(_onOAuthLoginSuccess(providerName));
        },
        onError: (_) {
          if (!mounted) return;
          MoeToast.error(context, '$providerName登录异常，请稍后重试');
        },
      );
    } finally {
      await OauthPendingStore.clear(pending.provider);
    }
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
      // Web 点浮层会先失焦：延迟收起，给 onPointerUp 补全留时间。
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
      FocusScope.of(context).requestFocus(_passwordFocus);
    });
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

  Future<void> _feishuLogin() async {
    if (kIsWeb) {
      try {
        final begin = await OauthBeginService.feishuAuth();
        final hint = oauthRedirectConfigMismatchHint(
          'Feishu',
          begin.authorizeUrl,
          AuthFlowService.apiBaseUrl,
        );
        if (hint != null && mounted) {
          MoeToast.error(context, hint);
          return;
        }
        await OAuthAppLauncher.navigateBrowserToOAuthAuthorize(
          begin.authorizeUrl,
        );
      } catch (e) {
        if (mounted) MoeToast.error(context, _beginFailureCopy('飞书', e));
      }
      return;
    }

    try {
      final begin = await OauthBeginService.feishuAuth();
      final hint = oauthRedirectConfigMismatchHint(
        'Feishu',
        begin.authorizeUrl,
        AuthFlowService.apiBaseUrl,
      );
      if (!mounted) return;
      if (hint != null) {
        MoeToast.error(context, hint);
        return;
      }

      final installed = await OAuthAppLauncher.isFeishuInstalled();
      if (!mounted) return;

      if (installed) {
        final opened =
            await OAuthAppLauncher.openOAuthAuthorize(begin.authorizeUrl);
        if (!mounted) return;
        if (opened) {
          MoeToast.info(
            context,
            '请在飞书中完成授权；若只打开浏览器且无法回到 App，请返回后再次点击飞书登录',
          );
          return;
        }
      }

      await _feishuLoginInAppWebView(begin);
    } catch (e) {
      if (mounted) MoeToast.error(context, _beginFailureCopy('飞书', e));
    }
  }

  /// 发起阶段的失败文案。
  ///
  /// 这里的异常大多来自服务端（回跳地址没登记进 `oauth.allowed_return_urls`、
  /// 供应商未启用）或本地存不下事务，都不是「网络不好重试一下」能解决的，
  /// 所以要把原始原因摆出来而不是笼统说失败。
  String _beginFailureCopy(String providerName, Object e) =>
      '无法发起$providerName授权：'
      '${MoeErrorCopy.toast(e, scene: MoeErrorScene.generic)}';

  /// App 内 WebView 授权：回调仍走服务端 `/api/auth/feishu/callback`，
  /// 再 302 到深链或本页；WebView 只认精确命中回跳地址的那一跳。
  Future<void> _feishuLoginInAppWebView(OauthBegin begin) async {
    final result = await Navigator.of(context).push<FeishuLoginResult>(
      MaterialPageRoute(
        builder: (_) => FeishuLoginPage(
          authorizeUrl: begin.authorizeUrl,
          expectedState: begin.state,
          returnUrl: begin.returnUrl,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
      MoeToast.error(context, result.errorMessage!);
      return;
    }
    if (!result.hasTicket) return;
    final pending = await OauthPendingStore.takeForState(
      OauthBeginService.feishu,
      result.state ?? '',
    );
    if (pending == null) {
      if (mounted) MoeToast.error(context, _noPendingAuthMessage);
      return;
    }
    await _completeOAuthLogin(pending, result.ticket!);
  }

  /// Web/PC：开放平台网站应用扫码；App：fluwx 唤起微信授权。
  ///
  /// 原生 flow 也必须先向服务端换 state：SDK 返回的 code 要配着那个 state 才能登录，
  /// 服务端靠它找回授权事务并校验 verifier。只在客户端比对 state 挡不住
  /// 「另一个 App 塞一个 code 进来」。
  Future<void> _wechatLogin() async {
    final flow = defaultWechatOAuthFlow();
    final OauthBegin begin;
    try {
      begin = await OauthBeginService.wechatAuth(flow);
    } catch (e) {
      if (mounted) MoeToast.error(context, _beginFailureCopy('微信', e));
      return;
    }

    if (kIsWeb) {
      try {
        await OAuthAppLauncher.navigateBrowserToWechatAuthorize(
          begin.authorizeUrl,
        );
      } catch (e) {
        if (mounted) MoeToast.error(context, '无法打开微信扫码登录：$e');
      }
      return;
    }

    if (!mounted) return;
    final loadingProvider = context.read<LoadingProvider>();
    try {
      await loadingProvider.executeOperation<AuthResult>(
        operation: () async {
          final pending = await OauthPendingStore.takeForState(
            OauthBeginService.wechat,
            begin.state,
          );
          if (pending == null) {
            return AuthResult.failure(_noPendingAuthMessage);
          }
          try {
            final code = await WechatSdkService.instance
                .requestAuthCode(state: begin.state);
            return AuthService.loginWithWechatSdkCode(
              code: code,
              state: begin.state,
              codeVerifier: pending.codeVerifier,
            );
          } on StateError catch (e) {
            return AuthResult.failure(e.message);
          }
        },
        key: LoadingKeys.wechatLogin,
        onSuccess: (authResult) {
          if (!mounted) return;
          if (!authResult.success) {
            MoeToast.error(
              context,
              authResult.errorMessage ?? '微信登录失败',
            );
            return;
          }
          unawaited(_onOAuthLoginSuccess('微信'));
        },
        onError: (_) {
          if (!mounted) return;
          MoeToast.error(context, '微信登录异常，请稍后重试');
        },
      );
    } finally {
      // SDK 返回的 code 同样是一次性的，无论成败都不该留下可重放的事务。
      await OauthPendingStore.clear(OauthBeginService.wechat);
    }
  }

  Future<void> _onOAuthLoginSuccess(String providerName) async {
    try {
      context.read<NotificationProvider>().init();
    } catch (_) {}
    final uid = AuthService.currentUser;
    if (uid != null) {
      unawaited(AchievementHooks.ensureReady(uid));
    }
    if (!mounted) return;
    MoeToast.success(context, '$providerName登录成功');
    Navigator.pushReplacementNamed(context, '/home');
    DailyGrowthService.instance.scheduleAutoCheckInAfterLogin();
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
          final msg = result.errorMessage?.trim();
          MoeToast.error(
            context,
            (msg != null && msg.isNotEmpty)
                ? msg
                : MoeErrorCopy.toast(
                    StateError('登录失败'),
                    scene: MoeErrorScene.generic,
                  ),
          );
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
        DailyGrowthService.instance.scheduleAutoCheckInAfterLogin();
      },
      onError: (msg) {
        if (!mounted) return;
        MoeToast.error(
          context,
          msg.isNotEmpty
              ? msg
              : MoeErrorCopy.toast(
                  StateError('登录异常'),
                  scene: MoeErrorScene.generic,
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ═══ Logo 区域 — 渐变容器 + 呼吸光晕 + 渐变文字 ═══
              MoeReveal(
                duration: const Duration(milliseconds: 800),
                child: _buildLogoSection(),
              ),

              const SizedBox(height: 28),

              // ═══ 表单卡片 — 毛玻璃容器 ═══
              MoeReveal(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 800),
                child: OperationLoadingWidget(
                  operationKey: LoadingKeys.feishuLogin,
                  loadingText: '正在完成飞书登录…',
                  child: OperationLoadingWidget(
                    operationKey: LoadingKeys.wechatLogin,
                    loadingText: '正在完成微信登录…',
                    child: _buildFormCard(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ═══ 底部注册引导 — 渐变分隔线 + 渐变文字 ═══
              MoeReveal(
                delay: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 800),
                child: _buildRegisterPrompt(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Logo 区域 ──────────────────────────────────────────────────
  Widget _buildLogoSection() {
    return Column(
      children: [
        // 渐变圆角容器 + 呼吸脉冲光晕
        const _BreathingLogo(),
        const SizedBox(height: 16),
        // 品牌名 — 渐变文字
        ShaderMask(
          shaderCallback: (bounds) =>
              MoeTokens.gradientText.createShader(bounds),
          child: const Text(
            'Moe Social',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white, // ShaderMask 会覆盖此颜色
              letterSpacing: 1.5,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 副标题 — 柔和渐变色
        ShaderMask(
          shaderCallback: (bounds) =>
              MoeTokens.gradientSoft.createShader(bounds),
          child: Text(
            '发现更可爱的世界',
            style: TextStyle(
              fontSize: MoeTokens.textMd,
              color: Colors.white,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 毛玻璃表单卡片 ────────────────────────────────────────────
  Widget _buildFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MoeTokens.blurMedium,
          sigmaY: MoeTokens.blurMedium,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            border: Border.all(
              color: MoeTokens.surfaceBorder,
              width: 1,
            ),
            boxShadow: MoeTokens.shadowCard(),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 邮箱输入
                ValueListenableBuilder<List<String>>(
                  valueListenable: _emailCompletions,
                  builder: (_, completions, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoeInputField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          hintText: '邮箱或 10 位 Moe 号',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: completions.isNotEmpty
                              ? (_) => null
                              : Validators.loginAccount,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          textInputAction: TextInputAction.next,
                          onEditingComplete: () => FocusScope.of(context)
                              .requestFocus(_passwordFocus),
                        ),
                        EmailSuffixBar(
                          candidates: completions,
                          accentColor: _primaryColor,
                          onSelected: _pickEmailSuffix,
                        ),
                        SizedBox(height: completions.isEmpty ? 20 : 12),
                      ],
                    );
                  },
                ),
                // 密码输入
                MoeInputField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hintText: '密码',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: Validators.password,
                  autovalidateMode: AutovalidateMode.disabled,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => unawaited(_login()),
                ),
                const SizedBox(height: 12),
                // 忘记密码
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: MoeTokens.hintText,
                    ),
                    child: const Text(
                      '忘记密码？',
                      style: TextStyle(fontSize: MoeTokens.textSm),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // 主登录按钮 — 渐变 + 光晕
                _buildGradientLoginButton(),
                const SizedBox(height: 14),
                // 分隔线 — "或"
                _buildDividerWithLabel(),
                const SizedBox(height: 14),
                // 微信登录
                _buildSocialLoginButton(
                  onPressed: () => unawaited(_wechatLogin()),
                  brandColor: const Color(0xFF07C160),
                  icon: Icons.wechat,
                  label: kIsWeb ? '微信扫码登录' : '微信登录 / 注册',
                ),
                const SizedBox(height: 10),
                // 飞书登录
                _buildSocialLoginButton(
                  onPressed: () => unawaited(_feishuLogin()),
                  brandColor: const Color(0xFF3370FF),
                  icon: Icons.hub_outlined,
                  label: '飞书登录 / 注册',
                ),
                const SizedBox(height: 4),
                const FeishuEnterpriseInviteBanner(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 渐变登录按钮 ──────────────────────────────────────────────
  Widget _buildGradientLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: MoePressable(
        onTap: _login,
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
        child: Consumer<LoadingProvider>(
          builder: (context, loadingProvider, _) {
            final isLoading =
                loadingProvider.isOperationLoading(LoadingKeys.login);
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
                  onTap: isLoading ? null : _login,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            '登 录',
                            style: TextStyle(
                              fontSize: MoeTokens.textLg,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
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

  // ─── 分隔线（渐变淡出 + 中间标签）──────────────────────────────
  Widget _buildDividerWithLabel() {
    return Row(
      children: [
        const Expanded(
          child: _GradientDivider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或',
            style: TextStyle(
              fontSize: MoeTokens.textSm,
              color: MoeTokens.hintText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: _GradientDivider(),
        ),
      ],
    );
  }

  // ─── 第三方登录按钮（毛玻璃风格）───────────────────────────────
  Widget _buildSocialLoginButton({
    required VoidCallback onPressed,
    required Color brandColor,
    required IconData icon,
    required String label,
  }) {
    return MoePressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: brandColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
          border: Border.all(
            color: brandColor.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 品牌色渐变圆形图标容器
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    brandColor.withValues(alpha: 0.15),
                    brandColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: brandColor),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: MoeTokens.textMd,
                fontWeight: FontWeight.w600,
                color: brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 底部注册引导 ──────────────────────────────────────────────
  Widget _buildRegisterPrompt() {
    return Column(
      children: [
        // 渐变淡出分隔线
        const _GradientDivider(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '还没有账号？',
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
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        MoeTokens.gradientPrimary.createShader(bounds),
                    child: const Text(
                      '立即注册',
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
    _feishuLinkSub?.cancel();
    _wechatLinkSub?.cancel();
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

/// Logo 呼吸脉冲动画 — 渐变容器 + 心形图标 + 缩放/光晕呼吸效果。
class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo();

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: MoeTokens.gradientPrimary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.primary
                      .withValues(alpha: 0.31 * _glowOpacity.value),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: MoeTokens.primary
                      .withValues(alpha: 0.16 * _glowOpacity.value),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        );
      },
    );
  }
}
