import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_flow_service.dart';
import '../../services/api_service.dart' show ApiException;
import 'reset_password_page.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_toast.dart';
import '../../utils/responsive.dart';
import '../../theme/moe_tokens.dart';

class VerifyCodePage extends StatefulWidget {
  final String email;

  const VerifyCodePage({super.key, required this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _countdown = 60;
  Timer? _timer;

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthFlowService.sendResetPasswordCode(widget.email);
      if (!mounted) return;
      _showCustomSnackBar(context, '验证码已重新发送', isError: false);
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) _showCustomSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, '发送失败，请稍后重试', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AuthFlowService.verifyResetCode(
            widget.email, _codeController.text);
        if (!mounted) return;
        _showCustomSnackBar(context, '验证成功！(≧∇≦)/', isError: false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(
              email: widget.email,
              code: _codeController.text,
            ),
          ),
        );
      } on ApiException catch (e) {
        if (mounted) _showCustomSnackBar(context, e.message, isError: true);
      } catch (e) {
        if (mounted) {
          _showCustomSnackBar(context, '验证失败，请稍后重试', isError: true);
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
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
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
                          colors: [MoeTokens.primary, MoeTokens.secondary],
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
                              child: const Icon(Icons.security_rounded,
                                  size: 60, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                          MoeReveal(
                            duration: const Duration(milliseconds: 800),
                            delay: const Duration(milliseconds: 100),
                            child: const Text(
                              '安全验证',
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
                                    Text(
                                      '我们已向您的邮箱发送了验证码',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    Text(
                                      widget.email,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          height: 1.5),
                                    ),
                                    const SizedBox(height: 30),
                                    TextFormField(
                                      controller: _codeController,
                                      decoration: InputDecoration(
                                        labelText: '6位验证码',
                                        prefixIcon: const Icon(
                                            Icons.verified_user_outlined,
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
                                        suffixIcon: _countdown > 0
                                            ? Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text('${_countdown}s',
                                                    style: const TextStyle(
                                                        color: Colors.grey)),
                                              )
                                            : TextButton(
                                                onPressed: _resendCode,
                                                child: const Text('重发',
                                                    style: TextStyle(
                                                        color:
                                                            MoeTokens.primary)),
                                              ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          (value?.length ?? 0) != 6
                                              ? '请输入6位验证码'
                                              : null,
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _verifyCode,
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
                                            : const Text('验证并重置',
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
