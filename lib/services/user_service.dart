import '../models/user.dart';
import 'api_service.dart';

class UserService {
  static Future<User> getUserInfo(String userId) =>
      ApiService.getUserInfo(userId);

  static Future<User> updateUserInfo(
    String userId, {
    String? username,
    String? email,
    String? avatar,
    String? signature,
    String? gender,
    String? birthday,
    List<String>? inventory,
    String? equippedFrameId,
    bool clearEquippedFrame = false,
    String? messageRetention,
  }) =>
      ApiService.updateUserInfo(
        userId,
        username: username,
        email: email,
        avatar: avatar,
        signature: signature,
        gender: gender,
        birthday: birthday,
        inventory: inventory,
        equippedFrameId: equippedFrameId,
        clearEquippedFrame: clearEquippedFrame,
        messageRetention: messageRetention,
      );

  static Future<List<User>> getFriends(String userId) =>
      ApiService.getFriends(userId);

  static Future<List<Map<String, dynamic>>> getIncomingFriendRequests(
    String userId,
  ) =>
      ApiService.getIncomingFriendRequests(userId);

  static Future<void> acceptFriendRequest(String userId, String requestId) =>
      ApiService.acceptFriendRequest(userId, requestId);

  static Future<void> rejectFriendRequest(String userId, String requestId) =>
      ApiService.rejectFriendRequest(userId, requestId);

  static Future<Map<String, dynamic>> getFollowers(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getFollowers(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> getFollowings(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getFollowings(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> followUser(
    String userId,
    String followingId,
  ) =>
      ApiService.followUser(userId, followingId);

  static Future<Map<String, dynamic>> unfollowUser(
    String userId,
    String followingId,
  ) =>
      ApiService.unfollowUser(userId, followingId);

  static Future<bool> checkFollow(String followerId, String followingId) =>
      ApiService.checkFollow(followerId, followingId);

  static Future<String> getFriendRelation(String userId, String otherUserId) =>
      ApiService.getFriendRelation(userId, otherUserId);

  static Future<void> sendFriendRequestByUserId(
    String userId,
    String toUserId,
  ) =>
      ApiService.sendFriendRequestByUserId(userId, toUserId);

  static Future<void> sendFriendRequestByMoeNo(String userId, String moeNo) =>
      ApiService.sendFriendRequestByMoeNo(userId, moeNo);

  static Future<User> checkUserByEmail(String email) =>
      ApiService.checkUserByEmail(email);

  static Future<Map<String, bool>> getChatOnlineBatch(List<String> userIds) =>
      ApiService.getChatOnlineBatch(userIds);

  static Future<void> deleteMyAccount() => ApiService.deleteMyAccount();

  static Future<void> updateUserPassword(
    String userId,
    String oldPassword,
    String newPassword,
  ) =>
      ApiService.updateUserPassword(userId, oldPassword, newPassword);

  static Future<List<Map<String, dynamic>>> getLoginHistory(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) =>
      ApiService.getLoginHistory(userId, page: page, pageSize: pageSize);

  static Future<Map<String, dynamic>> getTwoFactorStatus(String userId) =>
      ApiService.getTwoFactorStatus(userId);

  static Future<Map<String, dynamic>> enableTwoFactorAuth(String userId) =>
      ApiService.enableTwoFactorAuth(userId);

  static Future<Map<String, dynamic>> verifyTwoFactorCode(
    String userId,
    String code,
  ) =>
      ApiService.verifyTwoFactorCode(userId, code);

  static Future<void> disableTwoFactorAuth(String userId, String code) =>
      ApiService.disableTwoFactorAuth(userId, code);

  static Future<User> bindFeishuEmail(String feishuEmail) =>
      ApiService.bindFeishuEmail(feishuEmail);

  static Future<User> unbindFeishuEmail() => ApiService.unbindFeishuEmail();

  static Future<void> sendFeishuTestCard() => ApiService.sendFeishuTestCard();

  static Future<Map<String, dynamic>> submitFeedback({
    required String email,
    required String category,
    required String content,
    String? source,
    String? clientIp,
    String? userAgent,
  }) =>
      ApiService.submitFeedback(
        email: email,
        category: category,
        content: content,
        source: source,
        clientIp: clientIp,
        userAgent: userAgent,
      );
}
