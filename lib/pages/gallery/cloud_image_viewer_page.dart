import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../utils/error_handler.dart';
import '../../utils/media_url.dart';

class CloudImageViewerPage extends StatefulWidget {
  const CloudImageViewerPage({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  final List<dynamic> images; // expects {url, filename, size}
  final int initialIndex;

  @override
  State<CloudImageViewerPage> createState() => _CloudImageViewerPageState();
}

class _CloudImageViewerPageState extends State<CloudImageViewerPage> {
  late final PageController _controller;
  late int _index;
  bool _downloading = false;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
    
    // 设置全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    // 恢复正常系统UI模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '未知大小';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    final b = bytes.toDouble();
    if (b >= mb) return '${(b / mb).toStringAsFixed(2)} MB';
    if (b >= kb) return '${(b / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Future<void> _downloadCurrent() async {
    if (kIsWeb) {
      ErrorHandler.showError(context, 'Web端暂不支持下载，请使用App');
      return;
    }
    if (_downloading) return;

    final image = widget.images[_index] as Map;
    final url = image['url']?.toString() ?? '';
    final filename = image['filename']?.toString() ?? 'image_$_index.jpg';
    if (url.isEmpty) return;
    final resolvedUrl = resolveMediaUrl(url);

    setState(() => _downloading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = filename.replaceAll('/', '_').replaceAll('\\', '_');
      final path = '${dir.path}${Platform.pathSeparator}$safeName';

      final dio = Dio();
      await dio.download(
        resolvedUrl,
        path,
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已保存到本地');
      
      // 震动反馈
      HapticFeedback.lightImpact();
      
      // 可以直接打开文件
      // await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.images[_index] as Map;
    final fileSize = currentImage['size'] as int?;
    final filename = currentImage['filename']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 图片查看器
          GestureDetector(
            onTap: _toggleUI,
            child: PhotoViewGallery.builder(
              pageController: _controller,
              itemCount: widget.images.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onPageChanged: (i) {
                setState(() => _index = i);
                HapticFeedback.selectionClick();
              },
              builder: (context, i) {
                final image = widget.images[i] as Map;
                final url = image['url']?.toString() ?? '';
                final displayUrl = resolveMediaUrl(url);
                final heroTag = 'cloud_image_$i';

                return PhotoViewGalleryPageOptions(
                  heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                  imageProvider: CachedNetworkImageProvider(displayUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text('图片加载失败', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    );
                  },
                );
              },
              loadingBuilder: (context, event) {
                final progress = (event == null || event.expectedTotalBytes == null)
                    ? null
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes!;
                return Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                    ),
                  ),
                );
              },
            ),
          ),

          // 顶部导航栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            top: _showUI ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    onPressed: _downloading ? null : _downloadCurrent,
                    icon: _downloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: '保存到本地',
                  ),
                ],
              ),
            ),
          ),

          // 底部信息栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            bottom: _showUI ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 30,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filename.isNotEmpty)
                    Text(
                      filename.split('/').last, // 如果包含路径只显示文件名
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.sd_storage_outlined, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatBytes(fileSize),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
