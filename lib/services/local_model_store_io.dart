import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/hf_local_model_catalog.dart';
import '../models/local_llm_model_catalog_item.dart';
import 'api_service.dart';

/// 离线 GGUF：优先从 Hugging Face 直下到手机；可选合并后端镜像清单。
class LocalModelStore {
  LocalModelStore._();

  static final LocalModelStore instance = LocalModelStore._();

  static const String _manifestFileName = 'installed.json';

  Dio? _dio;

  Dio get _client {
    return _dio ??= Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(hours: 6),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          // HF CDN 对无 User-Agent 的请求偶发限流
          'User-Agent': 'MoeSocial/1.0 (Flutter; local-gguf-download)',
        },
      ),
    );
  }

  Future<Directory> _modelsRootDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Web 端暂不支持将 GGUF 下载到本机');
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'moe_local_models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _manifestFile() async {
    final dir = await _modelsRootDir();
    return File(p.join(dir.path, _manifestFileName));
  }

  Future<List<InstalledLocalLlmModel>> listInstalled() async {
    if (kIsWeb) return const [];
    final file = await _manifestFile();
    if (!await file.exists()) return const [];

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      final out = <InstalledLocalLlmModel>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final model = InstalledLocalLlmModel.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (await File(model.filePath).exists()) {
          out.add(model);
        }
      }
      return out;
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

  /// 主清单：内置 Hugging Face 推荐模型；可选追加后端镜像（需登录/API）。
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
      } catch (_) {
        // 后端未配置镜像时不影响 HF 直下
      }
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
    ApiService.logDirectHttp('GET', uri);
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
        .map((m) {
          final item = LocalLlmModelCatalogItem.fromJson(
            Map<String, dynamic>.from(m),
          );
          if (item.downloadPath.isEmpty) return item;
          final path = item.downloadPath.startsWith('http')
              ? item.downloadPath
              : '${ApiService.baseUrl}${item.downloadPath.startsWith('/') ? '' : '/'}${item.downloadPath}';
          return LocalLlmModelCatalogItem(
            id: item.id,
            name: item.name,
            filename: item.filename,
            sizeBytes: item.sizeBytes,
            sha256: item.sha256,
            description:
                item.description.isEmpty ? '服务器镜像（可选）' : item.description,
            parametersB: item.parametersB,
            recommended: item.recommended,
            downloadPath: path,
            source: LocalModelSource.serverMirror,
          );
        })
        .where((e) => e.id.isNotEmpty && e.downloadPath.isNotEmpty)
        .toList();
  }

  Uri _downloadUri(LocalLlmModelCatalogItem item) {
    final path = item.downloadPath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    throw Exception('无效的下载地址');
  }

  Future<InstalledLocalLlmModel> downloadModel({
    required LocalLlmModelCatalogItem item,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 端暂不支持下载离线模型');
    }

    final uri = _downloadUri(item);
    final root = await _modelsRootDir();
    final finalPath = p.join(root.path, '${item.id}.gguf');
    final partPath = '$finalPath.part';
    final partFile = File(partPath);
    final finalFile = File(finalPath);

    var startByte = 0;
    if (await partFile.exists()) {
      startByte = await partFile.length();
    } else if (await finalFile.exists()) {
      await finalFile.delete();
    }

    final headers = <String, String>{
      if (startByte > 0) 'Range': 'bytes=$startByte-',
    };

    final sink = partFile.openWrite(
      mode: startByte > 0 ? FileMode.append : FileMode.write,
    );
    try {
      final response = await _client.get<ResponseBody>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (code) =>
              code != null && (code == 200 || code == 206 || code == 416),
          followRedirects: true,
        ),
        cancelToken: cancelToken,
      );

      final status = response.statusCode ?? 0;
      if (status != 200 && status != 206 && status != 416) {
        throw Exception(
            '下载失败: HTTP $status（${item.isHuggingFace ? 'Hugging Face' : '服务器'}）');
      }

      var totalBytes = item.sizeBytes;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        final totalPart = contentRange.split('/').last.trim();
        totalBytes = int.tryParse(totalPart) ?? totalBytes;
      } else {
        final totalHeader = response.headers.value('content-length');
        final parsed = int.tryParse(totalHeader ?? '');
        if (parsed != null && parsed > 0) {
          totalBytes = startByte > 0 ? startByte + parsed : parsed;
        }
      }
      var received = startByte;

      await for (final chunk in response.data?.stream ?? const Stream.empty()) {
        sink.add(chunk);
        received += (chunk as List<int>).length;
        if (onProgress != null && totalBytes > 0) {
          onProgress((received / totalBytes).clamp(0.0, 1.0));
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        throw Exception(
          '无法访问模型文件（${item.hfRepoId}）。若为国内网络，可稍后重试或改用服务器镜像。',
        );
      }
      rethrow;
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (!await partFile.exists() || await partFile.length() == 0) {
      throw Exception('下载为空，请检查网络或模型文件名是否已在 Hugging Face 更新');
    }

    final shaExpected = item.sha256.trim().toLowerCase();
    if (shaExpected.isNotEmpty) {
      onProgress?.call(0.98);
      final actual = await _fileSha256Hex(partFile);
      if (actual != shaExpected) {
        await partFile.delete();
        throw Exception('校验失败：文件哈希与清单不一致');
      }
    }

    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await partFile.rename(finalPath);

    final installed = InstalledLocalLlmModel(
      id: item.id,
      name: item.name,
      filename: item.filename,
      filePath: finalPath,
      sizeBytes: await finalFile.length(),
      sha256: shaExpected,
      installedAt: DateTime.now(),
      source: item.source,
      hfRepoId: item.hfRepoId,
    );
    await _upsertInstalled(installed);
    onProgress?.call(1.0);
    return installed;
  }

  Future<void> deleteInstalled(String id) async {
    if (kIsWeb) return;
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;

    final path = await resolveModelPath(trimmed);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final part = File(
      '${p.join((await _modelsRootDir()).path, '$trimmed.gguf')}.part',
    );
    if (await part.exists()) {
      await part.delete();
    }

    final all = await listInstalled();
    final next = all.where((e) => e.id != trimmed).toList();
    await _writeManifest(next);
  }

  Future<void> _upsertInstalled(InstalledLocalLlmModel model) async {
    final all = await listInstalled();
    final next = [
      ...all.where((e) => e.id != model.id),
      model,
    ]..sort((a, b) => b.installedAt.compareTo(a.installedAt));
    await _writeManifest(next);
  }

  Future<void> _writeManifest(List<InstalledLocalLlmModel> models) async {
    final file = await _manifestFile();
    final payload = models.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<String> _fileSha256Hex(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
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
        return 'Hugging Face';
      case LocalModelSource.serverMirror:
        return '服务器镜像';
    }
  }
}
