import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_flow_service.dart';
import '../../services/api_service.dart' show ApiException;
import '../../utils/validators.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../utils/responsive.dart';
import '../../theme/moe_tokens.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordPage({super.key, required this.email, required this.code});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AuthFlowService.resetPassword(
          widget.email,
          widget.code,
          _newPasswordController.text,
        );
        if (!mounted) return;
        MoeToast.success(context, '密码重置成功，请重新登录 (｡♥‿♥｡)');

        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } on ApiException catch (e) {
        if (mounted) MoeToast.error(context, e.message);
      } catch (e) {
        if (mounted) {
          MoeToast.error(context, '重置失败，请稍后重试');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final layoutHeight = math.max(size.height, 900.0);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: SizedBox(
              height: layoutHeight,
              child: Stack(
                children: [
                  // 背景层
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: layoutHeight * 0.4,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [MoeTokens.secondary, MoeTokens.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(60),
                          bottomRight: Radius.circular(60),
                        ),
                      ),
                    ),
                  ),

                  // 内容层
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          SizedBox(
                              height: MediaQuery.of(context).padding.top + 40),
                          MoeReveal(
                            duration: const Duration(milliseconds: 800),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_person_rounded,
                                  size: 60, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                          MoeReveal(
                            duration: const Duration(milliseconds: 800),
                            delay: const Duration(milliseconds: 100),
                            child: const Text(
                              '设置新密码',
                              style: TextStyle(
                                fontSize: MoeTokens.text3xl,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const Spacer(),
                          MoeReveal(
                            duration: const Duration(milliseconds: 1000),
                            delay: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                    MoeTokens.radiusButton),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('新密码',
                                          style: TextStyle(
                                              fontSize: MoeTokens.textSm,
                                              color: MoeTokens.titleText)),
                                    ),
                                    const SizedBox(height: 8),
                                    MoeInputField(
                                      controller: _newPasswordController,
                                      hintText: '新密码',
                                      icon: Icons.lock_outline,
                                      primaryColor: MoeTokens.primary,
                                      isPassword: true,
                                      validator: Validators.password,
                                    ),
                                    const SizedBox(height: 20),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('确认密码',
                                          style: TextStyle(
                                              fontSize: MoeTokens.textSm,
                                              color: MoeTokens.titleText)),
                                    ),
                                    const SizedBox(height: 8),
                                    MoeInputField(
                                      controller: _confirmPasswordController,
                                      hintText: '确认密码',
                                      icon: Icons.lock_reset_outlined,
                                      primaryColor: MoeTokens.primary,
                                      isPassword: true,
                                      validator: (value) =>
                                          Validators.confirmPassword(value,
                                              _newPasswordController.text),
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _resetPassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: MoeTokens.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                MoeTokens.radiusButton),
                                          ),
                                          elevation: 5,
                                        ),
                                        child: _isLoading
                                            ? const MoeSmallLoading(
                                                size: 20,
                                                color: Colors.white)
                                            : const Text('确认重置',
                                                style: TextStyle(
                                                    fontSize: MoeTokens.textLg,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
                        ],
                      ),
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
