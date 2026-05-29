import 'post.dart';
import '../utils/api_json.dart';

/// 兴趣社区群组（与后端 `Group` 契约一致）。
class CommunityGroup {
  CommunityGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImage,
    required this.avatar,
    required this.memberCount,
    required this.isJoined,
    required this.isPublic,
    required this.creatorId,
    required this.creatorName,
    required this.tags,
  });

  final String id;
  final String name;
  final String description;
  final String coverImage;
  final String avatar;
  final int memberCount;
  final bool isJoined;
  final bool isPublic;
  final String creatorId;
  final String creatorName;
  final List<String> tags;

  factory CommunityGroup.fromApi(Map<String, dynamic> m) {
    final cover = apiString(m, 'cover', 'cover');
    final avatar = apiString(m, 'avatar', 'avatar');
    final isPublic = apiBool(m, 'is_public', 'isPublic', fallback: true);
    return CommunityGroup(
      id: (m['id'] ?? '').toString(),
      name: apiString(m, 'name', 'name'),
      description: apiString(m, 'description', 'description'),
      coverImage: cover.isNotEmpty ? cover : avatar,
      avatar: avatar,
      memberCount: apiInt(apiField(m, 'member_count', 'memberCount')),
      isJoined: apiBool(m, 'is_joined', 'isJoined'),
      isPublic: isPublic,
      creatorId: apiString(m, 'creator_id', 'creatorId'),
      creatorName: apiString(m, 'creator_name', 'creatorName'),
      tags: <String>[isPublic ? '公开' : '私密'],
    );
  }
}

class GroupMember {
  GroupMember({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.role,
  });

  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String role;

  factory GroupMember.fromApi(Map<String, dynamic> m) {
    return GroupMember(
      id: (m['id'] ?? '').toString(),
      userId: apiString(m, 'user_id', 'userId'),
      userName: apiString(m, 'user_name', 'userName'),
      userAvatar: apiString(m, 'user_avatar', 'userAvatar'),
      role: apiString(m, 'role', 'role', fallback: 'member'),
    );
  }
}

class GroupPostEntry {
  GroupPostEntry({
    required this.id,
    required this.groupId,
    required this.postId,
    required this.post,
  });

  final String id;
  final String groupId;
  final String postId;
  final Post post;

  factory GroupPostEntry.fromApi(Map<String, dynamic> m) {
    final postRaw = m['post'];
    Post post;
    if (postRaw is Map<String, dynamic>) {
      post = Post.fromJson(postRaw);
    } else if (postRaw is Map) {
      post = Post.fromJson(Map<String, dynamic>.from(postRaw));
    } else {
      post = Post.fromJson(<String, dynamic>{});
    }
    return GroupPostEntry(
      id: (m['id'] ?? '').toString(),
      groupId: apiString(m, 'group_id', 'groupId'),
      postId: apiString(m, 'post_id', 'postId').isNotEmpty
          ? apiString(m, 'post_id', 'postId')
          : post.id,
      post: post,
    );
  }
}
