import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/qr_code_service.dart';
import '../../services/camera_permission_service.dart';
import '../../services/api_service.dart';
import '../../auth_service.dart';
import '../../widgets/moe_toast.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isScanSuccess = false;
  double _scanLinePosition = 0.0;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _initScanner();
    _initScanAnimation();
  }

  void _initScanAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    )..addListener(() {
        setState(() {
          _scanLinePosition = _scanLineAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initScanner() async {
    // 请求相机权限
    final hasPermission = await CameraPermissionService.handleCameraPermission(context);
    if (hasPermission) {
      setState(() {
        _hasPermission = true;
        _controller = MobileScannerController(
          torchEnabled: false,
          facing: CameraFacing.back,
          detectionSpeed: DetectionSpeed.normal,
        );
      });
    }
  }

  // 从相册选择图片
  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        MoeToast.info(context, '图片选择成功，正在识别二维码...');
        
        // 使用 mobile_scanner 库的 analyzeImage 方法识别二维码
        try {
          if (_controller != null) {
            // 注意：mobile_scanner 3.2.0 版本的 analyzeImage 方法返回 bool
            // 它会通过 onDetect 回调来传递扫描结果
            // 所以我们需要临时设置一个回调来处理扫描结果
            final bool success = await _controller!.analyzeImage(
              pickedFile.path,
            );

            if (!success) {
              MoeToast.error(context, '未识别到二维码');
            }
            // 成功的话会通过 onDetect 回调处理
          } else {
            MoeToast.error(context, '扫码控制器未初始化');
          }
        } catch (e) {
          MoeToast.error(context, '识别二维码失败: $e');
        }
      }
    } catch (e) {
      MoeToast.error(context, '选择图片失败: $e');
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final List<Barcode> barcodes = capture.barcodes;
      for (final barcode in barcodes) {
        final String? rawValue = barcode.rawValue;
        if (rawValue != null) {
          // 显示扫描成功动画
          setState(() {
            _isScanSuccess = true;
          });
          // 延迟一段时间后处理扫描结果
          await Future.delayed(const Duration(milliseconds: 500));
          await _processScanResult(rawValue);
          break;
        }
      }
    } catch (e) {
      MoeToast.error(context, '处理扫码结果失败: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _isScanSuccess = false;
      });
    }
  }

  Future<void> _processScanResult(String rawValue) async {
    // 解析二维码数据
    final qrData = QrCodeService.parseQrCodeData(rawValue);
    if (qrData == null) {
      MoeToast.error(context, '无效的二维码');
      return;
    }

    // 验证二维码数据
    if (!QrCodeService.isValidContactQrCode(qrData)) {
      MoeToast.error(context, '这不是有效的联系人二维码');
      return;
    }

    // 提取用户信息
    final String userId = qrData['userId'];
    final String username = qrData['username'];
    final String? avatar = qrData['avatar'];
    final String? moeNo = qrData['moeNo'];

    // 显示用户信息确认界面
    await _showUserConfirmDialog(userId, username, avatar, moeNo);
  }

  Future<void> _showUserConfirmDialog(String userId, String username, String? avatar, String? moeNo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null && avatar.isNotEmpty)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: FadeInImage.assetNetwork(
                    placeholder: 'assets/default_avatar.png',
                    image: avatar,
                    fit: BoxFit.cover,
                    imageErrorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (moeNo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Moe号: $moeNo',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),
            const Text('是否添加此用户为好友？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('添加'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await _sendFriendRequest(userId, username);
    }
  }

  Future<void> _sendFriendRequest(String userId, String username) async {
    try {
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == userId) {
        MoeToast.error(context, '不能添加自己为好友');
        return;
      }

      // 发送好友请求
      await ApiService.sendFriendRequestByUserId(currentUserId, userId);
      MoeToast.success(context, '好友请求已发送给 $username');
      Navigator.pop(context);
    } catch (e) {
      MoeToast.error(context, '发送好友请求失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _hasPermission
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Text(
                        '相机错误: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  },
                ),
                // 扫码框
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isScanSuccess ? Colors.blue : Colors.green,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // 扫描线动画
                        Positioned(
                          top: _scanLinePosition * 300,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.green,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 扫描成功动画
                        if (_isScanSuccess)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blue,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 64,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 底部操作栏
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '请将二维码对准扫描框',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  await _controller!.toggleTorch();
                                }
                              },
                              icon: const Icon(
                                Icons.flash_on,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                            ),
                            const SizedBox(width: 40),
                            IconButton(
                              onPressed: () async {
                                if (_controller != null) {
                                  await _controller!.switchCamera();
                                }
                              },
                              icon: const Icon(
                                Icons.cameraswitch,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                            ),
                            const SizedBox(width: 40),
                            IconButton(
                              onPressed: _pickImageFromGallery,
                              icon: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '需要相机权限',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initScanner,
                    child: const Text('重新请求权限'),
                  ),
                ],
              ),
            ),
    );
  }
}
