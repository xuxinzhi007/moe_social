import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/validators.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/signature_input.dart';
import '../../widgets/gender_selector.dart';
import '../../widgets/birthday_selector.dart';
import '../gallery/cloud_gallery_page.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_loading.dart';

class EditProfilePage extends StatefulWidget {
  final User user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _avatarController;

  // 新字段状态
  String _signature = '';
  String _gender = '';
  DateTime? _birthday;

  // UI状态
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // 验证错误信息
  String? _signatureError;
  String? _genderError;
  String? _birthdayError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _avatarController = TextEditingController(text: widget.user.avatar);

    // 初始化新字段
    _signature = widget.user.signature;
    _gender = widget.user.gender;
    _birthday = widget.user.birthdayDateTime;

    // 监听字段变化
    _usernameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _avatarController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      _hasUnsavedChanges = _checkHasChanges();
    });
  }

  Future<void> _pickAvatarFromCloud() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudGalleryPage(
          isSelectMode: true,
          onImageSelected: (imageUrl) {
            setState(() {
              _avatarController.text = imageUrl;
              _hasUnsavedChanges = _checkHasChanges();
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickAvatarFromCamera() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // 降低图片质量以减小大小
        maxWidth: 1024, // 限制图片宽度
        maxHeight: 1024, // 限制图片高度
      );
      if (pickedFile != null) {
        // 上传图片到云端
        MoeToast.info(context, '正在上传头像...');
        try {
          final file = File(pickedFile.path);
          final imageUrl = await ApiService.uploadImage(file);
          // 为了避免缓存问题，添加时间戳参数
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageUrlWithTimestamp = '$imageUrl?t=$timestamp';
          setState(() {
            _avatarController.text = imageUrlWithTimestamp;
            _hasUnsavedChanges = _checkHasChanges();
          });
          MoeToast.success(context, '头像已更新');
        } catch (uploadError) {
          if (uploadError.toString().contains('413')) {
            MoeToast.error(context, '图片太大，请降低拍照分辨率');
          } else if (uploadError.toString().contains('Broken pipe') || uploadError.toString().contains('SocketException')) {
            MoeToast.error(context, '网络连接中断，请检查网络后重试');
          } else {
            MoeToast.error(context, '上传失败: $uploadError');
          }
        }
      }
    } catch (e) {
      MoeToast.error(context, '选择图片失败: $e');
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // 降低图片质量以减小大小
        maxWidth: 1024, // 限制图片宽度
        maxHeight: 1024, // 限制图片高度
      );
      if (pickedFile != null) {
        // 上传图片到云端
        MoeToast.info(context, '正在上传头像...');
        try {
          final file = File(pickedFile.path);
          final imageUrl = await ApiService.uploadImage(file);
          // 为了避免缓存问题，添加时间戳参数
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageUrlWithTimestamp = '$imageUrl?t=$timestamp';
          setState(() {
            _avatarController.text = imageUrlWithTimestamp;
            _hasUnsavedChanges = _checkHasChanges();
          });
          MoeToast.success(context, '头像已更新');
        } catch (uploadError) {
          if (uploadError.toString().contains('413')) {
            MoeToast.error(context, '图片太大，请选择较小的图片');
          } else if (uploadError.toString().contains('Broken pipe') || uploadError.toString().contains('SocketException')) {
            MoeToast.error(context, '网络连接中断，请检查网络后重试');
          } else {
            MoeToast.error(context, '上传失败: $uploadError');
          }
        }
      }
    } catch (e) {
      MoeToast.error(context, '选择图片失败: $e');
    }
  }

  Future<void> _showAvatarOptions() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '选择头像',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatarFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Color(0xFF7F7FD5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('拍照'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatarFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          size: 40,
                          color: Color(0xFF7F7FD5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('相册'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatarFromCloud();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.cloud_upload,
                          size: 40,
                          color: Color(0xFF7F7FD5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('云端'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  bool _checkHasChanges() {
    return _usernameController.text.trim() != widget.user.username ||
           _emailController.text.trim() != widget.user.email ||
           _avatarController.text.trim() != widget.user.avatar ||
           _signature != widget.user.signature ||
           _gender != widget.user.gender ||
           _birthday != widget.user.birthdayDateTime;
  }

  bool _validateFields() {
    bool isValid = true;

    // 重置错误信息
    _signatureError = null;
    _genderError = null;
    _birthdayError = null;

    // 验证个性签名
    if (_signature.length > 100) {
      _signatureError = '个性签名长度不能超过100个字符';
      isValid = false;
    }

    // 验证性别
    if (_gender.isNotEmpty && !['male', 'female', 'secret'].contains(_gender)) {
      _genderError = '请选择有效的性别选项';
      isValid = false;
    }

    // 验证生日
    if (_birthday != null && _birthday!.isAfter(DateTime.now())) {
      _birthdayError = '生日不能是未来日期';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('您有未保存的更改，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('离开'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveProfile() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    // 验证表单
    if (!_formKey.currentState!.validate() || !_validateFields()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final avatarText = _avatarController.text.trim();
      final updated = await ApiService.updateUserInfo(
        userId,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        avatar: avatarText.isEmpty ? null : avatarText,
        signature: _signature.trim(),
        gender: _gender,
        birthday: _birthday != null ? _birthday!.toIso8601String().substring(0, 10) : null,
      );
      await AuthService.replaceUserProfileCache(updated);

      if (mounted) {
        _hasUnsavedChanges = false;
        MoeToast.success(context, '保存成功');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '保存失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('编辑资料', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () {
                HapticFeedback.lightImpact();
                _saveProfile();
              },
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7FD5))),
                    )
                  : Text(
                      '保存',
                      style: TextStyle(
                        color: _hasUnsavedChanges ? const Color(0xFF7F7FD5) : Colors.grey,
                        fontWeight: _hasUnsavedChanges ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 背景渐变
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像编辑区域
                    Center(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: NetworkAvatarImage(
                                imageUrl: _avatarController.text.isNotEmpty
                                    ? _avatarController.text
                                    : null,
                                radius: 65,
                                placeholderIcon: Icons.person,
                                placeholderColor: Colors.white,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isSaving ? null : () {
                                  HapticFeedback.lightImpact();
                                  _showAvatarOptions();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: const Color(0xFF7F7FD5),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Color(0xFF7F7FD5),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 基本信息卡片
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey[100]!, 
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF7F7FD5),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '基本信息',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 用户名
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: '用户名',
                                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF7F7FD5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF7F7FD5), width: 2),
                                ),
                                hintText: '3-20个字符，支持字母、数字、下划线',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: Validators.username,
                              onChanged: (_) => _onFieldChanged(),
                            ),

                            const SizedBox(height: 16),

                            // 邮箱
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: '邮箱',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF7F7FD5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF7F7FD5), width: 2),
                                ),
                                hintText: 'example@email.com',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              onChanged: (_) => _onFieldChanged(),
                            ),

                            const SizedBox(height: 16),

                            // 头像URL
                            TextField(
                              controller: _avatarController,
                              decoration: InputDecoration(
                                labelText: '头像URL',
                                prefixIcon: const Icon(Icons.image_outlined, color: Color(0xFF7F7FD5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF7F7FD5), width: 2),
                                ),
                                helperText: '输入头像图片的URL地址',
                                helperStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                suffixIcon: IconButton(
                                  tooltip: '选择头像',
                                  onPressed: _isSaving ? null : () {
                                    HapticFeedback.lightImpact();
                                    _showAvatarOptions();
                                  },
                                  icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF7F7FD5)),
                                ),
                              ),
                              keyboardType: TextInputType.url,
                              onChanged: (value) {
                                setState(() {}); // 更新头像预览
                                _onFieldChanged();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 个人资料卡片
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey[100]!, 
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF7F7FD5),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '个人资料',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 个性签名
                            SignatureInput(
                              initialValue: _signature,
                              onChanged: (value) {
                                _signature = value;
                                _onFieldChanged();
                              },
                              errorText: _signatureError,
                              enabled: !_isSaving,
                            ),

                            const SizedBox(height: 20),

                            // 性别选择
                            GenderSelector(
                              selectedGender: _gender,
                              onChanged: (value) {
                                _gender = value;
                                _onFieldChanged();
                              },
                              errorText: _genderError,
                              enabled: !_isSaving,
                            ),

                            const SizedBox(height: 20),

                            // 生日选择
                            BirthdaySelector(
                              selectedDate: _birthday,
                              onChanged: (value) {
                                _birthday = value;
                                _onFieldChanged();
                              },
                              errorText: _birthdayError,
                              enabled: !_isSaving,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 账户信息卡片
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey[100]!, 
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_outlined,
                                  color: Color(0xFF7F7FD5),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '账户信息',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('用户ID', widget.user.id),
                            const Divider(height: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                            _buildInfoRow(
                              'Moe 号',
                              widget.user.moeNo.isNotEmpty
                                  ? widget.user.moeNo
                                  : '—',
                              widget.user.moeNo.isNotEmpty
                                  ? const Color(0xFF7F7FD5)
                                  : null,
                            ),
                            const Divider(height: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                            _buildInfoRow(
                              'VIP状态',
                              widget.user.isVip ? 'VIP会员' : '普通用户',
                              widget.user.isVip ? const Color(0xFFFFD700) : null,
                            ),
                            if (widget.user.vipExpiresAt != null) ...[
                              const Divider(height: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                              _buildInfoRow(
                                'VIP到期时间',
                                widget.user.vipExpiresAt!,
                              ),
                            ],
                            const Divider(height: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                            _buildInfoRow(
                              '钱包余额',
                              '¥${widget.user.balance.toStringAsFixed(2)}',
                              const Color(0xFF4CAF50),
                            ),
                            const Divider(height: 20, thickness: 1, color: Color(0xFFF0F0F0)),
                            _buildInfoRow(
                              '注册时间',
                              widget.user.createdAt,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 保存按钮
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () {
                            HapticFeedback.lightImpact();
                            _saveProfile();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _hasUnsavedChanges ? const Color(0xFF7F7FD5) : Colors.grey[300],
                            foregroundColor: _hasUnsavedChanges ? Colors.white : Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _hasUnsavedChanges ? 8 : 0,
                            shadowColor: _hasUnsavedChanges ? const Color(0xFF7F7FD5).withOpacity(0.6) : Colors.transparent,
                            animationDuration: const Duration(milliseconds: 300),
                          ),
                          child: _isSaving
                              ? const MoeLoading(size: 24, color: Colors.white)
                              : const Text(
                                  '保存更改',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
