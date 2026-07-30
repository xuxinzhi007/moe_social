import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/api_response.dart';
import '../../services/gallery_service.dart';
import '../../auth_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/error_handler.dart';
import '../../utils/media_url.dart';
import '../../utils/public_download_directory.dart';
import '../../widgets/moe_action_row.dart';
import 'cloud_image_viewer_page.dart';

class CloudGalleryPage extends StatefulWidget {
  const CloudGalleryPage(
      {super.key, this.onImageSelected, this.isSelectMode = false});

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

  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < 680;
  }

  int _gridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1280) return 5;
    if (width >= 960) return 4;
    if (width >= 680) return 3;
    return 2;
  }

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
      final data = await GalleryService.getQuota();
      if (data.isNotEmpty) {
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
      final result = await GalleryService.listImages(
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (ApiResponse.isSuccess(result)) {
        final images =
            ApiResponse.listOf(result, keys: const ['images', 'data']);
        setState(() {
          for (final it in images) {
            if (it is! Map) continue;
            final key =
                it['filename']?.toString() ?? it['id']?.toString() ?? '';
            if (key.isEmpty) {
              _images.add(it);
              continue;
            }
            if (_seenKeys.add(key)) {
              _images.add(it);
            }
          }
          _total = ApiResponse.intField(result, 'total') ?? _images.length;
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
        title:
            const Text('删除确认', style: TextStyle(fontWeight: FontWeight.bold)),
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
        await GalleryService.deleteImage(filename);
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
      final dir = await resolvePublicDownloadDirectory();
      final dio = Dio();
      final indices = _selected.toList()..sort();

      String? lastPath;
      for (final i in indices) {
        final image = _images[i] as Map;
        final url = image['url']?.toString() ?? '';
        final filename = image['filename']?.toString() ?? 'image_$i';
        if (url.isEmpty) continue;
        final resolvedUrl = resolveMediaUrl(url);

        final safeName = filename.replaceAll('/', '_').replaceAll('\\', '_');
        final path = '${dir.path}${Platform.pathSeparator}$safeName';
        await dio.download(
          resolvedUrl,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MoeActionRow(
                    icon: Icons.photo_library_outlined,
                    iconColor: MoeTokens.primary,
                    title: '从相册选择',
                    titleStyle: const TextStyle(fontWeight: FontWeight.w500),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MoeActionRow(
                    icon: Icons.camera_alt_outlined,
                    iconColor: MoeTokens.secondary,
                    title: '拍照上传',
                    titleStyle: const TextStyle(fontWeight: FontWeight.w500),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
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

      final imageInfo = await GalleryService.uploadImageInfo(File(picked.path));

      if (!mounted) return;
      final key = imageInfo['filename']?.toString() ??
          imageInfo['id']?.toString() ??
          '';
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

  Widget _buildHeroHeader(BuildContext context) {
    final compact = _isCompactLayout(context);
    final maxBytes = _maxBytes ?? 0;
    final usedBytes = _usedBytes ?? 0;
    final progress =
        maxBytes > 0 ? (usedBytes / maxBytes).clamp(0.0, 1.0) : 0.0;
    final remainingBytes =
        maxBytes > usedBytes ? _formatBytes(maxBytes - usedBytes) : '0 B';

    return Container(
      margin: EdgeInsets.fromLTRB(12, 10, 12, compact ? 10 : 18),
      padding: EdgeInsets.all(compact ? 14 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF8F6FF),
            Color(0xFFEFF4FF),
            Color(0xFFFDF9FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: MoeTokens.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 42 : 58,
                height: compact ? 42 : 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(compact ? 14 : 18),
                ),
                child: Icon(
                  Icons.cloud_circle_rounded,
                  size: compact ? 22 : 32,
                  color: MoeTokens.primary,
                ),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '把灵感收进云端',
                      style: TextStyle(
                        fontSize: compact ? 18 : 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF25273A),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      _images.isEmpty
                          ? '从第一张图开始整理你的收藏、头像素材和创作灵感。'
                          : '你的图片会统一存放在这里，随时回看、下载或继续挑选使用。',
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        height: compact ? 1.4 : 1.5,
                        color: const Color(0xFF69708A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.collections_outlined,
                label: '已存图片',
                value: '${_images.length}',
              ),
              _buildInfoChip(
                icon: Icons.auto_awesome_outlined,
                label: '剩余空间',
                value: maxBytes > 0 ? remainingBytes : '未统计',
              ),
              _buildInfoChip(
                icon: Icons.backup_outlined,
                label: '云端状态',
                value: _busy ? '同步中' : '可上传',
              ),
            ],
          ),
          if (maxBytes > 0) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '空间使用情况',
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF30344B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(MoeTokens.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '已用 ${_formatBytes(usedBytes)} / 共 ${_formatBytes(maxBytes)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A819B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MoeTokens.primary),
          const SizedBox(width: 6),
          Text(
            '$label  ',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF77809A),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E3142),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final compact = _isCompactLayout(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, compact ? 16 : 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          padding: EdgeInsets.all(compact ? 18 : 30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(compact ? 22 : 30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 68 : 100,
                height: compact ? 68 : 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MoeTokens.primary.withValues(alpha: 0.16),
                      const Color(0xFF9BD8FF).withValues(alpha: 0.22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(compact ? 22 : 30),
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: compact ? 32 : 48,
                  color: MoeTokens.primary,
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                '你的云图库还在等待第一批灵感',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 18 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2A2C3E),
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                '上传头像素材、创作参考图或日常收藏图，让它们在这里被整齐保存，也方便后续发帖时直接取用。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: compact ? 1.45 : 1.6,
                  color: const Color(0xFF737B93),
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFeatureTag(Icons.bolt_rounded, '上传后立即可用'),
                  _buildFeatureTag(Icons.folder_copy_outlined, '统一整理常用图片'),
                  _buildFeatureTag(Icons.phone_iphone_rounded, '移动端也更顺手'),
                ],
              ),
              SizedBox(height: compact ? 18 : 24),
              FilledButton.icon(
                onPressed: _busy ? null : _pickAndUpload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('上传第一张图片'),
                style: FilledButton.styleFrom(
                  backgroundColor: MoeTokens.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, compact ? 48 : 54),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 22 : 28,
                    vertical: compact ? 14 : 16,
                  ),
                  textStyle: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MoeTokens.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B627A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground, // Moe 风格背景底色
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
              icon:
                  const Icon(Icons.download_rounded, color: Colors.blueAccent),
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
      floatingActionButton: widget.isSelectMode ||
              _selectMode ||
              _images.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: "cloud_gallery_upload_button",
              onPressed: _busy ? null : _pickAndUpload,
              icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
              label: const Text('上传图片',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: MoeTokens.primary, // Moe 主题色
              elevation: 4,
            ),
      body: Column(
        children: [
          _buildHeroHeader(context),
          Expanded(
            child: _isFetching && _images.isEmpty
                ? GridView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCompactLayout(context) ? 12 : 16,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridCrossAxisCount(context),
                      crossAxisSpacing: _isCompactLayout(context) ? 8 : 10,
                      mainAxisSpacing: _isCompactLayout(context) ? 8 : 10,
                      childAspectRatio: 1,
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
                        padding: EdgeInsets.fromLTRB(
                          _isCompactLayout(context) ? 12 : 16,
                          0,
                          _isCompactLayout(context) ? 12 : 16,
                          _isCompactLayout(context) ? 88 : 96,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridCrossAxisCount(context),
                          crossAxisSpacing: _isCompactLayout(context) ? 8 : 10,
                          mainAxisSpacing: _isCompactLayout(context) ? 8 : 10,
                          childAspectRatio: 1,
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
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const SizedBox(),
                            );
                          }

                          final image = _images[index];
                          final imageUrl = image['url'] as String;
                          final displayUrl = resolveMediaUrl(imageUrl);
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
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                      child: CachedNetworkImage(
                                      imageUrl: displayUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 400,
                                      maxWidthDiskCache: 800,
                                      maxHeightDiskCache: 800,
                                      placeholder: (context, _) =>
                                          Shimmer.fromColors(
                                        baseColor: Colors.grey[200]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(color: Colors.white),
                                      ),
                                      errorWidget: (context, _, __) =>
                                          Container(
                                        color: Colors.grey[100],
                                        child: const Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                // 选中状态蒙层
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blueAccent, width: 3),
                                    ),
                                  ),
                                if (!widget.isSelectMode && _selectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? Colors.blueAccent
                                          : Colors.white.withValues(alpha: 0.8),
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
                                      child: const Icon(Icons.check,
                                          color: Colors.white, size: 14),
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
