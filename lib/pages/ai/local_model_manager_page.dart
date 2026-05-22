import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/local_llm_model_catalog_item.dart';
import '../../services/local_model_store.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';

class LocalModelManagerPage extends StatefulWidget {
  const LocalModelManagerPage({super.key});

  @override
  State<LocalModelManagerPage> createState() => _LocalModelManagerPageState();
}

class _LocalModelManagerPageState extends State<LocalModelManagerPage> {
  bool _loading = true;
  String? _error;
  List<LocalLlmModelCatalogItem> _catalog = const [];
  List<InstalledLocalLlmModel> _installed = const [];

  String? _downloadingId;
  double _downloadProgress = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await LocalModelStore.instance.fetchCatalog();
      final installed = await LocalModelStore.instance.listInstalled();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _installed = installed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isInstalled(String id) => _installed.any((element) => element.id == id);

  Future<void> _download(LocalLlmModelCatalogItem item) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    setState(() {
      _downloadingId = item.id;
      _downloadProgress = 0;
    });

    try {
      await LocalModelStore.instance.downloadModel(
        item: item,
        cancelToken: _cancelToken,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _downloadProgress = p);
        },
      );
      if (!mounted) return;
      final doneMsg = kIsWeb
          ? '「${item.name}」已登记，首次对话时由浏览器下载并缓存'
          : '「${item.name}」已保存到本机';
      MoeToast.success(context, doneMsg);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) {
        MoeToast.error(context, '已取消下载');
      } else {
        MoeToast.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _downloadProgress = 0;
        });
      }
    }
  }

  Future<void> _delete(InstalledLocalLlmModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除本地模型'),
        content: Text(
            '确定删除「${item.name}」？\n将释放 ${LocalModelStore.formatBytes(item.sizeBytes)} 空间。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await LocalModelStore.instance.deleteInstalled(item.id);
    if (!mounted) return;
    MoeToast.success(context, '已删除');
    await _reload();
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _catalogCard(LocalLlmModelCatalogItem item) {
    final installed = _isInstalled(item.id);
    final downloading = _downloadingId == item.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.recommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF91EAE4).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '推荐',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${LocalModelStore.formatBytes(item.sizeBytes)} · ${item.parametersB > 0 ? '${item.parametersB}B' : 'GGUF'} · ${LocalModelStore.sourceLabel(item.source)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (item.hfRepoId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.hfRepoId,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700], height: 1.35),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 8,
                color: const Color(0xFF7F7FD5),
                backgroundColor:
                    const Color(0xFF7F7FD5).withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '下载中 ${(_downloadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (installed)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF91EAE4), size: 20),
              if (installed) const SizedBox(width: 6),
              if (installed)
                Text(
                  '已安装到本机',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              const Spacer(),
              if (downloading)
                TextButton(
                  onPressed: () => _cancelToken?.cancel(),
                  child: const Text('取消'),
                )
              else if (!installed)
                ElevatedButton(
                  onPressed:
                      _downloadingId != null ? null : () => _download(item),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF7F7FD5),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('下载到手机'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _installedCard(InstalledLocalLlmModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF86A8E7).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sd_storage_rounded, color: Color(0xFF7F7FD5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  LocalModelStore.formatBytes(item.sizeBytes),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _delete(item),
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('离线模型'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7F7FD5)),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reload,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF7F7FD5),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF7F7FD5),
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FadeInUp(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '从 Hugging Face 直下到手机。安装后可在「模型来源」选「本机 GGUF（离线）」聊天；推荐 1.5B 以使用记忆工具。建议在 Wi‑Fi 下下载。',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_installed.isNotEmpty) ...[
                        FadeInUp(
                          delay: const Duration(milliseconds: 80),
                          child: _sectionTitle(
                            '已安装',
                            '保存在应用私有目录，卸载 App 会一并删除',
                          ),
                        ),
                        ..._installed.map(_installedCard),
                        const SizedBox(height: 16),
                      ],
                      FadeInUp(
                        delay: const Duration(milliseconds: 120),
                        child: _sectionTitle(
                          '可下载',
                          _catalog.isEmpty
                              ? '暂无模型条目'
                              : '默认从 Hugging Face 直下；支持断点续传',
                        ),
                      ),
                      if (_catalog.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '暂无可下载模型。请检查网络或更新 App 内置模型清单。',
                            style:
                                TextStyle(color: Colors.grey[600], height: 1.4),
                          ),
                        )
                      else
                        ..._catalog.map(_catalogCard),
                    ],
                  ),
                ),
    );
  }
}
