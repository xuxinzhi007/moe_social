import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../auth_service.dart';
import '../../models/achievement_unlock.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/api_service.dart';
import '../../services/achievement_hooks.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/app_message_widget.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/topic_tag_selector.dart';
import '../gallery/cloud_gallery_page.dart';
import '../../models/hand_draw_card.dart';
import 'hand_draw_editor_page.dart';
import '../../widgets/hand_draw/hand_draw_card_view.dart';
import '../../utils/hand_draw_raster.dart';
import '../../utils/media_url.dart';

class CreatePostPage extends StatefulWidget {
  /// 传入已有帖子时进入编辑模式，否则为新建发布模式。
  final Post? initialPost;

  /// 发帖成功后关联到该群组（需先发布动态再 link）。
  final String? groupId;

  const CreatePostPage({super.key, this.initialPost, this.groupId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _selectedImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  String? _userName;
  String? _userAvatar;
  List<TopicTag> _selectedTopicTags = [];
  HandDrawCardData? _handDrawCard;
  String? _selectedMoodTag;
  /// 发到群组时：null=校验中，true=已加入，false=未加入
  bool? _canPostToGroup;

  bool get _isEditMode => widget.initialPost != null;

  bool get _isGroupPost =>
      !_isEditMode &&
      widget.groupId != null &&
      widget.groupId!.trim().isNotEmpty;

  Future<void> _openHandDrawEditor() async {
    final data = await Navigator.push<HandDrawCardData>(
      context,
      MaterialPageRoute(builder: (_) => const HandDrawEditorPage()),
    );
    if (data != null && mounted) {
      setState(() => _handDrawCard = data);
      context.read<LoadingProvider>().setSuccess('手绘卡片已添加 ✨');
    }
  }

  void _removeHandDraw() {
    setState(() => _handDrawCard = null);
  }

  Future<void> _addImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  void _openCloudGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudGalleryPage(
          isSelectMode: true,
          onImageSelected: (imageUrl) {
            // 将选择的图片URL添加到列表中
            setState(() {
              _selectedImageUrls.add(imageUrl);
            });
            context.read<LoadingProvider>().setSuccess('图片已添加');
          },
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      } else {
        final urlIndex = index - _selectedImages.length;
        _selectedImageUrls.removeAt(urlIndex);
      }
    });
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
                const Text(
                  '选择话题标签',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                selectedTags: _selectedTopicTags,
                onTagsChanged: (tags) {
                  setState(() {
                    _selectedTopicTags = List<TopicTag>.from(tags);
                  });
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
    _loadUserInfo();
    if (_isGroupPost) {
      _loadGroupPostPermission();
    }
    // 编辑模式：预填原帖内容
    final init = widget.initialPost;
    if (init != null) {
      _contentController.text = init.displayCaption;
      _selectedImageUrls.addAll(init.images);
      _selectedTopicTags = List.from(init.topicTags);
      // 恢复手绘卡片
      if (init.handDrawCardJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(init.handDrawCardJson);
          if (decoded is Map<String, dynamic>) {
            _handDrawCard = HandDrawCardData.fromJson(decoded);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      return;
    }

    try {
      final user = await ApiService.getUserInfo(userId);
      if (!mounted) return;
      setState(() {
        _userName = user.username;
        _userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      });
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  Future<void> _loadGroupPostPermission() async {
    final gid = widget.groupId?.trim();
    if (gid == null || gid.isEmpty) return;
    final uid = AuthService.currentUser;
    if (uid == null) {
      if (mounted) setState(() => _canPostToGroup = false);
      return;
    }
    try {
      final group =
          await ApiService.getCommunityGroup(groupId: gid, userId: uid);
      if (!mounted) return;
      setState(() => _canPostToGroup = group.isJoined);
    } catch (e) {
      debugPrint('校验群成员资格失败: $e');
      if (mounted) setState(() => _canPostToGroup = false);
    }
  }

  Future<void> _publishPost() async {
    final caption = _contentController.text.trim();
    final hasLocalImages = _selectedImages.isNotEmpty;
    final hasCloudImages = _selectedImageUrls.isNotEmpty;
    if (caption.isEmpty &&
        _handDrawCard == null &&
        !hasLocalImages &&
        !hasCloudImages) {
      context.read<LoadingProvider>().setError(
            '写点文字、选几张图，或画一张手绘卡片再发布吧',
          );
      return;
    }

    if (_isEditMode) {
      await _saveEdit(caption);
      return;
    }

    if (_isGroupPost) {
      if (_canPostToGroup == null) {
        await _loadGroupPostPermission();
      }
      if (_canPostToGroup != true) {
        if (mounted) {
          MoeToast.info(context, '请先加入该群组再发帖');
        }
        return;
      }
    }

    final loadingProvider = context.read<LoadingProvider>();
    var pendingUnlocks = const <AchievementUnlock>[];
    await loadingProvider.executeOperation<Post>(
      key: LoadingKeys.createPost,
      operation: () async {
        final List<String> imageUrls = [];

        // 上传本地选择的图片
        for (final image in _selectedImages) {
          final imageUrl = await ApiService.uploadImage(image);
          imageUrls.add(imageUrl);
        }

        // 直接添加从云端图库选择的网络图片URL
        imageUrls.addAll(_selectedImageUrls);

        final userId = AuthService.currentUser;
        if (userId == null) {
          throw ApiException('请先登录', 401);
        }

        String handJson = '';
        String thumbUrl = '';
        if (_handDrawCard != null) {
          handJson = jsonEncode(_handDrawCard!.toJson());
          try {
            final png = await handDrawCardToPngBytes(_handDrawCard!);
            if (png != null && png.isNotEmpty) {
              thumbUrl = await ApiService.uploadImageBytes(
                png,
                filename: 'hand_draw_thumb.png',
              );
            }
          } catch (e) {
            // 缩略图上传失败不应阻断主流程；保留 hand_draw_card 让动态可正常发布。
            debugPrint('手绘缩略图上传失败，继续发布: $e');
          }
        }

        final newPost = Post(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          userName: _userName ?? '用户',
          userAvatar: _userAvatar ?? 'https://picsum.photos/150',
          content: caption,
          images: imageUrls,
          likes: 0,
          comments: 0,
          isLiked: false,
          createdAt: DateTime.now(),
          topicTags: _selectedTopicTags,
          handDrawCardJson: handJson,
          handDrawThumbUrl: thumbUrl,
          moodTag: _selectedMoodTag ?? '',
        );

        final created = await ApiService.createPostWithUnlocks(
          newPost,
          groupId: widget.groupId,
        );
        pendingUnlocks = created.newAchievements;
        final apiPost = created.post;
        // 接口有时不回手绘字段，合并本地已上传数据，避免列表里回放组件布局异常。
        return apiPost.copyWith(
          handDrawCardJson: apiPost.handDrawCardJson.isNotEmpty
              ? apiPost.handDrawCardJson
              : handJson,
          handDrawThumbUrl: apiPost.handDrawThumbUrl.isNotEmpty
              ? apiPost.handDrawThumbUrl
              : thumbUrl,
        );
      },
      onSuccess: (createdPost) {
        if (!mounted) return;
        loadingProvider.clearMessages();
        final msg = widget.groupId != null && widget.groupId!.isNotEmpty
            ? '已发布并同步到群组 ~(≧∇≦)/~'
            : '帖子发布成功！(≧∇≦)/';
        final uid = AuthService.currentUser;
        final unlocks = pendingUnlocks;
        Navigator.pop(context, createdPost);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (uid != null && unlocks.isNotEmpty) {
            AchievementHooks.scheduleServerUnlocks(uid, unlocks);
          }
          final rootCtx = AuthService.navigatorKey.currentContext;
          if (rootCtx != null) {
            MoeToast.success(rootCtx, msg);
          }
        });
      },
      onError: (_) {
        // 错误已由 LoadingProvider 统一显示
      },
    );
  }

  Future<void> _saveEdit(String caption) async {
    final loadingProvider = context.read<LoadingProvider>();
    final init = widget.initialPost!;
    await loadingProvider.executeOperation<Post>(
      key: LoadingKeys.createPost,
      operation: () async {
        final List<String> imageUrls = [];
        for (final image in _selectedImages) {
          imageUrls.add(await ApiService.uploadImage(image));
        }
        imageUrls.addAll(_selectedImageUrls);

        String? handJson;
        String? thumbUrl;
        if (_handDrawCard != null) {
          handJson = jsonEncode(_handDrawCard!.toJson());
          // 只有手绘内容有变化时才重新上传缩略图
          if (handJson != init.handDrawCardJson) {
            try {
              final png = await handDrawCardToPngBytes(_handDrawCard!);
              if (png != null && png.isNotEmpty) {
                thumbUrl = await ApiService.uploadImageBytes(
                  png,
                  filename: 'hand_draw_thumb.png',
                );
              }
            } catch (e) {
              // 编辑态同样容错：缩略图失败保留原图或空，不阻断保存。
              debugPrint('编辑动态时手绘缩略图上传失败，继续保存: $e');
              thumbUrl = init.handDrawThumbUrl;
            }
          } else {
            thumbUrl = init.handDrawThumbUrl;
          }
        }

        return await ApiService.updatePost(
          init.id,
          content: caption,
          images: imageUrls,
          topicTags: _selectedTopicTags
              .map((t) => {'name': t.name, 'color': t.color})
              .toList(),
          handDrawCard: handJson,
          handDrawThumbUrl: thumbUrl,
        );
      },
      onSuccess: (updated) {
        if (!mounted) return;
        Navigator.pop(context, updated);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final rootCtx = AuthService.navigatorKey.currentContext;
          if (rootCtx != null) {
            MoeToast.success(rootCtx, '动态已更新 ✨');
          }
        });
      },
      onError: (_) {},
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

  String get _weatherEmoji => '☀️';
  String get _weatherText => '晴朗';

  static const Map<String, Color> _moodColors = {
    'happy': Color(0xFFFFB347),
    'calm': Color(0xFF4ECDC4),
    'sad': Color(0xFF74b9ff),
    'excited': Color(0xFFFD79A8),
  };

  static const Map<String, String> _moodEmojis = {
    'happy': '😊',
    'calm': '😌',
    'sad': '😢',
    'excited': '🤩',
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
    final primaryColor = theme.primaryColor;
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? '编辑动态'
              : (_isGroupPost ? '发到本群' : '记录心情'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Color(0xFF2D3436),
          ),
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
            icon: const Icon(Icons.close_rounded, color: Color(0xFF636E72), size: 20),
            onPressed: () => Navigator.pop(context),
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
                onPressed:
                    _isGroupPost && _canPostToGroup != true ? null : _publishPost,
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
                child: Text(
                  _isEditMode ? '保存' : '发布',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 90, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isGroupPost && _canPostToGroup == false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2),
                          ),
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
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  _buildGreetingCard(scheme),

                  const SizedBox(height: 16),

                  _buildInputCard(scheme),

                  const SizedBox(height: 20),

                  if (!_isEditMode) ...[
                    _buildSectionTitle('💭 今天的心情'),
                    const SizedBox(height: 10),
                    _buildMoodChips(),
                    const SizedBox(height: 20),
                  ],

                  if (_selectedTopicTags.isNotEmpty) ...[
                    _buildSectionTitle('🏷️ 话题标签'),
                    const SizedBox(height: 10),
                    _buildTopicTags(scheme),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // 底部悬浮工具栏
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7F7FD5).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolIcon(Icons.brush_rounded, const Color(0xFF7F7FD5), _openHandDrawEditor),
                  _buildToolIcon(Icons.image_rounded, const Color(0xFF4ECDC4), _addImage),
                  _buildToolIcon(Icons.cloud_upload_rounded, const Color(0xFF74b9ff), _openCloudGallery),
                  _buildToolIcon(
                    Icons.tag_rounded,
                    const Color(0xFFFD79A8),
                    _openTopicTagSelector,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: scheme.outline.withValues(alpha: 0.15),
                  ),
                  _buildToolIcon(Icons.keyboard_hide_rounded, const Color(0xFFB2BEC3), () {
                    FocusScope.of(context).unfocus();
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(ColorScheme scheme) {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA8EDEA).withValues(alpha: 0.4),
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
              Text(
                '$_weatherEmoji  $_greeting，${_userName ?? '萌友'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_weatherEmoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      _weatherText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF636E72),
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF636E72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 4,
            decoration: InputDecoration(
              hintText: '写下此刻的想法...\n无论是开心的事，还是小小的烦恼，\n这里都是你的秘密花园 (｡･ω･｡)',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
                height: 1.6,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.6,
              color: Color(0xFF2D3436),
            ),
          ),

          if (_handDrawCard != null) ...[
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F7FD5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🎨 手绘卡片',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7F7FD5),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openHandDrawEditor,
                  child: const Text(
                    '改画',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7F7FD5),
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
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: HandDrawCardStatic(data: _handDrawCard!),
              ),
            ),
          ],

          if (_selectedImages.isNotEmpty || _selectedImageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🖼️ 图片',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedImages.length + _selectedImageUrls.length} 张',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB2BEC3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...List.generate(_selectedImages.length, (index) {
                  return _buildImageThumb(
                    imageProvider: FileImage(_selectedImages[index]),
                    onRemove: () => _removeImage(index),
                  );
                }),
                ...List.generate(_selectedImageUrls.length, (index) {
                  final urlIndex = index + _selectedImages.length;
                  return _buildImageThumb(
                    imageProvider: NetworkImage(
                      resolveMediaUrl(_selectedImageUrls[index]),
                    ),
                    onRemove: () => _removeImage(urlIndex),
                  );
                }),
              ],
            ),
          ],
        ],
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
            const Color(0xFFDFE6E9),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D3436),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildMoodChips() {
    return Row(
      children: [
        Expanded(
          child: _moodCard('happy'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _moodCard('calm'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _moodCard('sad'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _moodCard('excited'),
        ),
      ],
    );
  }

  Widget _moodCard(String mood) {
    final selected = _selectedMoodTag == mood;
    final color = _moodColors[mood]!;
    final emoji = _moodEmojis[mood]!;
    final label = _moodLabels[mood]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedMoodTag = selected ? null : mood;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : const Color(0xFFDFE6E9),
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
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : const Color(0xFF636E72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicTags(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedTopicTags.map((tag) {
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
                style: TextStyle(
                  color: tag.color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTopicTags.remove(tag);
                  });
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
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40FF6B6B),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
