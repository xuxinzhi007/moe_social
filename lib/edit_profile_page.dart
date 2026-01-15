import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'models/user.dart';
import 'utils/validators.dart';
import 'widgets/avatar_image.dart';
import 'widgets/signature_input.dart';
import 'widgets/gender_selector.dart';
import 'widgets/birthday_selector.dart';

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
      await ApiService.updateUserInfo(
        userId,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        avatar: _avatarController.text.trim(),
        signature: _signature.trim(),
        gender: _gender,
        birthday: _birthday != null ? _birthday!.toIso8601String().substring(0, 10) : null,
      );

      if (mounted) {
        _hasUnsavedChanges = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存成功'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 返回true表示已更新
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        appBar: AppBar(
          title: const Text('编辑资料'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '保存',
                      style: TextStyle(
                        color: _hasUnsavedChanges ? Colors.blue : Colors.grey,
                        fontWeight: _hasUnsavedChanges ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像编辑区域
                Center(
                  child: Stack(
                    children: [
                      NetworkAvatarImage(
                        imageUrl: _avatarController.text.isNotEmpty
                            ? _avatarController.text
                            : null,
                        radius: 60,
                        placeholderIcon: Icons.person,
                        placeholderColor: Colors.grey,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 基本信息标题
                Text(
                  '基本信息',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // 用户名
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    hintText: '3-20个字符，支持字母、数字、下划线',
                  ),
                  validator: Validators.username,
                  onChanged: (_) => _onFieldChanged(),
                ),

                const SizedBox(height: 16),

                // 邮箱
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  onChanged: (_) => _onFieldChanged(),
                ),

                const SizedBox(height: 16),

                // 头像URL
                TextField(
                  controller: _avatarController,
                  decoration: const InputDecoration(
                    labelText: '头像URL',
                    prefixIcon: Icon(Icons.image_outlined),
                    border: OutlineInputBorder(),
                    helperText: '输入头像图片的URL地址',
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (value) {
                    setState(() {}); // 更新头像预览
                    _onFieldChanged();
                  },
                ),

                const SizedBox(height: 32),

                // 个人资料标题
                Text(
                  '个人资料',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

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

                const SizedBox(height: 32),

                // 账户信息
                Text(
                  '账户信息',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('用户ID', widget.user.id),
                        const Divider(),
                        _buildInfoRow(
                          'VIP状态',
                          widget.user.isVip ? 'VIP会员' : '普通用户',
                        ),
                        if (widget.user.vipExpiresAt != null) ...[
                          const Divider(),
                          _buildInfoRow(
                            'VIP到期时间',
                            widget.user.vipExpiresAt!,
                          ),
                        ],
                        const Divider(),
                        _buildInfoRow(
                          '钱包余额',
                          '¥${widget.user.balance.toStringAsFixed(2)}',
                        ),
                        const Divider(),
                        _buildInfoRow(
                          '注册时间',
                          widget.user.createdAt,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 保存按钮 (移动端友好)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _hasUnsavedChanges ? Colors.blue : Colors.grey,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '保存更改',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

