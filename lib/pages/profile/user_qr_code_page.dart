import 'package:flutter/material.dart';
import '../../services/qr_code_service.dart';
import '../../auth_service.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/moe_toast.dart';

class UserQrCodePage extends StatefulWidget {
  const UserQrCodePage({super.key});

  @override
  State<UserQrCodePage> createState() => _UserQrCodePageState();
}

class _UserQrCodePageState extends State<UserQrCodePage> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getUserInfo();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      MoeToast.error(context, '获取用户信息失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的二维码'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _currentUser != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        QrCodeService.buildQrCodeCard(
                          context: context,
                          userId: _currentUser!.id,
                          username: _currentUser!.username,
                          avatar: _currentUser!.avatar,
                          moeNo: _currentUser!.moeNo,
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          '让其他用户扫描此二维码添加你为好友',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '无法获取用户信息',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCurrentUser,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
