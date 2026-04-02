import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/api_service.dart';
import '../../auth_service.dart';
import '../../utils/error_handler.dart';
import 'cloud_image_viewer_page.dart';

class CloudGalleryPage extends StatefulWidget {
  const CloudGalleryPage({Key? key, this.onImageSelected, this.isSelectMode = false}) : super(key: key);
  
  final Function(String)? onImageSelected;
  final bool isSelectMode;

  @override
  State<CloudGalleryPage> createState() => _CloudGalleryPageState();
}

class _CloudGalleryPageState extends State<CloudGalleryPage> {
  List<dynamic> _images = [];
  bool _isFetching = false;
  bool _isMutating = false;
  int _currentPage = 1;
  int _pageSize = 15;
  int _total = 0;
  bool _hasMore = true;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _seenKeys = <String>{};

  int? _maxBytes;
  int? _usedBytes;

  bool _selectMode = false;
  final Set<int> _selected = <int>{};
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 240) {
        _loadImages();
      }
    });
    _loadQuota();
    _loadImages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _busy => _isFetching || _isMutating;

  String _formatBytes(int bytes) {
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    final b = bytes.toDouble();
    if (b >= gb) return '${(b / gb).toStringAsFixed(2)} GB';
    if (b >= mb) return '${(b / mb).toStringAsFixed(1)} MB';
    if (b >= kb) return '${(b / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Future<void> _loadQuota() async {
    try {
      final result = await ApiService.get('/api/images/quota');
      final data = result['data'];
      if (data is Map) {
        final used = data['used_bytes'];
        final max = data['max_bytes'];
        setState(() {
          _usedBytes = used is num ? used.toInt() : int.tryParse('$used');
          _maxBytes = max is num ? max.toInt() : int.tryParse('$max');
        });
      }
    } catch (_) {}
  }
  
  Future<void> _loadImages({bool force = false}) async {
    if (_isFetching) return;
    if (!_hasMore && !force) return;

    setState(() {
      _isFetching = true;
    });
    
    try {
      final result = await ApiService.get('/api/images?page=$_currentPage&page_size=$_pageSize');
      if (result['success'] == true) {
        final images = result['data'] as List;
        setState(() {
          for (final it in images) {
            if (it is! Map) continue;
            final key = it['filename']?.toString() ?? it['id']?.toString() ?? '';
            if (key.isEmpty) {
              _images.add(it);
              continue;
            }
            if (_seenKeys.add(key)) {
              _images.add(it);
            }
          }
          _total = result['total'] as int;
          _hasMore = _images.length < _total;
          _currentPage++;
        });
      } else {
        ErrorHandler.showError(context, result['message'] ?? '加载图片失败');
      }
    } catch (e) {
      ErrorHandler.showError(context, '加载图片失败: $e');
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _refreshAll({bool exitSelect = true}) async {
    if (exitSelect) {
      _exitSelectMode();
    }
    setState(() {
      _images = [];
      _seenKeys.clear();
      _currentPage = 1;
      _hasMore = true;
      _total = 0;
    });

    await _loadQuota();
    await _loadImages(force: true);

    while (mounted && _hasMore && _images.length < _pageSize && !_isFetching) {
      await _loadImages(force: true);
    }
  }
  
  void _enterSelectMode({int? initialIndex}) {
    if (_selectMode) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _selectMode = true;
      _selected.clear();
      if (initialIndex != null) _selected.add(initialIndex);
    });
  }

  void _exitSelectMode() {
    if (!_selectMode) return;
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除确认', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('确定要删除选中的 ${_selected.length} 张图片吗？此操作无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isMutating = true);
    try {
      final indices = _selected.toList()..sort((a, b) => b.compareTo(a));
      for (final i in indices) {
        final image = _images[i] as Map;
        final filename = image['filename']?.toString() ?? '';
        if (filename.isEmpty) continue;
        await ApiService.delete('/api/images/$filename');
      }

      await _refreshAll(exitSelect: true);
      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已成功删除 ${_selected.length} 张图片');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '删除失败: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _bulkDownloadSelected() async {
    if (_selected.isEmpty) return;
    if (kIsWeb) {
      ErrorHandler.showError(context, 'Web 暂不支持下载，请使用手机端');
      return;
    }

    setState(() => _isMutating = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dio = Dio();
      final indices = _selected.toList()..sort();

      String? lastPath;
      for (final i in indices) {
        final image = _images[i] as Map;
        final url = image['url']?.toString() ?? '';
        final filename = image['filename']?.toString() ?? 'image_$i';
        if (url.isEmpty) continue;

        final safeName = filename.replaceAll('/', '_').replaceAll('\\', '_');
        final path = '${dir.path}${Platform.pathSeparator}$safeName';
        await dio.download(
          url,
          path,
          options: Options(
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 60),
          ),
        );
        lastPath = path;
      }

      if (!mounted) return;
      ErrorHandler.showSuccess(context, '已下载 ${_selected.length} 张图片到本地');
      if (lastPath != null) {
        await OpenFilex.open(lastPath);
      }
      _exitSelectMode();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '批量下载失败: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _pickAndUpload() async {
    if (kIsWeb) {
      ErrorHandler.showError(context, 'Web 暂不支持本地上传，请使用手机端');
      return;
    }
    final userId = AuthService.currentUser;
    if (userId == null) {
      ErrorHandler.showError(context, '请先登录');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                  ),
                  title: const Text('从相册选择', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.purple),
                  ),
                  title: const Text('拍照上传', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: source == ImageSource.camera ? 80 : 88,
      );
      if (picked == null) return;

      setState(() {
        _isMutating = true;
      });

      final imageInfo = await ApiService.uploadImageInfo(File(picked.path));

      if (!mounted) return;
      final key = imageInfo['filename']?.toString() ?? imageInfo['id']?.toString() ?? '';
      setState(() {
        if (key.isEmpty || _seenKeys.add(key)) {
          _images.insert(0, imageInfo);
          _total = (_total <= 0) ? _images.length : _total + 1;
          _hasMore = _images.length < _total;
        }
      });
      _loadQuota();
      ErrorHandler.showSuccess(context, '上传成功');
    } catch (e) {
      ErrorHandler.showError(context, '上传失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Widget _buildQuotaCard() {
    final maxBytes = _maxBytes ?? 0;
    final usedBytes = _usedBytes ?? 0;
    if (widget.isSelectMode || maxBytes <= 0) return const SizedBox.shrink();
    
    final progress = (usedBytes / maxBytes).clamp(0.0, 1.0);
    final isWarning = progress > 0.85;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isWarning ? Colors.red : Colors.blue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_done_outlined,
                  size: 20,
                  color: isWarning ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '云端存储空间',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已用 ${_formatBytes(usedBytes)} / 共 ${_formatBytes(maxBytes)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isWarning ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('图库空空如也', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('上传第一张图片'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _pickAndUpload,
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Moe 风格背景底色
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.isSelectMode
              ? '选择图片'
              : (_selectMode ? '已选 ${_selected.length} 项' : '我的云图库'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (!widget.isSelectMode && _selectMode) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.blueAccent),
              onPressed: _busy ? null : _bulkDownloadSelected,
              tooltip: '批量下载',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _busy ? null : _bulkDeleteSelected,
              tooltip: '批量删除',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _busy ? null : _exitSelectMode,
            ),
          ],
          if (!widget.isSelectMode && !_selectMode)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _refreshAll(exitSelect: false),
            ),
        ],
      ),
      floatingActionButton: widget.isSelectMode || _selectMode
          ? null
          : FloatingActionButton.extended(
              heroTag: "cloud_gallery_upload_button",
              onPressed: _busy ? null : _pickAndUpload,
              icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
              label: const Text('上传图片', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF7F7FD5), // Moe 主题色
              elevation: 4,
            ),
      body: Column(
        children: [
          _buildQuotaCard(),
          Expanded(
            child: _isFetching && _images.isEmpty
                ? GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 15,
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : _images.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _images.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _images.length) {
                            if (!_isFetching) {
                              Future.microtask(() => _loadImages());
                            }
                            return Center(
                              child: _isFetching
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const SizedBox(),
                            );
                          }

                          final image = _images[index];
                          final imageUrl = image['url'] as String;
                          final heroTag = 'cloud_image_$index';
                          final isSelected = _selected.contains(index);

                          return GestureDetector(
                            onLongPress: widget.isSelectMode
                                ? null
                                : () => _enterSelectMode(initialIndex: index),
                            onTap: () {
                              if (widget.onImageSelected != null) {
                                widget.onImageSelected!(imageUrl);
                                Navigator.pop(context);
                                return;
                              }
                              if (!widget.isSelectMode && _selectMode) {
                                _toggleSelected(index);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CloudImageViewerPage(
                                    images: _images,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: heroTag,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 400,
                                      placeholder: (context, _) => Shimmer.fromColors(
                                        baseColor: Colors.grey[200]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(color: Colors.white),
                                      ),
                                      errorWidget: (context, _, __) => Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                // 选中状态蒙层
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blueAccent, width: 3),
                                    ),
                                  ),
                                if (!widget.isSelectMode && _selectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.8),
                                      size: 24,
                                    ),
                                  ),
                                if (widget.isSelectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
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
    );
  }
}
