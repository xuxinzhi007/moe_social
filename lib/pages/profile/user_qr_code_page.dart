import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import '../../services/qr_code_service.dart';
import '../../auth_service.dart';
import '../../models/user.dart';
import '../../widgets/moe_toast.dart';

class UserQrCodePage extends StatefulWidget {
  const UserQrCodePage({super.key});

  @override
  State<UserQrCodePage> createState() => _UserQrCodePageState();
}

class _UserQrCodePageState extends State<UserQrCodePage> {
  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  final GlobalKey _qrCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getUserInfo();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      MoeToast.error(context, '获取用户信息失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _ensureSavePermission() async {
    if (kIsWeb) {
      MoeToast.info(context, 'Web 端暂不支持直接保存到系统相册');
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      if (status.isGranted || status.isLimited) {
        return true;
      }
      if (!mounted) return false;
      MoeToast.error(context, '请在系统设置中允许访问照片');
      return false;
    }
    // Android 10+ 使用分区存储，插件可直接写入媒体库。
    return true;
  }

  Future<void> _saveQrCardToGallery() async {
    if (_isSaving || _currentUser == null) {
      return;
    }
    final canSave = await _ensureSavePermission();
    if (!canSave) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final renderObject = _qrCardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        _showError('二维码视图获取失败，请稍后重试');
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('二维码图片生成失败');
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final fileName =
          'moe_qr_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(bytes, name: fileName, album: 'MoeSocial');

      if (!mounted) return;
      MoeToast.success(context, '二维码已保存到相册');
    } catch (e) {
      _showError('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    MoeToast.error(context, message);
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
                        RepaintBoundary(
                          key: _qrCardKey,
                          child: QrCodeService.buildQrCodeCard(
                            context: context,
                            userId: _currentUser!.id,
                            username: _currentUser!.username,
                            avatar: _currentUser!.avatar,
                            moeNo: _currentUser!.moeNo,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveQrCardToGallery,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(_isSaving ? '保存中...' : '保存到相册'),
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
