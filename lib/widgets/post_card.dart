import 'package:flutter/material.dart';
import '../models/post.dart';
import '../widgets/avatar_image.dart';
import '../widgets/network_image.dart';
import '../widgets/topic_tag_selector.dart';
import '../widgets/like_button.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAvatarTap;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Hero(
                    tag: 'avatar_${post.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7F7FD5).withOpacity(0.3),
                            const Color(0xFF86A8E7).withOpacity(0.3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7F7FD5).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: NetworkAvatarImage(
                          imageUrl: post.userAvatar,
                          radius: 22,
                          placeholderIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 帖子内容
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _renderContentWithEmojis(post.content),
            ),

            // 话题标签
            if (post.topicTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.topicTags
                    .map((tag) => TopicTagDisplay(
                          tag: tag,
                          fontSize: 12,
                          showUsageCount: false,
                          onTap: () {
                            // 跳转到话题动态列表页面
                            Navigator.pushNamed(
                              context,
                              '/topic-posts',
                              arguments: tag,
                            );
                          },
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 12),

            // 帖子图片
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 4),
              post.images.length == 1
                  ? GestureDetector(
                      onTap: () {},
                      child: Hero(
                        tag: 'post_img_${post.id}_0',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: NetworkImageWidget(
                              imageUrl: post.images[0],
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: post.images.length,
                        itemBuilder: (context, imgIndex) {
                          return Container(
                            margin: EdgeInsets.only(
                              right: imgIndex < post.images.length - 1 ? 12 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () {},
                              child: Hero(
                                tag: 'post_img_${post.id}_$imgIndex',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: NetworkImageWidget(
                                      imageUrl: post.images[imgIndex],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],

            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey[200]!,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 帖子互动
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LikeButton(
                  isLiked: post.isLiked,
                  likeCount: post.likes,
                  onTap: onLike ?? () {},
                ),
                _buildActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    count: post.comments,
                    onTap: onComment ?? () {}),
                _buildActionButton(
                    icon: Icons.share_rounded, label: '分享', onTap: onShare ?? () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      int? count,
      String? label,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              if (count != null || label != null) ...[
                const SizedBox(width: 6),
                Text(
                  count?.toString() ?? label ?? '',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  Widget _renderContentWithEmojis(String content) {
    // 表情占位符正则表达式：[emoji:url]格式
    final emojiRegex = RegExp(r'\[emoji:(.*?)\]');
    final matches = emojiRegex.allMatches(content);

    if (matches.isEmpty) {
      // 如果没有表情占位符，直接返回普通文本
      return Text(
        content,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      );
    }

    // 构建富文本
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      // 添加匹配之前的普通文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ));
      }

      // 获取表情URL
      final emojiUrl = match.group(1) ?? '';

      // 添加表情图片
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.network(
            emojiUrl,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        ),
      ));

      lastIndex = match.end;
    }

    // 添加剩余的普通文本
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }
}
