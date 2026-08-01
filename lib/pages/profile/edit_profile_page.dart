import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../auth_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import '../../utils/validators.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/signature_input.dart';
import '../../widgets/gender_selector.dart';
import '../../widgets/birthday_selector.dart';
import '../gallery/cloud_gallery_page.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/moe_input_field.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';

class EditProfilePage extends StatefulWidget {
  /// 从个人页传入时可预填；为空或字段不全时在 [initState] 拉远端。
  final User? user;

  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _avatarController;

  User? _profileUser;
  bool _loadingProfile = true;

  // 新字段状态
  String _signature = '';
  String _gender = '';
  DateTime? _birthday;

  // UI状态
  bool _hasUnsavedChanges = false;

  // 验证错误信息
  String? _signatureError;
  String? _genderError;
  String? _birthdayError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _avatarController = TextEditingController();
    _usernameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _avatarController.addListener(_onFieldChanged);
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    try {
      final seed = widget.user;
      final needsFetch = seed == null ||
          seed.username.trim().isEmpty ||
          seed.email.trim().isEmpty;
      final user =
          needsFetch ? await AuthService.getUserInfo(forceRefresh: true) : seed;
      if (!mounted) return;
      _applyUser(user);
      setState(() => _loadingProfile = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfile = false);
        MoeToast.error(context, '加载资料失败，请稍后重试');
      }
    }
  }

  void _applyUser(User user) {
    _profileUser = user;
    _usernameController.text = user.username;
    _emailController.text = user.email;
    _avatarController.text = user.avatar;
    _signature = user.signature;
    _gender = user.gender;
    _birthday = user.birthdayDateTime;
    _hasUnsavedChanges = false;
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
      if (pickedFile != null && mounted) {
        // 上传图片到云端
        MoeToast.info(context, '正在上传头像...');
        try {
          final file = File(pickedFile.path);
          final imageUrl = await UserService.uploadImage(file);
          if (!mounted) return;
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
          } else if (uploadError.toString().contains('Broken pipe') ||
              uploadError.toString().contains('SocketException')) {
            MoeToast.error(context, '网络连接中断，请检查网络后重试');
          } else {
            MoeToast.error(context, '上传失败: $uploadError');
          }
        }
      }
    } catch (e) {
      if (mounted) MoeToast.error(context, '选择图片失败: $e');
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
      if (pickedFile != null && mounted) {
        // 上传图片到云端
        MoeToast.info(context, '正在上传头像...');
        try {
          final file = File(pickedFile.path);
          final imageUrl = await UserService.uploadImage(file);
          if (!mounted) return;
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
          } else if (uploadError.toString().contains('Broken pipe') ||
              uploadError.toString().contains('SocketException')) {
            MoeToast.error(context, '网络连接中断，请检查网络后重试');
          } else {
            MoeToast.error(context, '上传失败: $uploadError');
          }
        }
      }
    } catch (e) {
      if (mounted) MoeToast.error(context, '选择图片失败: $e');
    }
  }

  Future<void> _showAvatarOptions() async {
    final moe = MoeTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.fromLTRB(
          MoeTokens.spaceLg,
          0,
          MoeTokens.spaceLg,
          MoeTokens.spaceLg,
        ),
        decoration: BoxDecoration(
          color: moe.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
          boxShadow: MoeTokens.shadowLg(),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceXl,
              MoeTokens.spaceMd,
              MoeTokens.spaceXl,
              MoeTokens.spaceXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MoeTokens.hintText.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXl),
                Text(
                  '更换头像',
                  style: TextStyle(
                    fontSize: MoeTokens.textLg,
                    fontWeight: MoeTokens.fontWeightTitle,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceSm),
                Text(
                  '拍照、相册或云端图库，任选一种方式',
                  style: TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.hintText,
                  ),
                ),
                const SizedBox(height: MoeTokens.space2xl),
                Row(
                  children: [
                    Expanded(
                      child: _AvatarSourceTile(
                        icon: Icons.camera_alt_rounded,
                        label: '拍照',
                        color: moe.primary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAvatarFromCamera();
                        },
                      ),
                    ),
                    const SizedBox(width: MoeTokens.spaceMd),
                    Expanded(
                      child: _AvatarSourceTile(
                        icon: Icons.photo_library_rounded,
                        label: '相册',
                        color: moe.secondary,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAvatarFromGallery();
                        },
                      ),
                    ),
                    const SizedBox(width: MoeTokens.spaceMd),
                    Expanded(
                      child: _AvatarSourceTile(
                        icon: Icons.cloud_rounded,
                        label: '云端',
                        color: moe.accent,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAvatarFromCloud();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _checkHasChanges() {
    final base = _profileUser;
    if (base == null) return false;
    return _usernameController.text.trim() != base.username ||
        _emailController.text.trim() != base.email ||
        _avatarController.text.trim() != base.avatar ||
        _signature != base.signature ||
        _gender != base.gender ||
        _birthday != base.birthdayDateTime;
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
    final loading = context.read<LoadingProvider>();
    if (loading.isOperationLoading(LoadingKeys.updateProfile)) return;

    final userId = AuthService.currentUser;
    if (userId == null) return;

    // 验证表单
    if (!_formKey.currentState!.validate() || !_validateFields()) {
      return;
    }

    final loadingProvider = context.read<LoadingProvider>();
    loadingProvider.setOperationLoading(LoadingKeys.updateProfile, true);

    try {
      final avatarText = _avatarController.text.trim();
      final updated = await UserService.updateUserInfo(
        userId,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        avatar: avatarText.isEmpty ? null : avatarText,
        signature: _signature.trim(),
        gender: _gender,
        birthday: _birthday?.toIso8601String().substring(0, 10),
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
        context
            .read<LoadingProvider>()
            .setOperationLoading(LoadingKeys.updateProfile, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    final isSaving = context.watch<LoadingProvider>().isOperationLoading(
          LoadingKeys.updateProfile,
        );

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: moe.pageBackground,
        body: _loadingProfile
            ? const Center(child: MoeLoading())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildFixedProfileHeader(moe, isSaving),
                    Expanded(child: _buildScrollableForm(moe)),
                    _buildStickySaveBar(moe, isSaving),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFixedProfileHeader(MoeTheme moe, bool saving) {
    final username = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()
        : '未设置昵称';

    return DecoratedBox(
      decoration: BoxDecoration(gradient: moe.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: Colors.white),
                    onPressed: () async {
                      if (_hasUnsavedChanges) {
                        final shouldPop = await _showUnsavedChangesDialog();
                        if (shouldPop && mounted) Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Expanded(
                    child: Text(
                      '编辑资料',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: MoeTokens.fontWeightTitle,
                        fontSize: MoeTokens.textLg,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_hasUnsavedChanges)
                    TextButton(
                      onPressed: saving ? null : _saveProfile,
                      child: Text(
                        '保存',
                        style: TextStyle(
                          color: saving
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.white,
                          fontWeight: MoeTokens.fontWeightSubtitle,
                          fontSize: MoeTokens.textBase,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MoeTokens.spaceXl,
                MoeTokens.spaceSm,
                MoeTokens.spaceXl,
                MoeTokens.spaceXl,
              ),
              child: Row(
                children: [
                  MoePressable(
                    onTap: _showAvatarOptions,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: NetworkAvatarImage(
                            imageUrl: _avatarController.text.isNotEmpty
                                ? _avatarController.text
                                : null,
                            radius: 36,
                            placeholderIcon: Icons.person_rounded,
                            placeholderColor: moe.primary,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: moe.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MoeTokens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: MoeTokens.textXl,
                            fontWeight: MoeTokens.fontWeightTitle,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: MoeTokens.spaceXs),
                        Text(
                          '点击头像更换',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: MoeTokens.textSm,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableForm(MoeTheme moe) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceLg,
        MoeTokens.spaceLg,
        MoeTokens.spaceLg,
        MoeTokens.space3xl,
      ),
      children: [
        _buildContentSheet(moe),
      ],
    );
  }

  Widget _buildContentSheet(MoeTheme moe) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: moe.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: MoeTokens.shadowMd(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditSection(
              index: 0,
              icon: Icons.badge_outlined,
              title: '账号身份',
              subtitle: '展示名称与联系方式',
              child: Column(
                children: [
                  MoeInputField(
                    controller: _usernameController,
                    hintText: '用户名',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: moe.primary,
                      size: 20,
                    ),
                    primaryColor: moe.primary,
                    validator: Validators.username,
                  ),
                  const SizedBox(height: MoeTokens.spaceLg),
                  MoeInputField(
                    controller: _emailController,
                    hintText: '邮箱',
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: moe.primary,
                      size: 20,
                    ),
                    primaryColor: moe.primary,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                ],
              ),
            ),
            _sectionGap(),
            _EditSection(
              index: 1,
              icon: Icons.auto_awesome_outlined,
              title: '个性展示',
              subtitle: '让别人更了解你',
              child: SignatureInput(
                initialValue: _signature,
                showFooterHint: false,
                onChanged: (value) {
                  _signature = value;
                  _onFieldChanged();
                },
                errorText: _signatureError,
              ),
            ),
            _sectionGap(),
            _EditSection(
              index: 2,
              icon: Icons.favorite_border_rounded,
              title: '基本信息',
              subtitle: '性别与生日可选填',
              child: Column(
                children: [
                  GenderSelector(
                    selectedGender: _gender,
                    showTitle: false,
                    showFooterHint: false,
                    onChanged: (value) {
                      _gender = value;
                      _onFieldChanged();
                    },
                    errorText: _genderError,
                  ),
                  const SizedBox(height: MoeTokens.spaceLg),
                  BirthdaySelector(
                    selectedDate: _birthday,
                    showFooterHint: false,
                    onChanged: (value) {
                      _birthday = value;
                      _onFieldChanged();
                    },
                    errorText: _birthdayError,
                  ),
                ],
              ),
            ),
            _sectionGap(),
            _EditSection(
              index: 3,
              icon: Icons.account_balance_wallet_outlined,
              title: '账户概览',
              subtitle: '只读信息，保存资料不影响账户资产',
              child: _AccountOverviewGrid(user: _profileUser, moe: moe),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionGap() => Padding(
        padding: const EdgeInsets.symmetric(vertical: MoeTokens.space2xl),
        child: Divider(
          height: 1,
          color: MoeTokens.hintText.withValues(alpha: 0.18),
        ),
      );

  Widget _buildStickySaveBar(MoeTheme moe, bool saving) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: moe.cardBackground,
        boxShadow: [
          BoxShadow(
            color: moe.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MoeTokens.spaceLg,
            MoeTokens.spaceMd,
            MoeTokens.spaceLg,
            MoeTokens.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: moe.primary,
                      ),
                      const SizedBox(width: MoeTokens.spaceSm),
                      Text(
                        '有未保存的更改',
                        style: TextStyle(
                          fontSize: MoeTokens.textSm,
                          color: moe.primary,
                          fontWeight: MoeTokens.fontWeightSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              LoadingButton(
                operationKey: LoadingKeys.updateProfile,
                onPressed: _hasUnsavedChanges && !saving ? _saveProfile : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: MoeTokens.spaceLg),
                  backgroundColor: _hasUnsavedChanges
                      ? moe.primary
                      : MoeTokens.hintText.withValues(alpha: 0.25),
                  foregroundColor:
                      _hasUnsavedChanges ? Colors.white : MoeTokens.hintText,
                  disabledBackgroundColor:
                      MoeTokens.hintText.withValues(alpha: 0.25),
                  disabledForegroundColor: MoeTokens.hintText,
                  elevation: _hasUnsavedChanges ? 4 : 0,
                  shadowColor: moe.primary.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                  ),
                  minimumSize: const Size(double.infinity, 52),
                  animationDuration: MoeTokens.motionMedium,
                ),
                child: Text(
                  _hasUnsavedChanges ? '保存更改' : '暂无更改',
                  style: const TextStyle(
                    fontSize: MoeTokens.textMd,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Layout primitives ───────────────────────────────────────────────────────

class _EditSection extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _EditSection({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    return MoeReveal(
      delay: Duration(milliseconds: 100 + index * 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      moe.primary.withValues(alpha: 0.14),
                      moe.secondary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                ),
                child: Icon(icon, size: 18, color: moe.primary),
              ),
              const SizedBox(width: MoeTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: MoeTokens.textMd,
                        fontWeight: MoeTokens.fontWeightTitle,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: MoeTokens.textSm,
                        color: MoeTokens.hintText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MoeTokens.spaceLg),
          child,
        ],
      ),
    );
  }
}

class _AccountOverviewGrid extends StatelessWidget {
  final User? user;
  final MoeTheme moe;

  const _AccountOverviewGrid({required this.user, required this.moe});

  @override
  Widget build(BuildContext context) {
    final isVip = user?.isVip ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - MoeTokens.spaceMd) / 2;
        return Wrap(
          spacing: MoeTokens.spaceMd,
          runSpacing: MoeTokens.spaceMd,
          children: [
            _AccountStatTile(
              width: tileWidth,
              icon: Icons.tag_rounded,
              label: 'Moe 号',
              value: (user?.moeNo.isNotEmpty ?? false) ? user!.moeNo : '—',
              valueColor: moe.primary,
            ),
            _AccountStatTile(
              width: tileWidth,
              icon: Icons.workspace_premium_rounded,
              label: '会员',
              value: isVip ? 'VIP' : '普通',
              valueColor: isVip ? const Color(0xFFFFB300) : MoeTokens.hintText,
            ),
            _AccountStatTile(
              width: tileWidth,
              icon: Icons.account_balance_wallet_rounded,
              label: '余额',
              value: '¥${(user?.balance ?? 0).toStringAsFixed(2)}',
              valueColor: MoeTokens.success,
            ),
            _AccountStatTile(
              width: tileWidth,
              icon: Icons.calendar_month_rounded,
              label: '注册',
              value: _shortDate(user?.createdAt),
              valueColor: MoeTokens.caption,
            ),
          ],
        );
      },
    );
  }

  String _shortDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

class _AccountStatTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _AccountStatTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(MoeTokens.spaceMd),
        decoration: BoxDecoration(
          color: MoeTokens.pageBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: MoeTokens.hintText.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: valueColor),
            const SizedBox(height: MoeTokens.spaceSm),
            Text(
              label,
              style: TextStyle(
                fontSize: MoeTokens.textXs,
                color: MoeTokens.hintText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MoeTokens.textBase,
                fontWeight: MoeTokens.fontWeightSubtitle,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AvatarSourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceLg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: MoeTokens.spaceSm),
            Text(
              label,
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                fontWeight: MoeTokens.fontWeightSubtitle,
                color: MoeTokens.titleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
