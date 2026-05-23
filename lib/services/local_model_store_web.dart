import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/hf_local_model_catalog.dart';
import '../models/local_llm_model_catalog_item.dart';
import 'api_service.dart';

/// Web：模型登记在浏览器侧，推理时由 llamadart 从 HF 缓存加载。
class LocalModelStore {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  static const String _manifestKey = 'moe_local_models_web_installed_v1';

  Future<List<InstalledLocalLlmModel>> listInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_manifestKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (m) => InstalledLocalLlmModel.fromJson(
              Map<String, dynamic>.from(m),
            ),
          )
          .where((e) => e.id.isNotEmpty && e.filePath.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> resolveModelPath(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final installed = await listInstalled();
    for (final item in installed) {
      if (item.id == trimmed) return item.filePath;
    }
    return null;
  }

  Future<bool> isInstalled(String id) async {
    final path = await resolveModelPath(id);
    return path != null && path.isNotEmpty;
  }

  Future<List<LocalLlmModelCatalogItem>> fetchCatalog({
    bool includeServerMirror = true,
  }) async {
    final merged = <String, LocalLlmModelCatalogItem>{
      for (final item in HfLocalModelCatalog.withResolvedUrls()) item.id: item,
    };
    if (includeServerMirror) {
      try {
        final serverItems = await _fetchServerCatalog();
        for (final item in serverItems) {
          merged[item.id] = item;
        }
      } catch (_) {}
    }
    return merged.values.toList()
      ..sort((a, b) {
        if (a.recommended != b.recommended) {
          return a.recommended ? -1 : 1;
        }
        return a.sizeBytes.compareTo(b.sizeBytes);
      });
  }

  Future<List<LocalLlmModelCatalogItem>> _fetchServerCatalog() async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/llm/local-models/catalog');
    final response = await http
        .get(
          uri,
          headers: ApiService.mergeTunnelHeaders(
            uri,
            headers: {
              if (ApiService.token case final t?) 'Authorization': 'Bearer $t',
            },
          ),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['success'] == false) return const [];
    final rawItems = decoded['items'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map(
          (m) => LocalLlmModelCatalogItem.fromJson(
            Map<String, dynamic>.from(m),
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<InstalledLocalLlmModel> downloadModel({
    required LocalLlmModelCatalogItem item,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final source = item.hfModelSourceUri ?? item.downloadPath.trim();
    if (source.isEmpty) {
      throw Exception('该模型缺少 Web 可用的下载源');
    }

    onProgress?.call(0.05);
    if (cancelToken?.isCancelled == true) {
      throw DioException(
          requestOptions: RequestOptions(), type: DioExceptionType.cancel);
    }

    final installed = InstalledLocalLlmModel(
      id: item.id,
      name: item.name,
      filename: item.filename,
      filePath: source,
      sizeBytes: item.sizeBytes,
      sha256: item.sha256,
      installedAt: DateTime.now(),
      source: item.source,
      hfRepoId: item.hfRepoId,
    );
    await _upsertInstalled(installed);
    onProgress?.call(1.0);
    if (kDebugMode) {
      debugPrint('✅ [LocalGGUF/Web] registered: ${item.id} -> $source');
    }
    return installed;
  }

  Future<void> deleteInstalled(String id) async {
    final list = await listInstalled();
    final next = list.where((e) => e.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _manifestKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _upsertInstalled(InstalledLocalLlmModel model) async {
    final list = await listInstalled();
    final next = [
      for (final item in list)
        if (item.id != model.id) item,
      model,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _manifestKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static String sourceLabel(LocalModelSource source) {
    switch (source) {
      case LocalModelSource.huggingFace:
        return 'Hugging Face（浏览器缓存）';
      case LocalModelSource.serverMirror:
        return '服务器镜像';
    }
  }
}
