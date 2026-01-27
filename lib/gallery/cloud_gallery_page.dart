import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../auth_service.dart';
import '../utils/error_handler.dart';
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
  bool _isFetching = false; // 列表加载中（分页）
  bool _isMutating = false; // 上传/删除等操作中
  int _currentPage = 1;
  int _pageSize = 10;
  int _total = 0;
  bool _hasMore = true;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

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
      // 接近底部自动加载下一页
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
    } catch (_) {
      // ignore quota errors silently
    }
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
          _images.addAll(images);
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
      _currentPage = 1;
      _hasMore = true;
      _total = 0;
    });

    await _loadQuota();
    await _loadImages(force: true);

    // 体验优化：如果删太多导致列表很空，自动补齐到至少一页
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
        title: const Text('批量删除'),
        content: Text('确定要删除已选择的 ${_selected.length} 张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
      ErrorHandler.showSuccess(context, '已删除 ${indices.length} 张');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, '批量删除失败: $e');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _bulkDownloadSelected() async {
    if (_selected.isEmpty) return;
    if (kIsWeb) {
      ErrorHandler.showError(context, 'Web 暂不支持下载，请用手机端');
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
      ErrorHandler.showSuccess(context, '已下载 ${indices.length} 张（保存在应用目录）');
      // 打开最后一张，方便用户“保存到相册/分享”
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
      ErrorHandler.showError(context, 'Web 暂不支持本地上传，请用手机端');
      return;
    }
    final userId = AuthService.currentUser;
    if (userId == null) {
      ErrorHandler.showError(context, '请先登录');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照上传'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        // 拍照图片往往很大，cpolar/移动网络容易在上传过程中断开（Broken pipe）。
        // 限制尺寸 + 压缩质量可以显著提高上传成功率。
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: source == ImageSource.camera ? 80 : 88,
      );
      if (picked == null) return;

      setState(() {
        _isMutating = true;
      });

      await ApiService.uploadImage(File(picked.path));

      // 上传后刷新列表（自动拉第一页，避免“必须点加载更多才出现”）
      if (!mounted) return;
      await _refreshAll(exitSelect: false);
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
  
  @override
  Widget build(BuildContext context) {
    final maxBytes = _maxBytes ?? 0;
    final usedBytes = _usedBytes ?? 0;
    final showQuota = !widget.isSelectMode && maxBytes > 0;
    final progress = maxBytes > 0 ? (usedBytes / maxBytes).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSelectMode
              ? '选择图片'
              : (_selectMode ? '已选择 ${_selected.length}' : '云端图库'),
        ),
        actions: [
          if (!widget.isSelectMode && _selectMode) ...[
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _busy ? null : _bulkDownloadSelected,
              tooltip: '批量下载',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _busy ? null : _bulkDeleteSelected,
              tooltip: '批量删除',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : _exitSelectMode,
              tooltip: '退出多选',
            ),
          ],
          if (!widget.isSelectMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _refreshAll(exitSelect: false);
              },
            ),
          if (!widget.isSelectMode)
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: (_busy || _selectMode) ? null : _pickAndUpload,
              tooltip: '上传图片',
            ),
        ],
      ),
      floatingActionButton: widget.isSelectMode
          ? null
          : FloatingActionButton(
              onPressed: (_busy || _selectMode) ? null : _pickAndUpload,
              child: const Icon(Icons.add_rounded),
            ),
      body: Column(
        children: [
          if (showQuota)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已用 ${_formatBytes(usedBytes)} / ${_formatBytes(maxBytes)}（剩余 ${_formatBytes((maxBytes - usedBytes).clamp(0, maxBytes))}）',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
          Expanded(
            child: _isFetching && _images.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _images.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _images.length) {
                        // 触底占位：自动触发下一页，同时保留点击兜底
                        if (!_isFetching) {
                          Future.microtask(() => _loadImages());
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _isFetching
                                ? const CircularProgressIndicator()
                                : const Text('加载更多'),
                          ),
                        );
                      }

                      final image = _images[index];
                      final imageUrl = image['url'] as String;
                      final heroTag = 'cloud_image_$index';
                      final isSelected = _selected.contains(index);

                      return Stack(
                        children: [
                          GestureDetector(
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
                            child: Hero(
                              tag: heroTag,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (!widget.isSelectMode && _selectMode)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: InkWell(
                                onTap: () => _toggleSelected(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected ? Colors.lightBlueAccent : Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          // 不再展示“单个删除按钮”：统一用长按多选批量删
                          if (widget.isSelectMode)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 16),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}