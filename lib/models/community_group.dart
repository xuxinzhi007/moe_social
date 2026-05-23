import 'post.dart';

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
    final cover = (m['cover'] ?? '').toString();
    final avatar = (m['avatar'] ?? '').toString();
    return CommunityGroup(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      coverImage: cover.isNotEmpty ? cover : avatar,
      avatar: avatar,
      memberCount: (m['member_count'] is int)
          ? m['member_count'] as int
          : int.tryParse('${m['member_count'] ?? 0}') ?? 0,
      isJoined: m['is_joined'] == true,
      isPublic: m['is_public'] != false,
      creatorId: (m['creator_id'] ?? '').toString(),
      creatorName: (m['creator_name'] ?? '').toString(),
      tags: <String>[m['is_public'] == false ? '私密' : '公开'],
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
      userId: (m['user_id'] ?? '').toString(),
      userName: (m['user_name'] ?? '').toString(),
      userAvatar: (m['user_avatar'] ?? '').toString(),
      role: (m['role'] ?? 'member').toString(),
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
      groupId: (m['group_id'] ?? '').toString(),
      postId: (m['post_id'] ?? post.id).toString(),
      post: post,
    );
  }
}
