import 'dart:convert';
import '../avatars/avatar_data.dart';
import '../services/api_service.dart';

class AvatarService {
  // 获取用户虚拟形象
  Future<UserAvatar?> getUserAvatar(String userId) async {
    try {
      print('🌐 正在调用API获取虚拟形象: GET /api/avatar/$userId');
      final response = await ApiService.get('/api/avatar/$userId');
      print('✅ API调用成功，响应数据: $response');

      if (response['data'] != null) {
        print('📦 解析虚拟形象数据: ${response['data']}');
        final userAvatar = UserAvatar.fromJson(response['data']);
        print('🎯 解析完成，虚拟形象: $userAvatar');
        return userAvatar;
      } else {
        print('⚠️ 响应data字段为空');
        return null;
      }
    } catch (e) {
      print('❌ 获取用户虚拟形象失败: $e');
      print('📍 错误类型: ${e.runtimeType}');
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
      print('Error updating user avatar: $e');
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
      print('Error getting avatar outfits: $e');
      return null;
    }
  }

  // 获取装扮物品详情
  Future<AvatarOutfit?> getAvatarOutfit(String outfitId) async {
    try {
      final response = await ApiService.get('/api/avatar/outfits/$outfitId');
      return AvatarOutfit.fromJson(response['data']);
    } catch (e) {
      print('Error getting avatar outfit: $e');
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
      print('Error purchasing avatar outfit: $e');
      return null;
    }
  }
}
