import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../services/like_state_manager.dart';
import '../widgets/avatar_image.dart';
import '../widgets/network_image.dart';
import '../widgets/topic_tag_selector.dart';
import '../widgets/like_button.dart';
import '../widgets/moe_bouncing_button.dart';
import '../widgets/post_image_viewer.dart';
import '../widgets/hand_draw/hand_draw_card_view.dart';
import 'moe_loading.dart';
import '../utils/media_url.dart';
import '../utils/post_navigation.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAvatarTap;
  /// Hero 标签命名空间前缀。
  /// 在同一 Navigator 栈中若有多个页面都渲染 PostCard（如首页 + 用户主页），
  /// 必须传入不同的前缀，否则 Hero 标签重复会导致头像消失、无法点击。
  /// 首页（根页面）保持默认空字符串；其他嵌套页面传入唯一前缀，例如 'up_'。
  final String heroTagPrefix;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onAvatarTap,
    this.heroTagPrefix = '',
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
                      tag: '${heroTagPrefix}avatar_${post.id}',
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
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.link_rounded, color: Color(0xFF7F7FD5)),
                                  title: const Text('复制链接'),
                                  onTap: () => Navigator.pop(context),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.visibility_off_rounded, color: Colors.orange),
                                  title: const Text('不感兴趣'),
                                  onTap: () => Navigator.pop(context),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.report_rounded, color: Colors.red),
                                  title: const Text('举报'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showReportDialog(context, post);
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.more_horiz_rounded, color: theme.iconTheme.color?.withOpacity(0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 帖子正文（手绘数据已内嵌在 content 中，展示时剥离）
              if (post.isPendingModeration)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Icon(Icons.hourglass_top_rounded,
                          size: 16, color: Colors.amber[800]),
                      label: const Text('审核中', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.amber.shade50,
                    ),
                  ),
                ),

              if (post.displayCaption.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _renderContentWithEmojis(context, post.displayCaption),
                ),

              if (post.handDrawThumbUrl.isNotEmpty) ...[
                if (post.displayCaption.isNotEmpty) const SizedBox(height: 4),
                _HandDrawThumbnail(
                  post: post,
                  onOpenReplay: () =>
                      _openHandDrawViewer(context, post),
                ),
              ] else if (post.handDrawCard != null) ...[
                if (post.displayCaption.isNotEmpty) const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: HandDrawCardReplay(
                    data: post.handDrawCard!,
                    autoPlay: false,
                    duration: Duration(
                      milliseconds: (1600 + post.handDrawCard!.strokes.length * 35)
                          .clamp(1200, 3800),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => _openHandDrawViewer(context, post),
                    icon: const Icon(Icons.fullscreen_rounded, size: 20),
                    label: const Text('全屏回放绘画过程'),
                  ),
                ),
              ],

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
                const SizedBox(height: 8),
                _buildImageGrid(context, post.images, post.id),
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
                            postId: post.id,
                            userId: AuthService.currentUser ?? '',
                            isLiked: isLiked,
                            likeCount: likeCount,
                            onLikeChanged: (liked, count) {
                              onLike?.call();
                            },
                          );
                        },
                      );
                    },
                  ),
                  _buildActionButton(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      count: post.comments,
                      onTap: onComment ??
                          () {
                            openPostDetail(context, post);
                          }),
                  _buildActionButton(
                      context,
                      icon: Icons.share_rounded,
                      label: '分享',
                      onTap: onShare ?? () {
                        _handleShare(post);
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _handleShare(Post post) {
    final body = post.displayCaption.isEmpty && post.handDrawCard != null
        ? '[手绘卡片]'
        : post.displayCaption;
    final shareText = '''${post.userName} 的动态：

$body

#萌社 ${post.topicTags.isNotEmpty ? post.topicTags.map((t) => '#${t.name}').join(' ') : ''}''';

    Share.share(
      shareText,
      subject: '来自萌社的分享',
    );
  }

  static void _showReportDialog(BuildContext context, Post post) {
    final reasons = [
      {'icon': Icons.security_rounded, 'title': '垃圾营销', 'color': Colors.orange},
      {'icon': Icons.warning_rounded, 'title': '不实信息', 'color': Colors.red},
      {'icon': Icons.person_off_rounded, 'title': '人身攻击', 'color': Colors.purple},
      {'icon': Icons.casino_rounded, 'title': '违法违规', 'color': Colors.deepOrange},
      {'icon': Icons.face_rounded, 'title': '色情低俗', 'color': Colors.pink},
      {'icon': Icons.more_horiz_rounded, 'title': '其他原因', 'color': Colors.grey},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.report_rounded, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('举报内容', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            leading: Icon(r['icon'] as IconData, color: r['color'] as Color),
            title: Text(r['title'] as String),
            onTap: () {
              Navigator.pop(context);
              _submitReport(context, post, r['title'] as String);
            },
          )).toList(),
        ),
      ),
    );
  }

  static Future<void> _submitReport(
      BuildContext context, Post post, String reason) async {
    final uid = AuthService.currentUser;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录后再举报'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      await ApiService.reportPost(
        postId: post.id,
        reporterUserId: uid,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已提交「$reason」举报，感谢反馈'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('举报失败：$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildActionButton(
      BuildContext context,
      {required IconData icon,
      int? count,
      String? label,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return MoeBouncingButton(
      onTap: onTap,
      scaleFactor: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.5),
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
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> images, String postId) {
    if (images.isEmpty) return const SizedBox.shrink();

    // 单张大图
    if (images.length == 1) {
      return GestureDetector(
        onTap: () {
          PostImageViewer.show(
            context,
            imageUrls: images,
            postId: postId,
            heroTagPrefix: heroTagPrefix,
            initialIndex: 0,
          );
        },
        child: Hero(
          tag: '${heroTagPrefix}post_img_${postId}_0',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: NetworkImageWidget(
              imageUrl: images[0],
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // 2-4张图使用2列，其他使用3列
    int crossAxisCount = images.length == 2 || images.length == 4 ? 2 : 3;
    double spacing = 6.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSpacing = spacing * (crossAxisCount - 1);
          final itemSize = (constraints.maxWidth - totalSpacing) / crossAxisCount;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(images.length, (index) {
              return GestureDetector(
                onTap: () {
                  PostImageViewer.show(
                    context,
                    imageUrls: images,
                    postId: postId,
                    heroTagPrefix: heroTagPrefix,
                    initialIndex: index,
                  );
                },
                child: Hero(
                  tag: '${heroTagPrefix}post_img_${postId}_$index',
                  child: NetworkImageWidget(
                    imageUrl: images[index],
                    width: itemSize,
                    height: itemSize,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }),
          );
        }
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
          child: CachedNetworkImage(
            imageUrl: emojiUrl,
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

/// 手绘缩略图：叠加播放按钮，点击全屏回放笔迹（有 JSON 时）或放大静图。
class _HandDrawThumbnail extends StatelessWidget {
  const _HandDrawThumbnail({
    required this.post,
    required this.onOpenReplay,
  });

  final Post post;
  final VoidCallback onOpenReplay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenReplay,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: resolveMediaUrl(post.handDrawThumbUrl),
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.grey.shade100),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 68,
                    color: Colors.white.withOpacity(0.94),
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
                if (post.handDrawCard == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Text(
                      '点击查看大图',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _openHandDrawViewer(BuildContext context, Post post) {
  final card = post.handDrawCard;
  final thumb = post.handDrawThumbUrl;

  if (card != null) {
    final duration = Duration(
      milliseconds: (1600 + card.strokes.length * 35).clamp(1200, 3800),
    );
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(context).height * 0.75;
        final maxW = MediaQuery.sizeOf(context).width - 24;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxW),
                child: HandDrawCardReplay(
                  data: card,
                  autoPlay: true,
                  duration: duration,
                ),
              ),
            ],
          ),
        );
      },
    );
    return;
  }

  if (thumb.isNotEmpty) {
    final thumbResolved = resolveMediaUrl(thumb);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: thumbResolved,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    width: 200,
                    height: 280,
                    child: Center(
                      child: MoeSmallLoading(
                        color: Colors.white70,
                        size: 28,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
