import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth_service.dart';
import '../../models/user.dart';
import '../../services/qr_code_service.dart';
import '../../theme/moe_tokens.dart';
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

  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < 720;
  }

  Widget _buildSavePanel(BuildContext context) {
    final compact = _isCompactLayout(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: const Color(0xFFECECFA)),
      ),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveQrCardToGallery,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isSaving ? '保存中...' : '保存到相册'),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 50 : 54),
              backgroundColor: MoeTokens.primary,
              foregroundColor: Colors.white,
              textStyle: TextStyle(
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compact ? 16 : 18),
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            compact ? '保存后可直接发给朋友。' : '保存后可以发给朋友，也可以在线下场景直接展示二维码。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF7D849B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('我的二维码'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser != null
              ? SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 20,
                    14,
                    compact ? 14 : 20,
                    22,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                          SizedBox(height: compact ? 16 : 24),
                          _buildSavePanel(context),
                          if (!compact) ...[
                            const SizedBox(height: 28),
                            const Text(
                              '让其他用户扫描此二维码添加你为好友',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8B92A7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
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
