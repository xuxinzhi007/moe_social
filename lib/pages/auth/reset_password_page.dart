import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_flow_service.dart';
import '../../services/api_service.dart' show ApiException;
import '../../utils/validators.dart';
import '../../widgets/motion/moe_reveal.dart';
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
  bool _obscurePassword = true;

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
        _showCustomSnackBar(context, '密码重置成功，请重新登录 (｡♥‿♥｡)', isError: false);

        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } on ApiException catch (e) {
        if (mounted) _showCustomSnackBar(context, e.message, isError: true);
      } catch (e) {
        if (mounted) {
          _showCustomSnackBar(context, '重置失败，请稍后重试', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showCustomSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    if (isError) {
      MoeToast.error(context, message);
      return;
    }
    MoeToast.success(context, message);
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
                                    TextFormField(
                                      controller: _newPasswordController,
                                      decoration: InputDecoration(
                                        labelText: '新密码',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            color: MoeTokens.primary),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.grey),
                                          onPressed: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword),
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                MoeTokens.radiusInput)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              MoeTokens.radiusInput),
                                          borderSide: BorderSide(
                                              color: Colors.grey[200]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              MoeTokens.radiusInput),
                                          borderSide: const BorderSide(
                                              color: MoeTokens.primary),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      obscureText: _obscurePassword,
                                      validator: Validators.password,
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      decoration: InputDecoration(
                                        labelText: '确认密码',
                                        prefixIcon: const Icon(
                                            Icons.lock_reset_outlined,
                                            color: MoeTokens.primary),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                MoeTokens.radiusInput)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              MoeTokens.radiusInput),
                                          borderSide: BorderSide(
                                              color: Colors.grey[200]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              MoeTokens.radiusInput),
                                          borderSide: const BorderSide(
                                              color: MoeTokens.primary),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      obscureText: _obscurePassword,
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
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2))
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
