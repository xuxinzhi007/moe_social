import 'dart:io';
import 'dart:typed_data';

import 'api_service.dart';

export 'api_service.dart' show ApiException, LifeActionCooldownException;

/// Low-level HTTP helpers for pages that need direct URL access (LLM, gallery, etc.).
class ApiClient {
  static String get baseUrl => ApiService.baseUrl;

  static String? get token => ApiService.token;

  static Map<String, String> mergeTunnelHeaders(
    Uri uri, {
    Map<String, String>? headers,
  }) =>
      ApiService.mergeTunnelHeaders(uri, headers: headers);

  static Map<String, String> tunnelBypassHeadersForUrl(String url) =>
      ApiService.tunnelBypassHeadersForUrl(url);

  static void logDirectHttp(String method, Uri uri) =>
      ApiService.logDirectHttp(method, uri);

  static Future<Map<String, dynamic>> get(String path) => ApiService.get(path);

  static Future<Map<String, dynamic>> delete(String path) =>
      ApiService.delete(path);

  static Future<String> uploadImage(File image) =>
      ApiService.uploadImage(image);

  static Future<String> uploadImageBytes(
    Uint8List bytes, {
    String filename = 'upload.png',
  }) =>
      ApiService.uploadImageBytes(bytes, filename: filename);

  static Future<Map<String, dynamic>> uploadImageInfo(File image) =>
      ApiService.uploadImageInfo(image);
}
