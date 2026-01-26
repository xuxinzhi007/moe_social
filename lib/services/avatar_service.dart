import '../avatars/avatar_data.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class AvatarService {
  // 获取用户虚拟形象
  Future<UserAvatar?> getUserAvatar(String userId) async {
    try {
      final response = await ApiService.get('/api/avatar/$userId');

      if (response['data'] != null) {
        final userAvatar = UserAvatar.fromJson(response['data']);
        return userAvatar;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ 响应data字段为空');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取用户虚拟形象失败: $e');
      }
      return null;
    }
  }

  // 更新用户虚拟形象
  Future<UserAvatar?> updateUserAvatar(String userId, UserAvatar avatar) async {
    try {
      // 按照后端期望的格式发送请求
      final requestBody = {
        'base_config': avatar.baseConfig.toJson(),
        'current_outfit': avatar.currentOutfit.toJson(),
      };

      final response = await ApiService.put(
        '/api/avatar/$userId',
        body: requestBody,
      );
      return UserAvatar.fromJson(response['data']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user avatar: $e');
      }
      return null;
    }
  }

  // 获取装扮物品列表
  Future<List<AvatarOutfit>?> getAvatarOutfits({
    String? category,
    String? style,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (category != null) 'category': category,
        if (style != null) 'style': style,
      };
      final queryString = Uri(queryParameters: queryParams).query;
      final response = await ApiService.get('/api/avatar/outfits?$queryString');
      final List<dynamic> outfitsJson = response['data'] ?? [];
      return outfitsJson.map((e) => AvatarOutfit.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting avatar outfits: $e');
      }
      return null;
    }
  }

  // 获取装扮物品详情
  Future<AvatarOutfit?> getAvatarOutfit(String outfitId) async {
    try {
      final response = await ApiService.get('/api/avatar/outfits/$outfitId');
      return AvatarOutfit.fromJson(response['data']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting avatar outfit: $e');
      }
      return null;
    }
  }

  // 购买装扮物品
  Future<String?> purchaseAvatarOutfit(String outfitId, String userId) async {
    try {
      final response = await ApiService.post(
        '/api/avatar/outfits/$outfitId/purchase',
        body: {'user_id': userId},
      );
      return response['data'];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error purchasing avatar outfit: $e');
      }
      return null;
    }
  }
}
