import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../auth_service.dart';
import '../models/post.dart';
import '../models/topic_tag.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../utils/error_handler.dart';
import '../widgets/avatar_image.dart';
import '../widgets/compact_topic_selector.dart';
import '../emoji/emoji_store_page.dart';
import '../gallery/cloud_gallery_page.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _selectedImageUrls = []; // 用于存储从云端图库选择的网络图片URL
  bool _isLoading = false;
  bool _isLoadingUser = true;
  final ImagePicker _picker = ImagePicker();
  String? _userName;
  String? _userAvatar;
  List<TopicTag> _selectedTopicTags = []; // 话题标签列表

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
            ErrorHandler.showSuccess(context, '图片已添加');
          },
        ),
      ),
    );
  }
  
  void _openEmojiStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmojiStorePage(
          onEmojiSelected: (emojiUrl) {
            // 将选择的表情URL插入到文本内容中
            final controller = _contentController;
            final cursorPosition = controller.selection.baseOffset;
            final text = controller.text;
            
            // 确保cursorPosition在有效范围内
            final safeCursorPosition = cursorPosition >= 0 && cursorPosition <= text.length ? cursorPosition : text.length;
            
            // 在光标位置插入表情URL占位符
            final newText = text.substring(0, safeCursorPosition) + '[emoji:$emojiUrl]' + text.substring(safeCursorPosition);
            controller.text = newText;
            
            // 将光标移动到插入内容之后
            controller.selection = TextSelection.collapsed(offset: safeCursorPosition + '[emoji:$emojiUrl]'.length);
            
            ErrorHandler.showSuccess(context, '表情已添加');
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
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      setState(() {
        _isLoadingUser = false;
      });
      return;
    }

    try {
      final user = await ApiService.getUserInfo(userId);
      setState(() {
        _userName = user.username;
        _userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
        _isLoadingUser = false;
      });
    } catch (e) {
      print('加载用户信息失败: $e');
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _publishPost() async {
    if (_contentController.text.trim().isEmpty) {
      ErrorHandler.showError(context, '请输入帖子内容');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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
        ErrorHandler.showError(context, '请先登录');
        return;
      }

      final newPost = Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: _userName ?? '用户',
        userAvatar: _userAvatar ?? 'https://picsum.photos/150',
        content: _contentController.text.trim(),
        images: imageUrls,
        likes: 0,
        comments: 0,
        isLiked: false,
        createdAt: DateTime.now(),
        topicTags: _selectedTopicTags, // 添加话题标签
      );

      await PostService.createPost(newPost);

      if (!mounted) return;

      ErrorHandler.showSuccess(context, '帖子发布成功！(≧∇≦)/');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('发布新动态', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 修复：使用 Container + Alignment 代替 Padding，解决 RenderBox size 错误
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: SizedBox(
              height: 32, // 给定固定高度
              child: ElevatedButton(
                onPressed: _isLoading ? null : _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: Size.zero, // 允许更小的尺寸
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 紧凑布局
                ),
                child: _isLoading 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('发布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息栏
            if (!_isLoadingUser)
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5),
                      ],
                    ),
                    child: NetworkAvatarImage(
                      imageUrl: _userAvatar,
                      radius: 24,
                      placeholderIcon: Icons.person,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? '用户',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        '分享此时此刻...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            const SizedBox(height: 20),

            // 内容输入卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '写点什么吧... (例如: 今天天气真好~)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                      hintStyle: TextStyle(color: Colors.black26),
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  
                  // 图片预览区域
                  if (_selectedImages.isNotEmpty || _selectedImageUrls.isNotEmpty)
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + _selectedImageUrls.length,
                        itemBuilder: (context, index) {
                          Widget imageWidget;
                          
                          if (index < _selectedImages.length) {
                            // 显示本地选择的图片
                            imageWidget = Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: FileImage(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          } else {
                            // 显示从云端图库选择的网络图片
                            final urlIndex = index - _selectedImages.length;
                            final imageUrl = _selectedImageUrls[urlIndex];
                            imageWidget = Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }
                          
                          return Container(
                             margin: const EdgeInsets.only(right: 12),
                             width: 110, // 明确宽度
                             height: 110, // 明确高度
                             child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: imageWidget,
                                ),
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // 话题标签选择器 - 紧凑版
            CompactTopicSelector(
              selectedTags: _selectedTopicTags,
              onTagsChanged: (tags) {
                setState(() {
                  _selectedTopicTags = tags;
                });
              },
              userId: AuthService.currentUser ?? 'guest',
              maxTags: 3,
            ),

            const SizedBox(height: 20),

            // 工具栏 - 使用SingleChildScrollView允许横向滚动
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildToolButton(
                    icon: Icons.image_rounded,
                    label: '图片',
                    color: Colors.green,
                    onTap: _addImage,
                  ),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    icon: Icons.cloud_upload_outlined,
                    label: '云端图库',
                    color: Colors.blue,
                    onTap: _openCloudGallery,
                  ),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    icon: Icons.emoji_emotions_outlined,
                    label: '表情',
                    color: Colors.purple,
                    onTap: _openEmojiStore,
                  ),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    icon: Icons.alternate_email_rounded,
                    label: '提到',
                    color: Colors.orange,
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _buildToolButton(
                    icon: Icons.tag_rounded,
                    label: '话题',
                    color: Colors.blue,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
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
