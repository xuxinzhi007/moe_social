class UserMemoryDisplayItem {
  final String id;
  final String key;
  final String title;
  final String content;
  final String category;
  final String updatedAt;

  const UserMemoryDisplayItem({
    required this.id,
    required this.key,
    required this.title,
    required this.content,
    required this.category,
    required this.updatedAt,
  });

  factory UserMemoryDisplayItem.fromJson(Map<String, dynamic> json) {
    return UserMemoryDisplayItem(
      id: '${json['id'] ?? ''}',
      key: '${json['key'] ?? ''}',
      title: '${json['title'] ?? '记忆'}',
      content: '${json['content'] ?? ''}',
      category: '${json['category'] ?? '了解'}',
      updatedAt: '${json['updated_at'] ?? ''}',
    );
  }
}

class UserMemoryDisplayProfile {
  final String title;
  final String summary;
  final int itemCount;

  const UserMemoryDisplayProfile({
    required this.title,
    required this.summary,
    required this.itemCount,
  });

  factory UserMemoryDisplayProfile.fromJson(Map<String, dynamic> json) {
    return UserMemoryDisplayProfile(
      title: '${json['title'] ?? '了解'}',
      summary: '${json['summary'] ?? ''}',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserMemoryDisplayData {
  final String headline;
  final List<UserMemoryDisplayProfile> profiles;
  final List<UserMemoryDisplayItem> items;
  final int total;

  const UserMemoryDisplayData({
    required this.headline,
    required this.profiles,
    required this.items,
    required this.total,
  });

  factory UserMemoryDisplayData.fromJson(Map<String, dynamic> json) {
    final profilesRaw = json['profiles'];
    final itemsRaw = json['items'];
    return UserMemoryDisplayData(
      headline: '${json['headline'] ?? ''}',
      profiles: profilesRaw is List
          ? profilesRaw
              .whereType<Map>()
              .map((e) => UserMemoryDisplayProfile.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => UserMemoryDisplayItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
