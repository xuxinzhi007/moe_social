import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../config/hf_local_model_catalog.dart';
import '../models/local_llm_model_catalog_item.dart';
import 'api_service.dart';

/// 非 Web / 非 dart:io 平台：仅展示目录，不支持安装。
class LocalModelStore {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  Future<List<InstalledLocalLlmModel>> listInstalled() async => const [];

  Future<String?> resolveModelPath(String id) async => null;

  Future<bool> isInstalled(String id) async => false;

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
    final uri =
        Uri.parse('${ApiService.baseUrl}/api/llm/local-models/catalog');
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
    throw UnsupportedError('Web 端不支持下载 GGUF，请使用 iOS/Android 或 macOS 应用');
  }

  Future<void> deleteInstalled(String id) async {}

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
        return 'Hugging Face';
      case LocalModelSource.serverMirror:
        return '服务器镜像';
    }
  }
}
