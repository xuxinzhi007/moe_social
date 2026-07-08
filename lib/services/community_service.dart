import '../models/community_group.dart';
import 'api_service.dart';

class CommunityService {
  static Future<CommunityGroup> getCommunityGroup({
    required String groupId,
    String? userId,
  }) =>
      ApiService.getCommunityGroup(groupId: groupId, userId: userId);

  static Future<Map<String, dynamic>> getCommunityGroups({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? userId,
    bool? isPublic,
  }) =>
      ApiService.getCommunityGroups(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
        userId: userId,
        isPublic: isPublic,
      );

  static Future<List<CommunityGroup>> getUserCommunityGroups({
    required String userId,
    int page = 1,
    int pageSize = 40,
  }) =>
      ApiService.getUserCommunityGroups(
        userId: userId,
        page: page,
        pageSize: pageSize,
      );

  static Future<Map<String, dynamic>> getGroupPosts({
    required String groupId,
    int page = 1,
    int pageSize = 20,
    String? userId,
  }) =>
      ApiService.getGroupPosts(
        groupId: groupId,
        page: page,
        pageSize: pageSize,
        userId: userId,
      );

  static Future<Map<String, dynamic>> getGroupMembers({
    required String groupId,
    int page = 1,
    int pageSize = 40,
  }) =>
      ApiService.getGroupMembers(
        groupId: groupId,
        page: page,
        pageSize: pageSize,
      );

  static Future<void> joinCommunityGroup({
    required String groupId,
    required String userId,
  }) =>
      ApiService.joinCommunityGroup(groupId: groupId, userId: userId);

  static Future<void> leaveCommunityGroup({
    required String groupId,
    required String userId,
  }) =>
      ApiService.leaveCommunityGroup(groupId: groupId, userId: userId);

  static Future<Map<String, dynamic>> createCommunityGroup({
    required String userId,
    required String name,
    required String description,
    bool isPublic = true,
    String avatar = '',
    String cover = '',
  }) =>
      ApiService.createCommunityGroup(
        userId: userId,
        name: name,
        description: description,
        isPublic: isPublic,
        avatar: avatar,
        cover: cover,
      );
}
