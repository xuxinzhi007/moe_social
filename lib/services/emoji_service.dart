import 'dart:convert';
import '../emoji/emoji_data.dart';
import '../services/api_service.dart';

class EmojiService {
  // 获取表情包包列表
  Future<List<EmojiPack>?> getEmojiPacks({
    String? category,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (category != null) 'category': category,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final response = await ApiService.get('/api/emoji/packs?$queryString');
      final List<dynamic> packsJson = response['data'] ?? [];
      return packsJson.map((e) => EmojiPack.fromJson(e)).toList();
    } catch (e) {
      print('Error getting emoji packs: $e');
      return null;
    }
  }

  // 获取表情包包详情
  Future<EmojiPack?> getEmojiPack(String packId) async {
    try {
      final response = await ApiService.get('/api/emoji/packs/$packId');
      return EmojiPack.fromJson(response['data']);
    } catch (e) {
      print('Error getting emoji pack: $e');
      return null;
    }
  }

  // 购买表情包包
  Future<String?> purchaseEmojiPack(String packId, String userId) async {
    try {
      final response = await ApiService.post(
        '/api/emoji/packs/$packId/purchase',
        body: {'user_id': userId},
      );
      return response['data'];
    } catch (e) {
      print('Error purchasing emoji pack: $e');
      return null;
    }
  }

  // 获取用户已拥有的表情包包
  Future<List<EmojiPack>?> getUserEmojiPacks(String userId) async {
    try {
      final response = await ApiService.get('/api/user/$userId/emoji/packs');
      final List<dynamic> packsJson = response['data'] ?? [];
      return packsJson.map((e) => EmojiPack.fromJson(e)).toList();
    } catch (e) {
      print('Error getting user emoji packs: $e');
      return null;
    }
  }

  // 收藏表情包包
  Future<bool> favoriteEmojiPack(String packId, String userId) async {
    try {
      final response = await ApiService.post(
        '/api/emoji/packs/$packId/favorite',
        body: {'user_id': userId},
      );
      return true;
    } catch (e) {
      print('Error favoriting emoji pack: $e');
      return false;
    }
  }
}
