import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/media_url.dart';

/// 帖子图片全屏查看器
/// - 支持多图翻页、双指缩放
/// - 支持下拉手势退出（背景跟随透明度渐变）
/// - heroTags 与 PostCard 里的 tag 一一对应，确保 Hero 动画衔接正确
class PostImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> heroTags;
  final int initialIndex;

  const PostImageViewer({
    super.key,
    required this.imageUrls,
    required this.heroTags,
    this.initialIndex = 0,
  });

  /// 从 [PostCard] 中调用的便捷入口
  /// [heroTagPrefix] 和 [postId] 需要与 PostCard 里保持一致
  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    required String postId,
    String heroTagPrefix = '',
    int initialIndex = 0,
  }) {
    final tags = List.generate(
      imageUrls.length,
      (i) => '${heroTagPrefix}post_img_${postId}_$i',
    );
    final resolved =
        imageUrls.map((u) => resolveMediaUrl(u)).toList(growable: false);
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => PostImageViewer(
          imageUrls: resolved,
          heroTags: tags,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<PostImageViewer> createState() => _PostImageViewerState();
}

class _PostImageViewerState extends State<PostImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  double _dragOffset = 0.0;
  bool _isDragging = false;

  double get _bgOpacity =>
      (1.0 - (_dragOffset.abs() / 220.0)).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _isDragging = true;
      _dragOffset += d.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dragOffset.abs() > 100 ||
        d.velocity.pixelsPerSecond.dy.abs() > 600) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 180),
          color: Colors.black.withOpacity(_bgOpacity),
          child: Stack(
            children: [
              // ── 图片画廊 ──
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PhotoViewGallery.builder(
                  pageController: _pageController,
                  itemCount: widget.imageUrls.length,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  builder: (_, i) => PhotoViewGalleryPageOptions(
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: widget.heroTags[i],
                    ),
                    imageProvider:
                        CachedNetworkImageProvider(widget.imageUrls[i]),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3.0,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 64),
                    ),
                  ),
                  loadingBuilder: (_, event) => Center(
                    child: CircularProgressIndicator(
                      value: event?.expectedTotalBytes == null
                          ? null
                          : event!.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),

              // ── 顶部操作栏 ──
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (widget.imageUrls.length > 1)
                        _PageIndicator(
                          current: _currentIndex,
                          total: widget.imageUrls.length,
                        ),
                    ],
                  ),
                ),
              ),

              // ── 下拉退出提示 ──
              if (_isDragging && _dragOffset.abs() > 40)
                Positioned(
                  bottom: 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('松开退出',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${current + 1} / $total',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
