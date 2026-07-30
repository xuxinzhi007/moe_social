import 'dart:io';

import 'api_client.dart';
import 'api_response.dart';

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
      ApiClient.uploadImageInfo(image);
}
