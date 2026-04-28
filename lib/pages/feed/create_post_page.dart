import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../auth_service.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/api_service.dart';
import '../../services/achievement_hooks.dart';
import '../../providers/loading_provider.dart';
import '../../widgets/compact_topic_selector.dart';
import '../../widgets/app_message_widget.dart';
import '../gallery/cloud_gallery_page.dart';
import '../../models/hand_draw_card.dart';
import 'hand_draw_editor_page.dart';
import '../../widgets/hand_draw/hand_draw_card_view.dart';
import '../../utils/hand_draw_raster.dart';
import '../../utils/media_url.dart';

class CreatePostPage extends StatefulWidget {
  /// 传入已有帖子时进入编辑模式，否则为新建发布模式。
  final Post? initialPost;
  const CreatePostPage({super.key, this.initialPost});

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

  bool get _isEditMode => widget.initialPost != null;

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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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
      setState(() {
        _userName = user.username;
        _userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      });
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
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

    final loadingProvider = context.read<LoadingProvider>();
    await loadingProvider.executeOperation<void>(
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
          final png = await handDrawCardToPngBytes(_handDrawCard!);
          if (png != null && png.isNotEmpty) {
            thumbUrl = await ApiService.uploadImageBytes(
              png,
              filename: 'hand_draw_thumb.png',
            );
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
        );

        await ApiService.createPost(newPost);
        try {
          await AchievementHooks.recordPostPublished(
            userId,
            imageCount: imageUrls.length,
            contentLength: caption.length,
          );
        } catch (_) {}
      },
      onSuccess: (_) {
        loadingProvider.setSuccess('帖子发布成功！(≧∇≦)/');
        Navigator.pop(context, true);
      },
      onError: (_) {
        // 错误已由 LoadingProvider 统一显示
      },
    );
  }

  Future<void> _saveEdit(String caption) async {
    final loadingProvider = context.read<LoadingProvider>();
    final init = widget.initialPost!;
    await loadingProvider.executeOperation<void>(
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
            final png = await handDrawCardToPngBytes(_handDrawCard!);
            if (png != null && png.isNotEmpty) {
              thumbUrl = await ApiService.uploadImageBytes(
                png,
                filename: 'hand_draw_thumb.png',
              );
            }
          } else {
            thumbUrl = init.handDrawThumbUrl;
          }
        }

        final updated = await ApiService.updatePost(
          init.id,
          content: caption,
          images: imageUrls,
          topicTags: _selectedTopicTags
              .map((t) => {'name': t.name, 'color': t.color})
              .toList(),
          handDrawCard: handJson,
          handDrawThumbUrl: thumbUrl,
        );
        if (mounted) Navigator.pop(context, updated);
      },
      onSuccess: (_) {
        loadingProvider.setSuccess('动态已更新 ✨');
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _isEditMode ? '编辑动态' : '记录心情',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: SizedBox(
              height: 32,
              width: 70,
              child: LoadingButton(
                operationKey: LoadingKeys.createPost,
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _isEditMode ? '保存' : '发布',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 100), // 底部留出工具栏空间
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期和天气（装饰性）
                  Row(
                    children: [
                      Text(
                        '${DateTime.now().month}月${DateTime.now().day}日',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[800],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wb_sunny_rounded, size: 14, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('晴朗', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // 输入区域 - 无边框设计
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 5,
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
                      fontSize: 16, 
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_handDrawCard != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '手绘卡片',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openHandDrawEditor,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('改画'),
                        ),
                        IconButton(
                          onPressed: _removeHandDraw,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: Colors.red[300],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: HandDrawCardStatic(data: _handDrawCard!),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 图片预览区域 - 拍立得风格
                  if (_selectedImages.isNotEmpty || _selectedImageUrls.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...List.generate(_selectedImages.length, (index) {
                          return _buildPolaroidImage(
                            imageProvider: FileImage(_selectedImages[index]),
                            onRemove: () => _removeImage(index),
                          );
                        }),
                        ...List.generate(_selectedImageUrls.length, (index) {
                          final urlIndex = index + _selectedImages.length;
                          return _buildPolaroidImage(
                            imageProvider: NetworkImage(
                              resolveMediaUrl(_selectedImageUrls[index]),
                            ),
                            onRemove: () => _removeImage(urlIndex),
                          );
                        }),
                      ],
                    ),
                  
                  const SizedBox(height: 30),

                  // 话题标签
                  if (_selectedTopicTags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedTopicTags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tag.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tag.color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${tag.name}', 
                              style: TextStyle(
                                color: tag.color, 
                                fontSize: 12,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTopicTags.remove(tag);
                                });
                              },
                              child: Icon(Icons.close, size: 14, color: tag.color),
                            )
                          ],
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ),
          
          // 底部悬浮工具栏
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolIcon(Icons.brush_rounded, const Color(0xFF7F7FD5), _openHandDrawEditor),
                  _buildToolIcon(Icons.image_rounded, Colors.green, _addImage),
                  _buildToolIcon(Icons.cloud_upload_rounded, Colors.blue, _openCloudGallery),
                  _buildToolIcon(Icons.tag_rounded, Colors.purple, () {
                    // 临时打开话题选择器
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: CompactTopicSelector(
                          selectedTags: _selectedTopicTags,
                          onTagsChanged: (tags) {
                            setState(() {
                              _selectedTopicTags = tags;
                            });
                          },
                          userId: AuthService.currentUser ?? 'guest',
                          maxTags: 5,
                        ),
                      ),
                    );
                  }),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey[200],
                  ),
                  _buildToolIcon(Icons.keyboard_hide_rounded, Colors.grey, () {
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

  Widget _buildPolaroidImage({required ImageProvider imageProvider, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 120,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton(
            onPressed: onRemove,
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
