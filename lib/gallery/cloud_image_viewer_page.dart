import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/error_handler.dart';

class CloudImageViewerPage extends StatefulWidget {
  const CloudImageViewerPage({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  final List<dynamic> images; // expects {url, filename}
  final int initialIndex;

  @override
  State<CloudImageViewerPage> createState() => _CloudImageViewerPageState();
}

class _CloudImageViewerPageState extends State<CloudImageViewerPage> {
  late final PageController _controller;
  late int _index;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _title() => '${_index + 1}/${widget.images.length}';

  Future<void> _downloadCurrent() async {
    if (kIsWeb) {
      ErrorHandler.showError(context, 'Web 暂不支持下载，请用手机端');
      return;
    }
    if (_downloading) return;

    final image = widget.images[_index] as Map;
    final url = image['url']?.toString() ?? '';
    final filename = image['filename']?.toString() ?? 'image';
    if (url.isEmpty) return;

    setState(() => _downloading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = filename.replaceAll('/', '_').replaceAll('\\', '_');
      final path = '${dir.path}${Platform.pathSeparator}$safeName';

      final dio = Dio();
      await dio.download(
        url,
        path,
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已下载到本地：$safeName');
      // 直接打开（系统查看器里可“保存到相册/分享”）
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Text(_title()),
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
                : const Icon(Icons.download_outlined),
            tooltip: '下载',
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _controller,
        itemCount: widget.images.length,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        onPageChanged: (i) => setState(() => _index = i),
        builder: (context, i) {
          final image = widget.images[i] as Map;
          final url = image['url']?.toString() ?? '';
          final heroTag = 'cloud_image_$i';

          return PhotoViewGalleryPageOptions(
            heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '图片加载失败',
                    style: TextStyle(color: Colors.white70),
                  ),
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
            child: CircularProgressIndicator(
              value: progress,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        },
      ),
    );
  }
}

