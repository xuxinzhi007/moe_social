import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../auth_service.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../utils/error_handler.dart';
import '../widgets/avatar_image.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isLoadingUser = true;
  final ImagePicker _picker = ImagePicker();
  String? _userName;
  String? _userAvatar;

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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
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
      for (final image in _selectedImages) {
        final imageUrl = await ApiService.uploadImage(image);
        imageUrls.add(imageUrl);
      }

      final userId = AuthService.currentUser;
      if (userId == null) {
        ErrorHandler.showError(context, '请先登录');
        return;
      }

      final newPost = Post(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: _userName ?? '用户',
        userAvatar: _userAvatar ?? 'https://via.placeholder.com/150',
        content: _contentController.text.trim(),
        images: imageUrls,
        likes: 0,
        comments: 0,
        isLiked: false,
        createdAt: DateTime.now(),
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
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                             margin: const EdgeInsets.only(right: 12),
                             width: 110, // 明确宽度
                             height: 110, // 明确高度
                             child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: FileImage(_selectedImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
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

            // 工具栏
            Row(
              children: [
                _buildToolButton(
                  icon: Icons.image_rounded,
                  label: '图片',
                  color: Colors.green,
                  onTap: _addImage,
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
