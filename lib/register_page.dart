import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'utils/validators.dart';
import 'widgets/fade_in_up.dart';
import 'package:provider/provider.dart';
import 'providers/loading_provider.dart';
import 'widgets/app_message_widget.dart';

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
  bool _obscurePassword = true;

  // 使用与登录页相同的配色
  final Color _primaryColor = const Color(0xFF7F7FD5);
  final Color _secondaryColor = const Color(0xFF86A8E7);
  final Color _accentColor = const Color(0xFF91EAE4);

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final loadingProvider = context.read<LoadingProvider>();

    await loadingProvider.executeOperation<AuthResult>(
      operation: () => AuthService.register(
        _usernameController.text,
        _emailController.text,
        _passwordController.text,
      ),
      key: LoadingKeys.register,
      onSuccess: (result) {
        if (!result.success) {
          loadingProvider.setError(result.errorMessage ?? '注册失败，请稍后重试');
          return;
        }

        loadingProvider.setSuccess('欢迎加入 Moe Social！(≧∇≦)/');
        Navigator.pop(context);
      },
      onError: (_) {
        // 错误已通过 LoadingProvider 统一显示
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // 让AppBar浮在背景上
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height, // 确保高度撑满
          child: Stack(
            children: [
              // 1. 背景层
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.35, // 稍微调小一点，给表单更多空间
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_secondaryColor, _primaryColor], // 反转渐变，增加变化
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                ),
              ),
              // 装饰
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 2. 内容层
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + 40),
                      
                      // 标题
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: const Text(
                          '创建账号',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          '开始你的萌系社交之旅',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 注册表单卡片
                      Expanded( // 使用Expanded填充剩余空间，避免溢出
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 1000),
                          delay: const Duration(milliseconds: 200),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 30),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView( // 卡片内部可滚动
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      controller: _usernameController,
                                      label: '用户名',
                                      icon: Icons.person_outline,
                                      validator: Validators.username,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _emailController,
                                      label: '电子邮箱',
                                      icon: Icons.email_outlined,
                                      validator: Validators.email,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _passwordController,
                                      label: '设置密码',
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      validator: Validators.password,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _confirmPasswordController,
                                      label: '确认密码',
                                      icon: Icons.lock_reset_outlined,
                                      isPassword: true,
                                      validator: (value) => Validators.confirmPassword(
                                          value, _passwordController.text),
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: LoadingButton(
                                        operationKey: LoadingKeys.register,
                                        onPressed: _register,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          elevation: 5,
                                          shadowColor: _primaryColor.withOpacity(0.4),
                                        ),
                                        child: const Text(
                                          '立即注册',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '已有账户？',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            '直接登录',
                                            style: TextStyle(
                                              color: _primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red[200]!),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red[400]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
