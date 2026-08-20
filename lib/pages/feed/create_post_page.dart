import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../../providers/user_level_provider.dart';
import '../../auth_service.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/companion_service.dart';
import '../../services/achievement_hooks.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/ai_bot_badge.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/topic_tag_selector.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../theme/moe_tokens.dart';
import '../gallery/cloud_gallery_page.dart';
import '../../models/hand_draw_card.dart';
import 'create_post_viewmodel.dart';
import 'hand_draw_editor_page.dart';
import '../../widgets/hand_draw/hand_draw_card_view.dart';
import '../../utils/media_url.dart';

class CreatePostPage extends StatefulWidget {
  /// 传入已有帖子时进入编辑模式，否则为新建发布模式。
  final Post? initialPost;

  /// 发帖成功后关联到该群组（需先发布动态再 link）。
  final String? groupId;

  /// 作为社区 AI 账号发布时使用。
  final CompanionCommunityIdentityData? communityIdentity;

  const CreatePostPage({
    super.key,
    this.initialPost,
    this.groupId,
    this.communityIdentity,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final CreatePostViewModel _vm;
  final TextEditingController _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  Timer? _draftSaveTimer;
  bool _draftRestoreFinished = false;

  static const Duration _draftSaveDebounce = Duration(milliseconds: 700);

  void _onVmChanged() {
    if (mounted) setState(() {});
    if (_draftRestoreFinished) {
      _queueDraftSave();
    }
  }

  void _queueDraftSave() {
    if (_vm.isEditMode || _vm.isGroupPost || !_vm.hasUnsavedChanges) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, () {
      if (!mounted) return;
      unawaited(_vm.saveDraft(_contentController.text));
    });
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确定离开？'),
        content: const Text('内容尚未发布，确定要离开吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('继续编辑')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('离开')),
        ],
      ),
    );
  }

  Future<void> _openHandDrawEditor() async {
    final data = await Navigator.push<HandDrawCardData>(
      context,
      MaterialPageRoute(builder: (_) => const HandDrawEditorPage()),
    );
    if (data != null && mounted) {
      _vm.setHandDraw(data);
      context.read<LoadingProvider>().setSuccess('手绘卡片已添加 ✨');
    }
  }

  void _removeHandDraw() {
    _vm.setHandDraw(null);
  }

  Future<void> _addImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );

    if (pickedFile != null) {
      _vm.addLocalImage(File(pickedFile.path));
    }
  }

  void _openCloudGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudGalleryPage(
          isSelectMode: true,
          onImageSelected: (imageUrl) {
            _vm.addCloudImageUrl(imageUrl);
            context.read<LoadingProvider>().setSuccess('图片已添加');
          },
        ),
      ),
    );
  }

  void _removeImage(int index) {
    if (index < _vm.selectedImages.length) {
      _vm.removeLocalImageAt(index);
    } else {
      final urlIndex = index - _vm.selectedImages.length;
      _vm.removeCloudImageUrl(_vm.selectedImageUrls[urlIndex]);
    }
  }

  void _openTopicTagSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(bottomSheetContext).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Text(
                  '选择话题标签',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(bottomSheetContext),
                  child: const Text('完成'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TopicTagSelector(
                selectedTags: _vm.selectedTopicTags,
                onTagsChanged: (tags) {
                  _vm.setTopicTags(List<TopicTag>.from(tags));
                },
                userId: AuthService.currentUser ?? 'guest',
                maxTags: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vm = CreatePostViewModel(
      initialPost: widget.initialPost,
      groupId: widget.groupId,
      communityIdentity: widget.communityIdentity,
    );
    _vm.addListener(_onVmChanged);
    _contentController.addListener(() {
      if (!_vm.hasUnsavedChanges) {
        _vm.markDirty();
      }
      if (_draftRestoreFinished) {
        _queueDraftSave();
      }
    });
    final init = widget.initialPost;
    if (init != null) {
      _vm.seedFromInitialPost(init);
      _contentController.text = init.content;
    }
    unawaited(_bootstrapPage());
  }

  Future<void> _bootstrapPage() async {
    await _vm.bootstrap();
    if (!mounted) return;
    if (widget.initialPost == null) {
      final draftCaption = await _vm.restoreDraft();
      if (!mounted || draftCaption == null) {
        _draftRestoreFinished = mounted;
        return;
      }
      final hasRestored = draftCaption.isNotEmpty ||
          _vm.selectedImageUrls.isNotEmpty ||
          _vm.selectedTopicTags.isNotEmpty ||
          _vm.selectedMoodTag != null ||
          _vm.handDrawCard != null;
      if (hasRestored) {
        if (draftCaption.isNotEmpty && _contentController.text.isEmpty) {
          _contentController.text = draftCaption;
        }
        MoeToast.info(context, '已恢复未发布的草稿');
      }
    }
    _draftRestoreFinished = true;
  }

  Future<void> _publishPost() async {
    final caption = _contentController.text.trim();
    final validationError = _vm.validateContent(caption);
    if (validationError != null) {
      _formKey.currentState?.validate();
      context.read<LoadingProvider>().setError(validationError);
      return;
    }

    if (_vm.isGroupPost && _vm.canPostToGroup != true) {
      if (_vm.canPostToGroup == null) {
        await _vm.loadGroupPostPermission();
      }
      if (_vm.canPostToGroup != true) {
        if (mounted) {
          MoeToast.info(context, '请先加入该群组再发帖');
        }
        return;
      }
    }

    if (!mounted) return;

    await _vm.saveDraft(caption);
    if (!mounted) return;

    final loadingProvider = context.read<LoadingProvider>();
    await loadingProvider.executeOperation<CreatePostPublishResult>(
      key: LoadingKeys.createPost,
      operation: () => _vm.publish(caption),
      onSuccess: (result) {
        if (!mounted) return;
        _draftSaveTimer?.cancel();
        loadingProvider.clearMessages();
        final uid = AuthService.currentUser;
        final unlocks = result.newAchievements;
        final softWarning = result.softWarning;
        Navigator.pop(context, result.post);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (uid != null && unlocks.isNotEmpty) {
            AchievementHooks.scheduleServerUnlocks(uid, unlocks);
          }
          final rootCtx = AuthService.navigatorKey.currentContext;
          if (rootCtx != null) {
            MoeToast.success(rootCtx, result.successMessage);
            if (softWarning != null && softWarning.isNotEmpty) {
              MoeToast.info(rootCtx, softWarning);
            }
            if (uid != null) {
              unawaited(rootCtx.read<UserLevelProvider>().loadUserLevel(uid));
            }
          }
        });
      },
      onError: (msg) {
        if (!mounted) return;
        MoeToast.error(context, msg);
      },
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String get _weatherText => '晴朗';

  static const Map<String, Color> _moodColors = {
    'happy': MoeTokens.pastelOrange,
    'calm': MoeTokens.pastelTeal,
    'sad': MoeTokens.pastelBlue,
    'excited': MoeTokens.pastelPink,
  };

  static const Map<String, IconData> _moodIcons = {
    'happy': Icons.sentiment_satisfied_alt_rounded,
    'calm': Icons.self_improvement_rounded,
    'sad': Icons.sentiment_dissatisfied_rounded,
    'excited': Icons.celebration_rounded,
  };

  static const Map<String, String> _moodLabels = {
    'happy': '开心',
    'calm': '平静',
    'sad': '低落',
    'excited': '兴奋',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final primaryColor = theme.primaryColor;

    return PopScope(
      canPop: !_vm.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _vm.hasUnsavedChanges) {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: MoeTokens.softLavenderBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            _vm.isEditMode ? '编辑动态' : (_vm.isGroupPost ? '发到本群' : '记录心情'),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: MoeTokens.inkMuted, size: 20),
              onPressed: () {
                if (_vm.hasUnsavedChanges) {
                  _showExitConfirmation();
                } else {
                  Navigator.pop(context);
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
              alignment: Alignment.center,
              child: SizedBox(
                height: 36,
                width: 76,
                child: LoadingButton(
                  operationKey: LoadingKeys.createPost,
                  onPressed: _vm.isGroupPost && _vm.canPostToGroup != true
                      ? null
                      : _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: primaryColor.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(_vm.isEditMode ? '保存' : '发布'),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_vm.isGroupPost && _vm.canPostToGroup == false) ...[
                  _buildGroupWarning(textTheme),
                  const SizedBox(height: 16),
                ],
                if (widget.communityIdentity?.isValid == true) ...[
                  MoeReveal(
                    delay: Duration.zero,
                    child: _buildCommunityIdentityBanner(textTheme),
                  ),
                  const SizedBox(height: 16),
                ],
                MoeReveal(
                  delay: Duration.zero,
                  child: _buildGreetingCard(textTheme),
                ),
                const SizedBox(height: 16),
                MoeReveal(
                  delay: MoeTokens.motionStaggerStep,
                  child: _buildInputCard(textTheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard(TextTheme textTheme) {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: MoeTokens.gradientMintBlush,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.mintSoft.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded,
                  size: 18, color: Colors.orange.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_greeting，${_vm.userName ?? '萌友'}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MoeTokens.inkDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wb_sunny_rounded,
                        size: 14, color: Colors.orange.shade500),
                    const SizedBox(width: 4),
                    Text(
                      _weatherText,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$month月$day日 星期$weekday',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: MoeTokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityIdentityBanner(TextTheme textTheme) {
    final identity = widget.communityIdentity!;
    final name = identity.userName.trim().isNotEmpty
        ? identity.userName.trim()
        : 'AI 伙伴';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoeTokens.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MoeTokens.softChipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.smart_toy_rounded, color: MoeTokens.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前以 $name 发布',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.inkDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '内容会进入社区流，并以真实 AI 账号身份展示。',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AiBotBadge(
              agentKey: identity.authorBotAgentKey.isNotEmpty
                  ? identity.authorBotAgentKey
                  : identity.agentId),
        ],
      ),
    );
  }

  Widget _buildInputCard(TextTheme textTheme) {
    final hasAttachments = _vm.handDrawCard != null ||
        _vm.selectedImages.isNotEmpty ||
        _vm.selectedImageUrls.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _formKey,
            child: MoeInputField(
              controller: _contentController,
              hintText: '写下此刻的想法…',
              maxLines: 10,
              minLines: 5,
              filled: true,
              keyboardType: TextInputType.multiline,
              validator: (v) {
                if ((v ?? '').trim().isEmpty &&
                    _vm.handDrawCard == null &&
                    _vm.selectedImages.isEmpty &&
                    _vm.selectedImageUrls.isEmpty) {
                  return '写点文字、选几张图，或画一张手绘卡片再发布吧';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildFormActions(textTheme),
          if (hasAttachments) ...[
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 12),
            _buildAttachments(textTheme),
          ],
          if (!_vm.isEditMode) ...[
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 14),
            _buildSectionTitle(textTheme, Icons.mood_rounded, '今天的心情'),
            const SizedBox(height: 10),
            _buildMoodChips(textTheme),
          ],
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildSectionTitle(textTheme, Icons.tag_rounded, '话题标签'),
          const SizedBox(height: 10),
          if (_vm.selectedTopicTags.isNotEmpty)
            _buildTopicTags(textTheme)
          else
            _buildTopicPlaceholder(textTheme),
        ],
      ),
    );
  }

  Widget _buildFormActions(TextTheme textTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _formActionChip(
          icon: Icons.brush_rounded,
          label: '手绘',
          color: MoeTokens.primary,
          onTap: _openHandDrawEditor,
        ),
        _formActionChip(
          icon: Icons.image_rounded,
          label: '相册',
          color: MoeTokens.pastelTeal,
          onTap: _addImage,
        ),
        _formActionChip(
          icon: Icons.cloud_upload_rounded,
          label: '云端图库',
          color: MoeTokens.pastelBlue,
          onTap: _openCloudGallery,
        ),
      ],
    );
  }

  Widget _formActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicPlaceholder(TextTheme textTheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openTopicTagSelector,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MoeTokens.lineSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: MoeTokens.pastelPink),
              const SizedBox(width: 6),
              Text(
                '点击添加话题，最多 5 个',
                style: textTheme.bodySmall?.copyWith(
                  color: MoeTokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            MoeTokens.lineSoft,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    TextTheme textTheme,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MoeTokens.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            color: MoeTokens.inkDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChips(TextTheme textTheme) {
    return Row(
      children: [
        for (final mood in _moodLabels.keys) ...[
          Expanded(child: _moodChip(mood, textTheme)),
          if (mood != _moodLabels.keys.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildGroupWarning(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '你还未加入该群组，请先返回群详情页点击「加入」后再发帖。',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_vm.handDrawCard != null) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MoeTokens.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.brush_rounded,
                        size: 14, color: MoeTokens.primary),
                    const SizedBox(width: 4),
                    Text(
                      '手绘卡片',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openHandDrawEditor,
                child: Text(
                  '改画',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MoeTokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _removeHandDraw,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: HandDrawCardStatic(data: _vm.handDrawCard!),
            ),
          ),
        ],
        if (_vm.handDrawCard != null &&
            (_vm.selectedImages.isNotEmpty || _vm.selectedImageUrls.isNotEmpty))
          const SizedBox(height: 12),
        if (_vm.selectedImages.isNotEmpty ||
            _vm.selectedImageUrls.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MoeTokens.pastelTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_rounded,
                        size: 14, color: MoeTokens.pastelTeal),
                    const SizedBox(width: 4),
                    Text(
                      '图片',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.pastelTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_vm.selectedImages.length + _vm.selectedImageUrls.length} 张',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: MoeTokens.greyDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...List.generate(_vm.selectedImages.length, (index) {
                return _buildImageThumb(
                  imageProvider: FileImage(_vm.selectedImages[index]),
                  onRemove: () => _removeImage(index),
                );
              }),
              ...List.generate(_vm.selectedImageUrls.length, (index) {
                final urlIndex = index + _vm.selectedImages.length;
                return _buildImageThumb(
                  imageProvider: NetworkImage(
                    resolveMediaUrl(_vm.selectedImageUrls[index]),
                  ),
                  onRemove: () => _removeImage(urlIndex),
                );
              }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _moodChip(String mood, TextTheme textTheme) {
    final selected = _vm.selectedMoodTag == mood;
    final color = _moodColors[mood]!;
    final icon = _moodIcons[mood]!;
    final label = _moodLabels[mood]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _vm.setMoodTag(selected ? null : mood);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? color.withValues(alpha: 0.5) : MoeTokens.lineSoft,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26, color: selected ? color : MoeTokens.inkMuted),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? color : MoeTokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicTags(TextTheme textTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _vm.selectedTopicTags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tag.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tag.color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${tag.name}',
                style: textTheme.labelSmall?.copyWith(color: tag.color),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  _vm.setTopicTags(
                    _vm.selectedTopicTags.where((t) => t != tag).toList(),
                  );
                },
                child: Icon(Icons.close_rounded, size: 14, color: tag.color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageThumb({
    required ImageProvider imageProvider,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: MoeTokens.danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40FF6B6B),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    if (!_vm.isEditMode && !_vm.isGroupPost && _vm.hasUnsavedChanges) {
      unawaited(_vm.saveDraft(_contentController.text));
    }
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
