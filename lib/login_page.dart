import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'utils/validators.dart';
import 'forgot_password_page.dart';
import 'widgets/fade_in_up.dart';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';
import 'providers/loading_provider.dart';
import 'widgets/app_message_widget.dart';
import 'widgets/moe_toast.dart';
import 'widgets/moe_input_field.dart';
import 'widgets/auth_background.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Color _primaryColor = const Color(0xFF7F7FD5);

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final loadingProvider = context.read<LoadingProvider>();

    await loadingProvider.executeOperation<AuthResult>(
      operation: () => AuthService.login(
        _emailController.text,
        _passwordController.text,
      ),
      key: LoadingKeys.login,
      onSuccess: (result) {
        if (!result.success) {
          loadingProvider.setError(result.errorMessage ?? '登录失败，请稍后重试');
          return;
        }
        try {
          context.read<NotificationProvider>().init();
        } catch (_) {}
        // 导航到首页后再显示通知
        Navigator.pushReplacementNamed(context, '/home').then((_) {
          // 在首页显示登录成功通知
          final currentContext = AuthService.navigatorKey.currentContext;
          if (currentContext != null) {
            MoeToast.success(currentContext, '欢迎回来！(｡♥♥｡)');
          }
        });
      },
      onError: (_) {},
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
                            color: _primaryColor.withOpacity(0.2),
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
                      MoeInputField(
                        controller: _emailController,
                        hintText: '邮箱',
                        icon: Icons.email_outlined,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 20),
                      MoeInputField(
                        controller: _passwordController,
                        hintText: '密码',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: Validators.password,
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
                            shadowColor: _primaryColor.withOpacity(0.4),
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
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: Text(
                        ' 立即注册',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
