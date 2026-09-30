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
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/motion/moe_pressable.dart';
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
  final TopicTagService _topicTagService = TopicTagService();
  List<TopicTag> _suggestedTopics = const [];
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

  void _removeImage(ComposerImage slot) {
    _vm.removeComposerImage(slot);
  }

  void _openTopicTagSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final media = MediaQuery.of(bottomSheetContext);
        final available = media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            12;
        var sheetHeight = media.size.height * 0.72;
        if (sheetHeight > available) sheetHeight = available;
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Container(
            height: sheetHeight,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: MoeTokens.surface2,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(MoeTokens.radius2xl),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: MoeTokens.lineSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '搜索话题',
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
      },
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
    _suggestedTopics = _topicTagService.getRecommendedTags(
      AuthService.currentUser ?? 'guest',
    );
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
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: MoeTokens.gradientPageBg),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: _buildPageTitle(
              _vm.isEditMode ? '编辑动态' : (_vm.isGroupPost ? '发到本群' : '发帖子'),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MoeTokens.cardBackground,
                shape: BoxShape.circle,
                boxShadow: MoeTokens.shadowSm(),
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
                    onPressed: _publishPost,
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
              padding: const EdgeInsets.fromLTRB(
                MoeTokens.spaceLg,
                88,
                MoeTokens.spaceLg,
                MoeTokens.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.communityIdentity?.isValid == true) ...[
                    MoeReveal(
                      delay: Duration.zero,
                      child: _buildCommunityIdentityBanner(textTheme),
                    ),
                    const SizedBox(height: MoeTokens.spaceMd),
                  ],
                  MoeReveal(
                    delay: Duration.zero,
                    child: _buildInputCard(textTheme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageTitle(String title) {
    return ShaderMask(
      shaderCallback: (bounds) => MoeTokens.gradientText.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildComposerHeader(TextTheme textTheme) {
    final now = DateTime.now();
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: MoeTokens.gradientMintBlush,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MoeTokens.radius2xl),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded,
              size: 18, color: MoeTokens.pastelOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_greeting，${_vm.userName ?? '萌友'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: MoeTokens.inkDark,
              ),
            ),
          ),
          Text(
            '${now.month}月${now.day}日 周$weekday',
            style: textTheme.labelSmall?.copyWith(
              color: MoeTokens.inkMuted,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
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
                    color: MoeTokens.inkMuted,
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
    final hasAttachments =
        _vm.handDrawCard != null || _vm.composerImages.isNotEmpty;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowMd(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_vm.isEditMode && !_vm.isGroupPost)
            _buildComposerHeader(textTheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceLg,
              MoeTokens.spaceMd,
              MoeTokens.spaceLg,
              MoeTokens.spaceLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: _formKey,
                  child: MoeInputField(
                    controller: _contentController,
                    hintText: '写下此刻的想法…',
                    maxLines: 8,
                    minLines: 3,
                    filled: true,
                    fillColor: MoeTokens.softChipBg,
                    keyboardType: TextInputType.multiline,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty &&
                          _vm.handDrawCard == null &&
                          _vm.composerImages.isEmpty) {
                        return '写点文字、选几张图，或画一张手绘卡片再发布吧';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                _buildFormActions(textTheme),
                if (hasAttachments) ...[
                  const SizedBox(height: MoeTokens.spaceMd),
                  _buildAttachments(textTheme),
                ],
                if (!_vm.isEditMode) ...[
                  const SizedBox(height: MoeTokens.spaceLg),
                  _buildSectionTitle(textTheme, '心情'),
                  const SizedBox(height: MoeTokens.spaceSm),
                  _buildMoodChips(textTheme),
                ],
                const SizedBox(height: MoeTokens.spaceLg),
                _buildTopicHeader(textTheme),
                const SizedBox(height: MoeTokens.spaceSm),
                _buildTopicPicker(textTheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormActions(TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: _formActionChip(
            icon: Icons.brush_rounded,
            label: '手绘',
            color: MoeTokens.primary,
            onTap: _openHandDrawEditor,
          ),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        Expanded(
          child: _formActionChip(
            icon: Icons.photo_outlined,
            label: '相册',
            color: MoeTokens.pastelTeal,
            onTap: _addImage,
          ),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        Expanded(
          child: _formActionChip(
            icon: Icons.cloud_outlined,
            label: '图库',
            color: MoeTokens.pastelBlue,
            onTap: _openCloudGallery,
          ),
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
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTopic(TopicTag tag) {
    final selected = _vm.selectedTopicTags;
    final exists = selected.any((item) => item.id == tag.id);
    if (exists) {
      _vm.setTopicTags(selected.where((item) => item.id != tag.id).toList());
      return;
    }
    if (selected.length >= 5) {
      MoeToast.warning(context, '最多 5 个话题');
      return;
    }
    _vm.setTopicTags([...selected, tag]);
  }

  Widget _buildTopicPicker(TextTheme textTheme) {
    final selectedIds = _vm.selectedTopicTags.map((tag) => tag.id).toSet();
    final extraSelected = _vm.selectedTopicTags
        .where((tag) => !_suggestedTopics.any((item) => item.id == tag.id))
        .toList();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final tag in _suggestedTopics) ...[
            _topicChoiceChip(
              textTheme,
              tag,
              selected: selectedIds.contains(tag.id),
              onTap: () => _toggleTopic(tag),
            ),
            const SizedBox(width: MoeTokens.spaceSm),
          ],
          for (final tag in extraSelected) ...[
            _topicChoiceChip(
              textTheme,
              tag,
              selected: true,
              onTap: () => _toggleTopic(tag),
            ),
            const SizedBox(width: MoeTokens.spaceSm),
          ],
          _buildTopicSearchChip(textTheme),
        ],
      ),
    );
  }

  Widget _topicChoiceChip(
    TextTheme textTheme,
    TopicTag tag, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionFast;
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: AnimatedContainer(
        duration: motion,
        curve: Curves.easeInOut,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? tag.color.withValues(alpha: 0.16)
              : MoeTokens.softChipBg,
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(
            color: selected
                ? tag.color.withValues(alpha: 0.55)
                : MoeTokens.surfaceBorder,
          ),
        ),
        child: Text(
          selected ? '#${tag.name}' : tag.name,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? tag.color : MoeTokens.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSearchChip(TextTheme textTheme) {
    return MoePressable(
      onTap: _openTopicTagSelector,
      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MoeTokens.pastelPink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(
            color: MoeTokens.pastelPink.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded,
                size: 15, color: MoeTokens.pastelPink),
            const SizedBox(width: 4),
            Text(
              '搜索',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: MoeTokens.pastelPink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicHeader(TextTheme textTheme) {
    return Row(
      children: [
        Text(
          '话题',
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: MoeTokens.titleText,
          ),
        ),
        const Spacer(),
        Text(
          '${_vm.selectedTopicTags.length}/5',
          style: textTheme.labelSmall?.copyWith(
            color: MoeTokens.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Text(
      title,
      style: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: MoeTokens.titleText,
      ),
    );
  }

  Widget _buildMoodChips(TextTheme textTheme) {
    return Row(
      children: [
        for (final mood in _moodLabels.keys) ...[
          Expanded(child: _moodChip(mood, textTheme)),
          if (mood != _moodLabels.keys.last)
            const SizedBox(width: MoeTokens.spaceSm),
        ],
      ],
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
              height: 128,
              width: double.infinity,
              child: HandDrawCardStatic(data: _vm.handDrawCard!),
            ),
          ),
        ],
        if (_vm.handDrawCard != null && _vm.composerImages.isNotEmpty)
          const SizedBox(height: 12),
        if (_vm.composerImages.isNotEmpty) ...[
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
                '${_vm.composerImages.length} 张',
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
              for (final slot in _vm.composerImages)
                _buildImageThumb(
                  imageProvider: slot.file != null
                      ? FileImage(slot.file!)
                      : NetworkImage(resolveMediaUrl(slot.remoteUrl ?? ''))
                          as ImageProvider,
                  uploading: slot.uploading,
                  error: slot.error,
                  onRetry: slot.error == null
                      ? null
                      : () => _vm.retryComposerImage(slot),
                  onRemove: () => _removeImage(slot),
                ),
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

    final motion =
        moeReduceMotion(context) ? Duration.zero : MoeTokens.motionMedium;

    return MoePressable(
      onTap: () => _vm.setMoodTag(selected ? null : mood),
      pressedScale: MoeTokens.motionPressScaleStrong,
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      child: AnimatedScale(
        duration: motion,
        curve: Curves.easeInOut,
        scale: selected && !moeReduceMotion(context) ? 1.03 : 1,
        child: AnimatedContainer(
          duration: motion,
          curve: Curves.easeInOut,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.2) : MoeTokens.softChipBg,
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : MoeTokens.surfaceBorder,
            ),
            boxShadow: selected ? MoeTokens.shadowSm() : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: motion,
                curve: Curves.easeInOut,
                scale: selected ? 1.08 : 1,
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? color : MoeTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? color : MoeTokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumb({
    required ImageProvider imageProvider,
    required VoidCallback onRemove,
    bool uploading = false,
    String? error,
    VoidCallback? onRetry,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onRetry,
          child: Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: uploading || (error != null && error.isNotEmpty)
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: Center(
                      child: uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  )
                : null,
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
