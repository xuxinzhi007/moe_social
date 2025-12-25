import 'package:flutter/material.dart';
import 'reset_password_page.dart';
import 'services/api_service.dart';
import 'utils/validators.dart';
import 'models/user.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _checkEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. 检查邮箱是否存在
        final user = await ApiService.checkUserByEmail(_emailController.text);
        
        if (!mounted) return;

        // 2. 如果存在，显示用户信息并确认
        _showUserFoundDialog(user);

      } on ApiException catch (e) {
        _showCustomSnackBar(context, e.message, isError: true);
      } catch (e) {
        _showCustomSnackBar(context, '查询失败，请稍后重试', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showUserFoundDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('账号已找到'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user.avatar == null || user.avatar!.isEmpty
                  ? Text(user.username.substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(height: 10),
            Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            const Text(
              '出于安全考虑，密码已加密存储，无法直接显示。\n您可以选择重置密码。',
              style: TextStyle(fontSize: 13, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResetPasswordPage(
                    email: _emailController.text,
                    code: "", 
                  ),
                ),
              );
            },
            child: const Text('去重置密码'),
          ),
        ],
      ),
    );
  }

  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.search_rounded, size: 70, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  const Text(
                    '找回账号',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '请输入您的邮箱地址以查找账号',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'example@email.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _checkEmail,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('查找账号', style: TextStyle(fontSize: 16)),
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('记得密码了？'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('去登录'),
                      ),
                    ],
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
