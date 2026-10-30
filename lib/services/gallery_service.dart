import 'dart:io';

import 'api_client.dart';
import 'api_response.dart';
import 'media_category.dart';

/// 云相册域服务：配额 / 列表 / 删除 / 上传。
class GalleryService {
  static Future<Map<String, dynamic>> getQuota() async {
    final result = await ApiClient.get('/api/images/quota');
    return ApiResponse.object(result, keys: const ['quota']);
  }

  static Future<Map<String, dynamic>> listImages({
    required int page,
    required int pageSize,
  }) =>
      ApiClient.get('/api/images?page=$page&page_size=$pageSize');

  static Future<void> deleteImage(String filename) =>
      ApiClient.delete('/api/images/$filename');

  static Future<Map<String, dynamic>> uploadImageInfo(File image) =>
      ApiClient.uploadImageInfo(image, category: MediaCategory.album);

  /// 调用本机 ComfyUI 生成图片并存入当前用户的 `gen/` 目录（返回图片 URL 等信息）。
  /// [style] 支持 `'anime'`（动漫，默认）或 `'realistic'`（写实）。
  static Future<String> generateComfyImage({
    required String prompt,
    String? style,
    String? negative,
    int? width,
    int? height,
    int? steps,
    double? cfg,
    int? seed,
    String? checkpoint,
  }) async {
    final resp = await ApiClient.generateComfyImage(
      prompt: prompt,
      style: style,
      negative: negative,
      width: width,
      height: height,
      steps: steps,
      cfg: cfg,
      seed: seed,
      checkpoint: checkpoint,
    );
    final data = ApiResponse.object(resp);
    // 优先取本站代理路径 /api/images/...（由后端鉴权并从七牛/本地流式输出），
    // 避免七牛测试域名（*.clouddn.com）在 Android 9+ 因明文 HTTP (Cleartext) 或过期被系统拦截导致「图片加载失败」。
    final url = (data['url'] ?? resp['url'])?.toString().trim();
    if (url != null && url.isNotEmpty) return url;
    final fullUrl = (data['fullUrl'] ?? resp['fullUrl'])?.toString().trim();
    if (fullUrl != null && fullUrl.isNotEmpty) return fullUrl;
    throw Exception('生图接口未返回有效图片地址');
  }
}
