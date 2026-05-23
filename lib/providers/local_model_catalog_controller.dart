import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../config/hf_local_model_catalog.dart';
import '../models/local_llm_model_catalog_item.dart';
import '../services/local_model_store.dart';

/// 离线模型页状态：首屏同步内置清单，后台刷新已安装与镜像。
class LocalModelCatalogController extends ChangeNotifier {
  List<LocalLlmModelCatalogItem> catalog =
      HfLocalModelCatalog.withResolvedUrls();
  List<InstalledLocalLlmModel> installed = const [];
  bool syncing = false;
  String? error;
  String? downloadingId;
  double downloadProgress = 0;

  CancelToken? _cancelToken;
  DateTime? _lastProgressNotify;
  bool _initialized = false;

  bool get hasCatalog => catalog.isNotEmpty;

  bool isInstalled(String id) => installed.any((element) => element.id == id);

  /// 在首帧 paint 完成后触发，避免与 layout/semantics 冲突。
  void initAfterFirstFrame() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.scheduleTask(
        () => refresh(silent: true),
        Priority.idle,
      );
    });
  }

  Future<bool> refresh({bool silent = false}) async {
    if (!silent) {
      syncing = true;
      _safeNotify();
    }
    try {
      final nextCatalog = await LocalModelStore.instance.fetchCatalog();
      final nextInstalled = await LocalModelStore.instance.listInstalled();
      if (nextCatalog.isNotEmpty) {
        catalog = nextCatalog;
      }
      installed = nextInstalled;
      error = null;
      return true;
    } catch (e) {
      if (catalog.isEmpty) {
        error = e.toString().replaceFirst('Exception: ', '');
      }
      return false;
    } finally {
      syncing = false;
      _safeNotify();
    }
  }

  Future<void> download(LocalLlmModelCatalogItem item) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _lastProgressNotify = null;
    downloadingId = item.id;
    downloadProgress = 0;
    _safeNotify();

    try {
      await LocalModelStore.instance.downloadModel(
        item: item,
        cancelToken: _cancelToken,
        onProgress: _onDownloadProgress,
      );
      await refresh(silent: true);
    } finally {
      downloadingId = null;
      downloadProgress = 0;
      _safeNotify();
    }
  }

  void cancelDownload() => _cancelToken?.cancel();

  Future<void> deleteInstalled(String id) async {
    await LocalModelStore.instance.deleteInstalled(id);
    await refresh(silent: true);
  }

  void _onDownloadProgress(double progress) {
    final now = DateTime.now();
    final last = _lastProgressNotify;
    if (last != null &&
        progress < 1.0 &&
        now.difference(last).inMilliseconds < 150) {
      downloadProgress = progress;
      return;
    }
    _lastProgressNotify = now;
    downloadProgress = progress;
    _safeNotify();
  }

  void _safeNotify() {
    void emit() {
      if (hasListeners) notifyListeners();
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      emit();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(emit);
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

String huggingFaceRepoPageUrl(String repoId) {
  final repo = repoId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  if (repo.isEmpty) return 'https://huggingface.co/models';
  return 'https://huggingface.co/$repo';
}
