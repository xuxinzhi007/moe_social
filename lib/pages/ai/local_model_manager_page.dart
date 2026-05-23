import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/local_llm_model_catalog_item.dart';
import '../../providers/local_model_catalog_controller.dart';
import '../../services/local_model_store.dart';
import '../../widgets/moe_toast.dart';

class LocalModelManagerPage extends StatefulWidget {
  const LocalModelManagerPage({super.key});

  @override
  State<LocalModelManagerPage> createState() => _LocalModelManagerPageState();
}

class _LocalModelManagerPageState extends State<LocalModelManagerPage> {
  late final LocalModelCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocalModelCatalogController();
    _controller.initAfterFirstFrame();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final ok = await _controller.refresh();
    if (!mounted) return;
    if (!ok && _controller.hasCatalog) {
      MoeToast.error(context, '同步失败，仍显示内置模型清单');
    }
  }

  Future<void> _onDownload(LocalLlmModelCatalogItem item) async {
    try {
      await _controller.download(item);
      if (!mounted) return;
      final doneMsg =
          kIsWeb ? '「${item.name}」已登记，首次对话时由浏览器下载并缓存' : '「${item.name}」已保存到本机';
      MoeToast.success(context, doneMsg);
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
    }
  }

  Future<void> _onDelete(InstalledLocalLlmModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除本地模型'),
        content: Text(
          '确定删除「${item.name}」？\n将释放 ${LocalModelStore.formatBytes(item.sizeBytes)} 空间。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _controller.deleteInstalled(item.id);
    if (!mounted) return;
    MoeToast.success(context, '已删除');
  }

  Future<void> _openHuggingFaceRepo(String repoId) async {
    final uri = Uri.parse(huggingFaceRepoPageUrl(repoId));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      MoeToast.error(context, '无法打开 Hugging Face 页面');
    }
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

  Widget _sourceBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        kIsWeb
            ? '模型来自 Hugging Face 开源 GGUF 仓库。登记后首次对话时由浏览器拉取并缓存（需 WebGPU），在 App 内 llama.cpp 推理。'
            : '模型来自 Hugging Face 开源 GGUF 仓库，下载到本机后在 App 内 llama.cpp 推理。可选合并服务器镜像加速。',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _catalogCard(LocalLlmModelCatalogItem item) {
    final installed = _controller.isInstalled(item.id);
    final downloading = _controller.downloadingId == item.id;

    return Container(
      key: ValueKey('catalog_${item.id}'),
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
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openHuggingFaceRepo(item.hfRepoId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.hfRepoId,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey[700],
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.35,
              ),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _controller.downloadProgress > 0
                    ? _controller.downloadProgress
                    : null,
                minHeight: 8,
                color: const Color(0xFF7F7FD5),
                backgroundColor:
                    const Color(0xFF7F7FD5).withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '下载中 ${(_controller.downloadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (installed) ...[
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF91EAE4), size: 20),
                const SizedBox(width: 6),
                Text(
                  '已安装到本机',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              const Spacer(),
              if (downloading)
                TextButton(
                  onPressed: _controller.cancelDownload,
                  child: const Text('取消'),
                )
              else if (!installed)
                ElevatedButton(
                  onPressed: _controller.downloadingId != null
                      ? null
                      : () => _onDownload(item),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF7F7FD5),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(kIsWeb ? '登记模型' : '下载到手机'),
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
            onPressed: () => _onDelete(item),
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_controller.hasCatalog && _controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _controller.error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onRefresh,
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
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sourceBanner(),
          const SizedBox(height: 20),
          if (_controller.installed.isNotEmpty) ...[
            _sectionTitle(
              '已安装',
              kIsWeb ? '已登记，推理时由浏览器缓存加载' : '保存在应用私有目录，卸载 App 会一并删除',
            ),
            ..._controller.installed.map(_installedCard),
            const SizedBox(height: 16),
          ],
          _sectionTitle(
            '可下载',
            _controller.catalog.isEmpty
                ? '暂无模型条目'
                : kIsWeb
                    ? '点击登记；首次对话时下载'
                    : '默认从 Hugging Face 直下；支持断点续传',
          ),
          if (_controller.catalog.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '暂无可下载模型。请检查网络或更新 App 内置模型清单。',
                style: TextStyle(color: Colors.grey[600], height: 1.4),
              ),
            )
          else
            ..._controller.catalog.map(_catalogCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            centerTitle: true,
            title: const Text('离线模型'),
            actions: [
              if (_controller.syncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              IconButton(
                onPressed: _controller.syncing ? null : _onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }
}
