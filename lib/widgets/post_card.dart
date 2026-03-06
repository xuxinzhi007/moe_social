import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/like_state_manager.dart';
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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08), // 使用主题色阴影
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
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
                              primaryColor.withOpacity(0.3),
                              secondaryColor.withOpacity(0.3),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.scaffoldBackgroundColor, // 适配暗黑模式
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        Text(
                          _formatTime(post.createdAt),
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color ?? Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.more_horiz_rounded, color: theme.iconTheme.color?.withOpacity(0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 帖子内容
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _renderContentWithEmojis(context, post.content),
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
                                    color: Colors.black.withOpacity(0.05),
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
                                            color: Colors.black.withOpacity(0.05),
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
              Divider(
                height: 1, 
                color: theme.dividerColor.withOpacity(0.1),
              ),
              const SizedBox(height: 12),

              // 帖子互动
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: LikeStateManager().getStatusNotifier(
                      post.id,
                      initialValue: post.isLiked,
                    ),
                    builder: (context, isLiked, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: LikeStateManager().getCountNotifier(
                          post.id,
                          initialValue: post.likes,
                        ),
                        builder: (context, likeCount, _) {
                          return LikeButton(
                            isLiked: isLiked,
                            likeCount: likeCount,
                            onTap: onLike ?? () {},
                          );
                        },
                      );
                    },
                  ),
                  _buildActionButton(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      count: post.comments,
                      onTap: onComment ?? () {}),
                  _buildActionButton(
                      context,
                      icon: Icons.share_rounded, label: '分享', onTap: onShare ?? () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      {required IconData icon,
      int? count,
      String? label,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.primaryColor.withOpacity(0.1),
        highlightColor: theme.primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.5), // 轻微背景色
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.iconTheme.color?.withOpacity(0.6), size: 20),
              if (count != null || label != null) ...[
                const SizedBox(width: 6),
                Text(
                  count?.toString() ?? label ?? '',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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

  Widget _renderContentWithEmojis(BuildContext context, String content) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: 15,
      height: 1.6,
      letterSpacing: 0.2,
      color: theme.textTheme.bodyLarge?.color,
    );

    // 表情占位符正则表达式：[emoji:url]格式
    final emojiRegex = RegExp(r'\[emoji:(.*?)\]');
    final matches = emojiRegex.allMatches(content);

    if (matches.isEmpty) {
      // 如果没有表情占位符，直接返回普通文本
      return Text(
        content,
        style: textStyle,
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
          style: textStyle,
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
        style: textStyle,
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }
}
